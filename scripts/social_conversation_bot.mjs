#!/usr/bin/env node

/**
 * Sync Facebook + WhatsApp conversations into Supabase.
 *
 * Required env vars:
 * - META_ACCESS_TOKEN
 * - META_PAGE_ID
 * - META_WABA_ID
 * - SUPABASE_URL
 * - SUPABASE_SERVICE_ROLE_KEY
 */

const {
  META_ACCESS_TOKEN,
  META_PAGE_ID,
  META_WABA_ID,
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
} = process.env;

const GRAPH_BASE = 'https://graph.facebook.com/v23.0';

function requireEnv(name, value) {
  if (!value) {
    throw new Error(`Missing env var: ${name}`);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function graphGet(path, params = {}) {
  const url = new URL(`${GRAPH_BASE}${path}`);
  url.searchParams.set('access_token', META_ACCESS_TOKEN);
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== '') {
      url.searchParams.set(k, String(v));
    }
  }

  const res = await fetch(url, { method: 'GET' });
  const body = await res.json();
  if (!res.ok) {
    throw new Error(`Graph API error ${res.status}: ${JSON.stringify(body)}`);
  }
  return body;
}

async function supabaseUpsert(table, rows, onConflict) {
  if (!rows.length) return;

  const url = new URL(`${SUPABASE_URL}/rest/v1/${table}`);
  url.searchParams.set('on_conflict', onConflict);

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    body: JSON.stringify(rows),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase upsert ${table} failed: ${res.status} ${text}`);
  }
}

async function getConversationIdMap() {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/social_conversations?select=id,channel,external_conversation_id`,
    {
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      },
    },
  );

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase query social_conversations failed: ${res.status} ${text}`);
  }

  const rows = await res.json();
  const map = new Map();
  for (const row of rows) {
    map.set(`${row.channel}:${row.external_conversation_id}`, row.id);
  }
  return map;
}

function participantName(participants = []) {
  return participants
    .map((p) => p?.name)
    .filter(Boolean)
    .join(', ');
}

async function syncFacebook() {
  const conversations = [];
  const messages = [];

  let nextUrl = null;
  let page = await graphGet(`/${META_PAGE_ID}/conversations`, {
    fields: 'id,updated_time,snippet,participants',
    limit: 50,
  });

  while (true) {
    for (const convo of page.data || []) {
      const participants = convo.participants?.data || [];
      conversations.push({
        channel: 'facebook',
        external_conversation_id: String(convo.id),
        participant_display: participantName(participants),
        last_message_preview: convo.snippet || null,
        last_message_at: convo.updated_time || null,
        raw_payload: convo,
      });

      const convoMsgs = await graphGet(`/${convo.id}/messages`, {
        fields: 'id,message,created_time,from',
        limit: 50,
      });

      for (const msg of convoMsgs.data || []) {
        messages.push({
          channel: 'facebook',
          external_conversation_id: String(convo.id),
          external_message_id: String(msg.id),
          sender_name: msg.from?.name || null,
          sender_id: msg.from?.id || null,
          body: msg.message || null,
          sent_at: msg.created_time || null,
          raw_payload: msg,
        });
      }

      await sleep(40);
    }

    nextUrl = page.paging?.next;
    if (!nextUrl) break;
    const res = await fetch(nextUrl);
    if (!res.ok) break;
    page = await res.json();
  }

  return { conversations, messages };
}

async function syncWhatsApp() {
  const conversations = [];

  const page = await graphGet(`/${META_WABA_ID}/conversations`, {
    fields: 'id,phone_number,origin,status,expiration_timestamp,last_updated',
    limit: 100,
  });

  for (const convo of page.data || []) {
    conversations.push({
      channel: 'whatsapp',
      external_conversation_id: String(convo.id),
      participant_phone: convo.phone_number || null,
      participant_display: convo.phone_number || 'WhatsApp lead',
      last_message_preview: convo.status || convo.origin?.type || null,
      last_message_at: convo.last_updated || convo.expiration_timestamp || null,
      raw_payload: convo,
    });
  }

  return { conversations, messages: [] };
}

async function linkAndInsertMessages(rawMessages, idMap) {
  const rows = [];
  for (const msg of rawMessages) {
    const key = `${msg.channel}:${msg.external_conversation_id}`;
    const conversationId = idMap.get(key);
    if (!conversationId) continue;
    rows.push({
      conversation_id: conversationId,
      channel: msg.channel,
      external_message_id: msg.external_message_id,
      sender_name: msg.sender_name,
      sender_id: msg.sender_id,
      body: msg.body,
      sent_at: msg.sent_at,
      raw_payload: msg.raw_payload,
    });
  }

  await supabaseUpsert('social_messages', rows, 'channel,external_message_id');
  return rows.length;
}

async function main() {
  requireEnv('META_ACCESS_TOKEN', META_ACCESS_TOKEN);
  requireEnv('META_PAGE_ID', META_PAGE_ID);
  requireEnv('META_WABA_ID', META_WABA_ID);
  requireEnv('SUPABASE_URL', SUPABASE_URL);
  requireEnv('SUPABASE_SERVICE_ROLE_KEY', SUPABASE_SERVICE_ROLE_KEY);

  console.log('Sync started...');

  const [facebook, whatsapp] = await Promise.all([syncFacebook(), syncWhatsApp()]);
  const allConversations = [...facebook.conversations, ...whatsapp.conversations];

  await supabaseUpsert(
    'social_conversations',
    allConversations,
    'channel,external_conversation_id',
  );

  const idMap = await getConversationIdMap();
  const insertedMessages = await linkAndInsertMessages(facebook.messages, idMap);

  console.log(
    `Done. Conversations upserted: ${allConversations.length}, messages upserted: ${insertedMessages}`,
  );
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
