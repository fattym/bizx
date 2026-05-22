-- MARGED SQL
-- Combined on 2026-05-22 07:38:50 UTC
-- Source: all .sql files found in this project

-- =========================================================
-- BEGIN FILE: supabase/demo_geofences.sql
-- =========================================================
-- Demo county geofences for admin map visualization
-- Run this after schema/seed setup.

insert into public.geofences (name, description, region, coordinates)
values
  (
    'Nairobi County Demo',
    'Demo boundary for Nairobi county.',
    'Nairobi',
    '[{"lat": -1.220, "lng": 36.760}, {"lat": -1.220, "lng": 36.940}, {"lat": -1.380, "lng": 36.940}, {"lat": -1.380, "lng": 36.760}]'::jsonb
  ),
  (
    'Mombasa County Demo',
    'Demo boundary for Mombasa county.',
    'Mombasa',
    '[{"lat": -3.930, "lng": 39.610}, {"lat": -3.930, "lng": 39.760}, {"lat": -4.120, "lng": 39.760}, {"lat": -4.120, "lng": 39.610}]'::jsonb
  ),
  (
    'Kisumu County Demo',
    'Demo boundary for Kisumu county.',
    'Kisumu',
    '[{"lat": -0.020, "lng": 34.650}, {"lat": -0.020, "lng": 34.860}, {"lat": -0.190, "lng": 34.860}, {"lat": -0.190, "lng": 34.650}]'::jsonb
  ),
  (
    'Nakuru County Demo',
    'Demo boundary for Nakuru county.',
    'Nakuru',
    '[{"lat": -0.130, "lng": 35.950}, {"lat": -0.130, "lng": 36.220}, {"lat": -0.430, "lng": 36.220}, {"lat": -0.430, "lng": 35.950}]'::jsonb
  ),
  (
    'Kiambu County Demo',
    'Demo boundary for Kiambu county.',
    'Kiambu',
    '[{"lat": -1.000, "lng": 36.620}, {"lat": -1.000, "lng": 37.000}, {"lat": -1.280, "lng": 37.000}, {"lat": -1.280, "lng": 36.620}]'::jsonb
  ),
  (
    'Uasin Gishu County Demo',
    'Demo boundary for Uasin Gishu county.',
    'Uasin Gishu',
    '[{"lat": 0.350, "lng": 35.100}, {"lat": 0.350, "lng": 35.450}, {"lat": 0.000, "lng": 35.450}, {"lat": 0.000, "lng": 35.100}]'::jsonb
  );

-- END FILE: supabase/demo_geofences.sql

-- =========================================================
-- BEGIN FILE: supabase/generate_mock_data.sql
-- =========================================================
-- Generate mock tasks + pipeline data for dashboard testing
-- Safe to rerun: uses deterministic IDs and upserts.

begin;

-- 1) Ensure task status normalization in existing rows
update public.tasks
set status = 'closed'
where lower(status) in ('complete', 'completed', 'done');

update public.tasks
set status = 'in_progress'
where lower(status) in ('in progress', 'progress');

update public.tasks
set status = 'open'
where lower(status) not in ('open', 'in_progress', 'closed');

-- 2) Insert/update demo tasks across statuses and due dates
insert into public.tasks (
  id, title, description, target_role, assigned_to, status, due_at, created_by, "isSynced"
)
values
  ('90000000-0000-0000-0000-000000000001', 'Pipeline Follow-up Call', 'Call 3 schools and confirm next action.', 5, null, 'open', now() + interval '1 day', null, true),
  ('90000000-0000-0000-0000-000000000002', 'Sample Delivery Review', 'Review sample delivery proof and update remarks.', 5, null, 'in_progress', now() + interval '3 days', null, true),
  ('90000000-0000-0000-0000-000000000003', 'Closed Task Demo', 'Already completed task for admin closed filter.', 5, null, 'closed', now() - interval '1 day', null, true),
  ('90000000-0000-0000-0000-000000000004', 'Admin Visibility Task', 'Task to verify role 1 can filter by status.', 2, null, 'closed', now() - interval '2 days', null, true)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  target_role = excluded.target_role,
  assigned_to = excluded.assigned_to,
  status = excluded.status,
  due_at = excluded.due_at,
  created_by = excluded.created_by,
  "isSynced" = excluded."isSynced";

-- 3) Add/refresh social pipeline stage demo data from available schools
with selected_schools as (
  select id, row_number() over (order by created_at desc nulls last, id) as rn
  from public.schools
  limit 6
),
stage_matrix as (
  select * from (values
    (1, 'lead', 45000::numeric),
    (2, 'contacted', 60000::numeric),
    (3, 'meeting_scheduled', 90000::numeric),
    (4, 'negotiation', 140000::numeric),
    (5, 'won', 180000::numeric),
    (6, 'lost', 30000::numeric)
  ) as t(rn, stage, expected_value)
)
insert into public.school_sales (
  id, school_id, package_name, sale_status, expected_value, stage_updated_at, probability, notes, "isSynced"
)
select
  ('91000000-0000-0000-0000-' || lpad(ss.rn::text, 12, '0'))::uuid as id,
  ss.id as school_id,
  'Generated Demo Package' as package_name,
  sm.stage,
  sm.expected_value,
  now() - ((ss.rn::text || ' days')::interval),
  case sm.stage
    when 'won' then 100
    when 'negotiation' then 75
    when 'meeting_scheduled' then 60
    when 'contacted' then 40
    when 'lead' then 25
    when 'lost' then 0
    else 20
  end,
  'Generated demo pipeline row',
  true
from selected_schools ss
join stage_matrix sm on sm.rn = ss.rn
on conflict (id) do update set
  package_name = excluded.package_name,
  sale_status = excluded.sale_status,
  expected_value = excluded.expected_value,
  stage_updated_at = excluded.stage_updated_at,
  probability = excluded.probability,
  notes = excluded.notes,
  "isSynced" = excluded."isSynced";

commit;

-- END FILE: supabase/generate_mock_data.sql

-- =========================================================
-- BEGIN FILE: supabase/schema.sql
-- =========================================================
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.role_id_from_text(role_text text)
returns integer
language plpgsql
immutable
as $$
begin
  if role_text is null or btrim(role_text) = '' then
    return 5;
  end if;

  case lower(btrim(role_text))
    when 'admin' then return 1;
    when 'sales manager' then return 2;
    when 'bas' then return 3;
    when 'agent' then return 4;
    when 'grounds person' then return 5;
    else
      begin
        return role_text::integer;
      exception
        when others then
          return 5;
      end;
  end case;
end;
$$;

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  role integer not null default 5,
  region text,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure region, phone and isSynced columns exist (in case table was created previously)
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'region') then
    alter table public.users add column region text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'phone') then
    alter table public.users add column phone text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'isSynced') then
    alter table public.users add column "isSynced" boolean not null default false;
  end if;
end $$;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'role'
      and data_type <> 'integer'
  ) then
    alter table public.users
      alter column role drop default;
    alter table public.users
      alter column role type integer using public.role_id_from_text(role::text);
    alter table public.users
      alter column role set default 5;
  end if;
end $$;

alter table public.users
  alter column role set default 5;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role = 1
  );
$$;

create or replace function public.is_manager_or_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role <= 3
  );
$$;

create or replace function public.is_sales_manager()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role <= 2
  );
$$;

create or replace function public.is_bas()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role <= 3
  );
$$;

create or replace function public.current_user_role_id()
returns integer
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select role from public.users where id = auth.uid() limit 1),
    5
  );
$$;

create or replace function public.current_user_role_from_jwt()
returns integer
language sql
stable
as $$
  select public.role_id_from_text(
    coalesce(
      auth.jwt() -> 'user_metadata' ->> 'role',
      auth.jwt() -> 'app_metadata' ->> 'role'
    )
  );
$$;

create or replace function public.current_user_region_from_jwt()
returns text
language sql
stable
as $$
  select coalesce(
    auth.jwt() -> 'user_metadata' ->> 'region',
    auth.jwt() -> 'app_metadata' ->> 'region'
  );
$$;

create or replace function public.current_user_region()
returns text
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select nullif(btrim(region), '') from public.users where id = auth.uid() limit 1),
    nullif(btrim(public.current_user_region_from_jwt()), '')
  );
$$;

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  county text not null,
  source text not null default 'manual',
  external_place_id text,
  external_vicinity text,
  "focusAreas" jsonb not null default '[]'::jsonb,
  book_category text,
  dealer_type text,
  shop_category text,
  selected_product text,
  partner_subtype text,
  latitude double precision,
  longitude double precision,
  photo_url text,
  photo_path text,
  captured_by uuid references public.users (id) on delete set null,
  captured_at timestamptz,
  capture_status text,
  contact_name text,
  contact_phone text,
  contact_title text,
  feedback text,
  notes text,
  samples_left text,
  sample_book text,
  school_ownership text,
  school_ownership_other text,
  school_population integer,
  school_lifecycle_status text,
  engagement_type text,
  sample_proof_url text,
  sample_proof_path text,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure isSynced column exists in schools
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'source') then
    alter table public.schools add column source text not null default 'manual';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'external_place_id') then
    alter table public.schools add column external_place_id text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'external_vicinity') then
    alter table public.schools add column external_vicinity text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'isSynced') then
    alter table public.schools add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'book_category') then
    alter table public.schools add column book_category text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'dealer_type') then
    alter table public.schools add column dealer_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'shop_category') then
    alter table public.schools add column shop_category text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'selected_product') then
    alter table public.schools add column selected_product text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'partner_subtype') then
    alter table public.schools add column partner_subtype text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'photo_url') then
    alter table public.schools add column photo_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'photo_path') then
    alter table public.schools add column photo_path text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'captured_by') then
    alter table public.schools add column captured_by uuid references public.users (id) on delete set null;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'captured_at') then
    alter table public.schools add column captured_at timestamptz;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'capture_status') then
    alter table public.schools add column capture_status text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_name') then
    alter table public.schools add column contact_name text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_phone') then
    alter table public.schools add column contact_phone text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_title') then
    alter table public.schools add column contact_title text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'feedback') then
    alter table public.schools add column feedback text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'notes') then
    alter table public.schools add column notes text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'samples_left') then
    alter table public.schools add column samples_left text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_book') then
    alter table public.schools add column sample_book text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_ownership') then
    alter table public.schools add column school_ownership text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_ownership_other') then
    alter table public.schools add column school_ownership_other text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_population') then
    alter table public.schools add column school_population integer;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_lifecycle_status') then
    alter table public.schools add column school_lifecycle_status text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'engagement_type') then
    alter table public.schools add column engagement_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_proof_url') then
    alter table public.schools add column sample_proof_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_proof_path') then
    alter table public.schools add column sample_proof_path text;
  end if;
end $$;

do $$
begin
  if to_regclass('public.users') is not null then
    create index if not exists idx_users_role_region on public.users(role, region);
  end if;
  if to_regclass('public.tasks') is not null then
    create index if not exists idx_tasks_assigned_status_due on public.tasks(assigned_to, status, due_at);
  end if;
  if to_regclass('public.geofences') is not null then
    create index if not exists idx_geofences_region_assigned on public.geofences(region, assigned_to);
  end if;
  if to_regclass('public.route_plans') is not null then
    create index if not exists idx_route_plans_assigned_date_status on public.route_plans(assigned_to, route_date, status);
  end if;
end $$;

create unique index if not exists idx_schools_external_place_id
  on public.schools (external_place_id)
  where external_place_id is not null;

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  target_role integer not null default 2,
  due_at timestamptz,
  status text not null default 'open',
  created_by uuid references auth.users (id) on delete set null,
  assigned_to uuid references public.users (id) on delete set null,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure isSynced column exists in tasks
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tasks' and column_name = 'isSynced') then
    alter table public.tasks add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.geofences (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  region text,
  coordinates jsonb not null default '[]'::jsonb,
  assigned_to uuid references public.users (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'geofences'
      and column_name = 'region'
  ) then
    alter table public.geofences add column region text;
  end if;
end $$;

create table if not exists public.route_plans (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  route_date date not null,
  assigned_to uuid references public.users (id) on delete set null,
  school_ids jsonb not null default '[]'::jsonb,
  notes text,
  status text not null default 'assigned',
  created_by uuid references auth.users (id) on delete set null,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'reviewed_by') then
    alter table public.route_plans add column reviewed_by uuid references public.users (id) on delete set null;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'reviewed_at') then
    alter table public.route_plans add column reviewed_at timestamptz;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'review_note') then
    alter table public.route_plans add column review_note text;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'route_plans_status_check'
      and conrelid = 'public.route_plans'::regclass
  ) then
    alter table public.route_plans
      add constraint route_plans_status_check
      check (status in ('draft', 'submitted', 'approved', 'rejected', 'assigned', 'in_progress', 'completed'));
  end if;
end $$;

create table if not exists public.geofence_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  geofence_id uuid references public.geofences (id) on delete set null,
  event_type text not null,
  region text,
  lat double precision,
  lng double precision,
  reason text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table if not exists public.supervisor_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  region text,
  alert_type text not null,
  severity text not null default 'amber',
  status text not null default 'open',
  message text,
  acked_at timestamptz,
  resolved_at timestamptz,
  ack_sla_met boolean default false,
  resolve_sla_met boolean default false,
  escalated_to_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.supervisor_incidents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  region text,
  incident_type text not null,
  severity text not null default 'high',
  status text not null default 'open',
  notes text,
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.supervisor_notes (
  id uuid primary key default gen_random_uuid(),
  supervisor_id uuid not null references public.users (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  region text,
  context_type text,
  context_id uuid,
  note text not null,
  follow_up_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.users (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  region text,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.task_completion_evidence (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  submitted_by uuid not null references public.users (id) on delete cascade,
  gps_lat double precision,
  gps_lng double precision,
  proof_url text,
  proof_type text,
  created_at timestamptz not null default now()
);

create table if not exists public.supervisor_notifications (
  id uuid primary key default gen_random_uuid(),
  supervisor_id uuid not null references public.users (id) on delete cascade,
  region text,
  notification_type text not null,
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  scheduled_for timestamptz not null default now(),
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_supervisor_alerts_status_created
  on public.supervisor_alerts(status, created_at);
create index if not exists idx_supervisor_alerts_region
  on public.supervisor_alerts(region);
create index if not exists idx_supervisor_notifications_supervisor_scheduled
  on public.supervisor_notifications(supervisor_id, scheduled_for);
create index if not exists idx_supervisor_notifications_read_at
  on public.supervisor_notifications(read_at);

create or replace function public.process_supervisor_alert_sla()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_count integer := 0;
begin
  -- Mark open red alerts older than 15 minutes as SLA-breached for ack.
  update public.supervisor_alerts
  set ack_sla_met = false
  where status = 'open'
    and lower(coalesce(severity, '')) = 'red'
    and created_at <= now() - interval '15 minutes'
    and coalesce(ack_sla_met, true) = true;
  get diagnostics affected_count = row_count;

  -- Escalate unresolved red alerts older than 2 hours.
  with to_escalate as (
    update public.supervisor_alerts
    set escalated_to_admin = true
    where status = 'open'
      and lower(coalesce(severity, '')) = 'red'
      and created_at <= now() - interval '2 hours'
      and coalesce(escalated_to_admin, false) = false
    returning id, user_id, region, alert_type
  )
  insert into public.supervisor_notifications (
    supervisor_id,
    region,
    notification_type,
    title,
    body,
    payload,
    scheduled_for
  )
  select
    u.id,
    u.region,
    'escalation',
    'Escalated Red Alert',
    'A red alert is unresolved for over 2 hours and has been escalated.',
    jsonb_build_object('alert_id', e.id, 'alert_type', e.alert_type, 'user_id', e.user_id),
    now()
  from to_escalate e
  join public.users u
    on u.role = 3
   and lower(coalesce(u.region, '')) = lower(coalesce(e.region, ''));

  return affected_count;
end;
$$;

create or replace function public.queue_supervisor_daily_digests()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
  batch_count integer := 0;
begin
  -- Morning digest at 07:00 local DB time.
  if to_char(now(), 'HH24:MI') between '07:00' and '07:10' then
    insert into public.supervisor_notifications (
      supervisor_id,
      region,
      notification_type,
      title,
      body,
      payload,
      scheduled_for
    )
    select
      s.id,
      s.region,
      'daily_digest',
      'Morning Supervision Digest',
      'Start-of-day summary for your Role 5 region.',
      jsonb_build_object(
        'open_alerts', (
          select count(*)
          from public.supervisor_alerts a
          where lower(coalesce(a.region, '')) = lower(coalesce(s.region, ''))
            and a.status = 'open'
        ),
        'overdue_tasks', (
          select count(*)
          from public.tasks t
          join public.users u on u.id = t.assigned_to
          where u.role = 5
            and lower(coalesce(u.region, '')) = lower(coalesce(s.region, ''))
            and t.due_at < now()
            and lower(coalesce(t.status, '')) not in ('closed', 'completed')
        )
      ),
      now()
    from public.users s
    where s.role = 3;
    get diagnostics batch_count = row_count;
    inserted_count := inserted_count + batch_count;
  end if;

  -- Evening digest at 18:00 local DB time.
  if to_char(now(), 'HH24:MI') between '18:00' and '18:10' then
    insert into public.supervisor_notifications (
      supervisor_id,
      region,
      notification_type,
      title,
      body,
      payload,
      scheduled_for
    )
    select
      s.id,
      s.region,
      'evening_summary',
      'Evening Supervision Summary',
      'End-of-day summary for Role 5 execution in your region.',
      jsonb_build_object(
        'resolved_alerts', (
          select count(*)
          from public.supervisor_alerts a
          where lower(coalesce(a.region, '')) = lower(coalesce(s.region, ''))
            and a.status = 'resolved'
            and a.resolved_at >= date_trunc('day', now())
        ),
        'completed_routes', (
          select count(*)
          from public.route_plans r
          join public.users u on u.id = r.assigned_to
          where u.role = 5
            and lower(coalesce(u.region, '')) = lower(coalesce(s.region, ''))
            and lower(coalesce(r.status, '')) = 'completed'
            and r.route_date = current_date
        )
      ),
      now()
    from public.users s
    where s.role = 3;
    get diagnostics batch_count = row_count;
    inserted_count := inserted_count + batch_count;
  end if;

  return inserted_count;
end;
$$;

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'isSynced') then
    alter table public.route_plans add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.catalog_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  sku text not null unique,
  item_type text not null default 'sale',
  unit_price numeric(12,2) not null default 0,
  stock_qty integer not null default 0,
  description text,
  is_active boolean not null default true,
  "isSynced" boolean not null default false,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'isSynced') then
    alter table public.catalog_items add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'is_active') then
    alter table public.catalog_items add column is_active boolean not null default true;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'item_type') then
    alter table public.catalog_items add column item_type text not null default 'sale';
  end if;
end $$;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references public.schools (id) on delete set null,
  school_name text not null,
  school_phone text,
  agent_id uuid references public.users (id) on delete set null,
  order_number text not null unique,
  payment_method text not null default 'cash',
  payment_reference text,
  checkout_amount numeric(12,2) not null default 0,
  status text not null default 'pending',
  notes text,
  submitted_at timestamptz,
  approved_at timestamptz,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'orders' and column_name = 'isSynced') then
    alter table public.orders add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_name text not null,
  category text,
  sku text,
  quantity integer not null default 1,
  unit_price numeric(12,2) not null default 0,
  line_total numeric(12,2) not null default 0,
  notes text,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'order_items' and column_name = 'isSynced') then
    alter table public.order_items add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.users (id) on delete cascade,
  recipient_id uuid not null references public.users (id) on delete cascade,
  subject text not null,
  body text not null,
  related_school_id uuid references public.schools (id) on delete set null,
  related_task_id uuid references public.tasks (id) on delete set null,
  is_read boolean not null default false,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'isSynced') then
    alter table public.messages add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.school_visits (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  outcome text,
  notes text,
  photo_url text,
  photo_path text,
  latitude double precision,
  longitude double precision,
  visit_status text not null default 'completed',
  visited_at timestamptz not null default now(),
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_visits' and column_name = 'isSynced') then
    alter table public.school_visits add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.school_follow_ups (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  contact_person text,
  next_step text,
  due_at timestamptz,
  notes text,
  follow_up_status text not null default 'open',
  completed_at timestamptz,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_follow_ups' and column_name = 'isSynced') then
    alter table public.school_follow_ups add column "isSynced" boolean not null default false;
  end if;
end $$;

create table if not exists public.debt_collections (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  collected_by uuid references public.users (id) on delete set null,
  amount numeric(12,2) not null check (amount > 0),
  payment_method text not null default 'cash',
  payment_reference text,
  notes text,
  collected_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.school_sales (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  package_name text not null,
  expected_value numeric(12,2),
  notes text,
  sale_status text not null default 'lead' check (
    sale_status in (
      'lead',
      'contacted',
      'meeting_scheduled',
      'sample_issued',
      'quotation_sent',
      'decision_pending',
      'negotiation',
      'won',
      'lost',
      'dormant'
    )
  ),
  stage_contact_person text,
  sample_quantity integer check (sample_quantity is null or sample_quantity >= 0),
  quotation_reference text,
  decision_owner text,
  negotiation_topic text,
  loss_reason text,
  dormant_reason text,
  stage_updated_at timestamptz,
  expected_close_date date,
  probability integer not null default 0 check (probability >= 0 and probability <= 100),
  closed_at timestamptz,
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'isSynced') then
    alter table public.school_sales add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'next_action') then
    alter table public.school_sales add column next_action text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'next_action_date') then
    alter table public.school_sales add column next_action_date date;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'last_activity_at') then
    alter table public.school_sales add column last_activity_at timestamptz;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'forecast_category') then
    alter table public.school_sales add column forecast_category text default 'pipeline';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'risk_level') then
    alter table public.school_sales add column risk_level text default 'low';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'weighted_forecast') then
    alter table public.school_sales add column weighted_forecast numeric(12,2) default 0;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'stage_sla_due_at') then
    alter table public.school_sales add column stage_sla_due_at timestamptz;
  end if;
end $$;

create index if not exists idx_school_sales_stage_sla_due_at
  on public.school_sales (stage_sla_due_at);
create index if not exists idx_school_sales_next_action_date
  on public.school_sales (next_action_date);
create index if not exists idx_school_sales_risk_level
  on public.school_sales (risk_level);

create table if not exists public.opportunity_activities (
  id uuid primary key default gen_random_uuid(),
  opportunity_id uuid not null references public.school_sales (id) on delete cascade,
  school_id uuid references public.schools (id) on delete set null,
  actor_id uuid references public.users (id) on delete set null,
  activity_type text not null,
  activity_outcome text,
  notes text,
  next_action text,
  next_action_date date,
  created_at timestamptz not null default now()
);

create index if not exists idx_opportunity_activities_opportunity
  on public.opportunity_activities (opportunity_id, created_at desc);

create or replace function public.refresh_school_sale_metrics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expected numeric(12,2) := coalesce(new.expected_value, 0);
  v_probability integer := coalesce(new.probability, 0);
  v_stage text := lower(coalesce(new.sale_status, 'lead'));
  v_sla_days integer := 5;
begin
  new.weighted_forecast := round((v_expected * v_probability) / 100.0, 2);

  if v_stage in ('lead', 'contacted') then
    v_sla_days := 3;
  elsif v_stage in ('meeting_scheduled', 'sample_issued') then
    v_sla_days := 5;
  elsif v_stage in ('quotation_sent', 'decision_pending', 'negotiation') then
    v_sla_days := 7;
  end if;

  if new.stage_sla_due_at is null then
    new.stage_sla_due_at := now() + make_interval(days => v_sla_days);
  end if;

  if v_stage in ('won', 'lost') then
    new.risk_level := 'low';
  elsif new.next_action_date is null then
    new.risk_level := 'high';
  elsif new.next_action_date < current_date then
    new.risk_level := 'high';
  elsif new.next_action_date <= current_date + 1 then
    new.risk_level := 'medium';
  else
    new.risk_level := 'low';
  end if;

  return new;
end;
$$;

drop trigger if exists derive_school_sale_metrics on public.school_sales;
create trigger derive_school_sale_metrics
before insert or update on public.school_sales
for each row execute procedure public.refresh_school_sale_metrics();

create or replace function public.enforce_school_sale_followup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stage text := lower(coalesce(new.sale_status, 'lead'));
begin
  if v_stage not in ('won', 'lost', 'dormant') then
    -- Auto-fill defaults during migration/legacy updates to avoid hard failures.
    if nullif(btrim(coalesce(new.next_action, '')), '') is null then
      new.next_action := 'Follow up call';
    end if;
    if new.next_action_date is null then
      new.next_action_date := current_date + 2;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_school_sale_followup_trigger on public.school_sales;
create trigger enforce_school_sale_followup_trigger
before insert or update on public.school_sales
for each row execute procedure public.enforce_school_sale_followup();

update public.school_sales
set
  next_action = coalesce(nullif(btrim(next_action), ''), 'Follow up call'),
  next_action_date = coalesce(next_action_date, current_date + 2)
where lower(coalesce(sale_status, 'lead')) not in ('won', 'lost', 'dormant')
  and (
    nullif(btrim(coalesce(next_action, '')), '') is null
    or next_action_date is null
  );

create or replace function public.sync_opportunity_activity_to_sale()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if nullif(btrim(coalesce(new.next_action, '')), '') is null then
    raise exception 'next_action is required when logging opportunity activity';
  end if;
  if new.next_action_date is null then
    raise exception 'next_action_date is required when logging opportunity activity';
  end if;

  update public.school_sales
  set
    last_activity_at = new.created_at,
    next_action = new.next_action,
    next_action_date = new.next_action_date,
    stage_updated_at = now()
  where id = new.opportunity_id;

  return new;
end;
$$;

drop trigger if exists sync_opportunity_activity_to_sale_trigger on public.opportunity_activities;
create trigger sync_opportunity_activity_to_sale_trigger
after insert on public.opportunity_activities
for each row execute procedure public.sync_opportunity_activity_to_sale();

create or replace function public.enforce_role5_task_completion_evidence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_role5 boolean := false;
  v_has_evidence boolean := false;
begin
  if lower(coalesce(new.status, '')) not in ('closed', 'completed') then
    return new;
  end if;

  if lower(coalesce(old.status, '')) in ('closed', 'completed') then
    return new;
  end if;

  select exists (
    select 1 from public.users u
    where u.id = new.assigned_to
      and u.role = 5
  ) into v_is_role5;

  if not v_is_role5 then
    return new;
  end if;

  select exists (
    select 1
    from public.task_completion_evidence e
    where e.task_id = new.id
      and e.gps_lat is not null
      and e.gps_lng is not null
      and nullif(btrim(coalesce(e.proof_url, '')), '') is not null
  ) into v_has_evidence;

  if not v_has_evidence then
    raise exception 'Role 5 task completion requires evidence with GPS and proof_url';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_role5_task_completion_evidence_trigger on public.tasks;
create trigger enforce_role5_task_completion_evidence_trigger
before update on public.tasks
for each row execute procedure public.enforce_role5_task_completion_evidence();

create or replace function public.generate_overdue_followup_alerts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
begin
  insert into public.supervisor_alerts (
    user_id,
    region,
    alert_type,
    severity,
    status,
    message,
    created_at
  )
  select
    s.agent_id as user_id,
    u.region,
    'overdue_followup',
    'amber',
    'open',
    'Opportunity follow-up is overdue for assigned Role 5 user.',
    now()
  from public.school_sales s
  join public.users u on u.id = s.agent_id
  where u.role = 5
    and s.next_action_date is not null
    and s.next_action_date < current_date
    and lower(coalesce(s.sale_status, '')) not in ('won', 'lost', 'dormant')
    and not exists (
      select 1
      from public.supervisor_alerts a
      where a.user_id = s.agent_id
        and a.alert_type = 'overdue_followup'
        and a.status = 'open'
        and a.created_at >= now() - interval '24 hours'
    );

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create table if not exists public.pipeline_history (
  id uuid primary key default gen_random_uuid(),
  pipeline_id uuid not null references public.school_sales (id) on delete cascade,
  old_stage text,
  new_stage text not null,
  changed_by uuid references public.users (id) on delete set null,
  changed_at timestamptz not null default now(),
  notes text
);

create index if not exists idx_pipeline_history_pipeline_id
  on public.pipeline_history (pipeline_id);

create index if not exists idx_pipeline_history_changed_at
  on public.pipeline_history (changed_at desc);

create or replace function public.log_pipeline_stage_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
    values (new.id, null, new.sale_status, auth.uid(), new.notes);
    return new;
  end if;

  if tg_op = 'UPDATE' and coalesce(new.sale_status, '') <> coalesce(old.sale_status, '') then
    insert into public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
    values (new.id, old.sale_status, new.sale_status, auth.uid(), new.notes);
  end if;

  return new;
end;
$$;

create table if not exists public.school_sample_distributions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  agent_id uuid references public.users (id) on delete set null,
  sample_name text not null,
  sample_category text,
  quantity integer not null default 1,
  stamped_receipt_url text,
  stamped_receipt_path text,
  notes text,
  distributed_at timestamptz not null default now(),
  "isSynced" boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'isSynced') then
    alter table public.school_sample_distributions add column "isSynced" boolean not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'stamped_receipt_url') then
    alter table public.school_sample_distributions add column stamped_receipt_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'stamped_receipt_path') then
    alter table public.school_sample_distributions add column stamped_receipt_path text;
  end if;
end $$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, full_name, phone, role, region)
  values (
    new.id,
    new.email,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 'Not Captured'),
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''), 'Not Captured'),
    public.role_id_from_text(new.raw_user_meta_data ->> 'role'),
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'region'), ''), 'Not Captured')
  )
  on conflict (id) do update
  set email = excluded.email,
      full_name = excluded.full_name,
      phone = excluded.phone,
      role = excluded.role,
      region = excluded.region;
  return new;
end;
$$;

create or replace function public.handle_updated_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.users
  set email = new.email,
      full_name = coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), full_name, 'Not Captured'),
      phone = coalesce(nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''), phone, 'Not Captured'),
      region = coalesce(nullif(btrim(new.raw_user_meta_data ->> 'region'), ''), region, 'Not Captured')
      -- Keep role untouched so admin changes in public.users are not overwritten by auth metadata.
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
after update on auth.users
for each row execute procedure public.handle_updated_user();

-- Backfill existing auth users into public.users so current accounts are linked too.
insert into public.users (id, email, full_name, phone, role, region)
select
  u.id,
  u.email,
  coalesce(nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''), 'Not Captured'),
  coalesce(nullif(btrim(u.raw_user_meta_data ->> 'phone'), ''), 'Not Captured'),
  public.role_id_from_text(u.raw_user_meta_data ->> 'role'),
  coalesce(nullif(btrim(u.raw_user_meta_data ->> 'region'), ''), 'Not Captured')
from auth.users u
on conflict (id) do update
set email = excluded.email,
    full_name = excluded.full_name,
    phone = excluded.phone,
    role = excluded.role,
    region = excluded.region;

drop trigger if exists touch_users_updated_at on public.users;
create trigger touch_users_updated_at
before update on public.users
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_schools_updated_at on public.schools;
create trigger touch_schools_updated_at
before update on public.schools
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_tasks_updated_at on public.tasks;
create trigger touch_tasks_updated_at
before update on public.tasks
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_geofences_updated_at on public.geofences;
create trigger touch_geofences_updated_at
before update on public.geofences
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_route_plans_updated_at on public.route_plans;
create trigger touch_route_plans_updated_at
before update on public.route_plans
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_catalog_items_updated_at on public.catalog_items;
create trigger touch_catalog_items_updated_at
before update on public.catalog_items
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_orders_updated_at on public.orders;
create trigger touch_orders_updated_at
before update on public.orders
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_order_items_updated_at on public.order_items;
create trigger touch_order_items_updated_at
before update on public.order_items
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_messages_updated_at on public.messages;
create trigger touch_messages_updated_at
before update on public.messages
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_school_visits_updated_at on public.school_visits;
create trigger touch_school_visits_updated_at
before update on public.school_visits
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_school_follow_ups_updated_at on public.school_follow_ups;
create trigger touch_school_follow_ups_updated_at
before update on public.school_follow_ups
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_debt_collections_updated_at on public.debt_collections;
create trigger touch_debt_collections_updated_at
before update on public.debt_collections
for each row execute procedure public.set_updated_at();

drop trigger if exists touch_school_sales_updated_at on public.school_sales;
create trigger touch_school_sales_updated_at
before update on public.school_sales
for each row execute procedure public.set_updated_at();

drop trigger if exists log_school_sales_stage_change on public.school_sales;
create trigger log_school_sales_stage_change
after insert or update on public.school_sales
for each row execute procedure public.log_pipeline_stage_change();

drop trigger if exists touch_school_sample_distributions_updated_at on public.school_sample_distributions;
create trigger touch_school_sample_distributions_updated_at
before update on public.school_sample_distributions
for each row execute procedure public.set_updated_at();

alter table public.users enable row level security;
alter table public.schools enable row level security;
alter table public.tasks enable row level security;
alter table public.geofences enable row level security;
alter table public.route_plans enable row level security;
alter table public.catalog_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.messages enable row level security;
alter table public.school_visits enable row level security;
alter table public.school_follow_ups enable row level security;
alter table public.debt_collections enable row level security;
alter table public.school_sales enable row level security;
alter table public.pipeline_history enable row level security;
alter table public.school_sample_distributions enable row level security;
alter table public.opportunity_activities enable row level security;
alter table public.geofence_events enable row level security;
alter table public.supervisor_alerts enable row level security;
alter table public.supervisor_incidents enable row level security;
alter table public.supervisor_notes enable row level security;
alter table public.audit_events enable row level security;
alter table public.task_completion_evidence enable row level security;
alter table public.supervisor_notifications enable row level security;

drop policy if exists "users_can_manage_own_row" on public.users;
create policy "users_can_manage_own_row"
on public.users
for all
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "authenticated_can_view_users" on public.users;
create policy "authenticated_can_view_users"
on public.users
for select
to authenticated
using (
  auth.uid() = id
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and role = 5
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "admins_can_manage_users" on public.users;
create policy "admins_can_manage_users"
on public.users
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "authenticated_can_manage_schools" on public.schools;
create policy "authenticated_can_manage_schools"
on public.schools
for all
to authenticated
using (true)
with check (true);

drop policy if exists "authenticated_can_view_assigned_tasks" on public.tasks;
create policy "authenticated_can_view_assigned_tasks"
on public.tasks
for select
to authenticated
using (
  target_role = 0
  or target_role >= public.current_user_role_id()
  or assigned_to = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.tasks.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

drop policy if exists "admins_can_manage_tasks" on public.tasks;
drop policy if exists "managers_can_manage_tasks" on public.tasks;
create policy "managers_can_manage_tasks"
on public.tasks
for all
to authenticated
using (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.tasks.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
)
with check (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.tasks.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

drop policy if exists "authenticated_can_view_geofences" on public.geofences;
create policy "authenticated_can_view_geofences"
on public.geofences
for select
to authenticated
using (
  assigned_to = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and (
      lower(coalesce(public.geofences.region, '')) = lower(coalesce(public.current_user_region(), ''))
      or exists (
        select 1
        from public.users u
        where u.id = public.geofences.assigned_to
          and u.role = 5
          and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
      )
    )
  )
);

drop policy if exists "managers_can_manage_geofences" on public.geofences;
create policy "managers_can_manage_geofences"
on public.geofences
for all
to authenticated
using (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and (
      lower(coalesce(public.geofences.region, '')) = lower(coalesce(public.current_user_region(), ''))
      or exists (
        select 1
        from public.users u
        where u.id = public.geofences.assigned_to
          and u.role = 5
          and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
      )
    )
  )
)
with check (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and (
      lower(coalesce(public.geofences.region, '')) = lower(coalesce(public.current_user_region(), ''))
      or exists (
        select 1
        from public.users u
        where u.id = public.geofences.assigned_to
          and u.role = 5
          and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
      )
    )
  )
);

drop policy if exists "authenticated_can_view_route_plans" on public.route_plans;
create policy "authenticated_can_view_route_plans"
on public.route_plans
for select
to authenticated
using (
  assigned_to = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.route_plans.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

drop policy if exists "managers_can_manage_route_plans" on public.route_plans;
create policy "managers_can_manage_route_plans"
on public.route_plans
for all
to authenticated
using (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.route_plans.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
)
with check (
  public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and exists (
      select 1
      from public.users u
      where u.id = public.route_plans.assigned_to
        and u.role = 5
        and lower(coalesce(u.region, '')) = lower(coalesce(public.current_user_region(), ''))
    )
  )
);

drop policy if exists "role5_can_submit_route_plans" on public.route_plans;
create policy "role5_can_submit_route_plans"
on public.route_plans
for update
to authenticated
using (assigned_to = auth.uid())
with check (
  assigned_to = auth.uid()
  and status in ('submitted', 'in_progress', 'completed')
);

drop policy if exists "authenticated_can_view_geofence_events" on public.geofence_events;
create policy "authenticated_can_view_geofence_events"
on public.geofence_events
for select
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "authenticated_can_manage_geofence_events" on public.geofence_events;
create policy "authenticated_can_manage_geofence_events"
on public.geofence_events
for all
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
)
with check (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "authenticated_can_view_supervisor_alerts" on public.supervisor_alerts;
create policy "authenticated_can_view_supervisor_alerts"
on public.supervisor_alerts
for select
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "managers_can_manage_supervisor_alerts" on public.supervisor_alerts;
create policy "managers_can_manage_supervisor_alerts"
on public.supervisor_alerts
for all
to authenticated
using (public.current_user_role_id() <= 3)
with check (public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_supervisor_incidents" on public.supervisor_incidents;
create policy "authenticated_can_view_supervisor_incidents"
on public.supervisor_incidents
for select
to authenticated
using (
  user_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "managers_can_manage_supervisor_incidents" on public.supervisor_incidents;
create policy "managers_can_manage_supervisor_incidents"
on public.supervisor_incidents
for all
to authenticated
using (public.current_user_role_id() <= 3)
with check (public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_supervisor_notes" on public.supervisor_notes;
create policy "authenticated_can_view_supervisor_notes"
on public.supervisor_notes
for select
to authenticated
using (
  user_id = auth.uid()
  or supervisor_id = auth.uid()
  or public.current_user_role_id() <= 2
  or (
    public.current_user_role_id() = 3
    and lower(coalesce(region, '')) = lower(coalesce(public.current_user_region(), ''))
  )
);

drop policy if exists "managers_can_manage_supervisor_notes" on public.supervisor_notes;
create policy "managers_can_manage_supervisor_notes"
on public.supervisor_notes
for all
to authenticated
using (supervisor_id = auth.uid() or public.current_user_role_id() <= 2)
with check (supervisor_id = auth.uid() or public.current_user_role_id() <= 2);

drop policy if exists "admins_can_view_audit_events" on public.audit_events;
create policy "admins_can_view_audit_events"
on public.audit_events
for select
to authenticated
using (public.current_user_role_id() <= 2);

drop policy if exists "managers_can_insert_audit_events" on public.audit_events;
create policy "managers_can_insert_audit_events"
on public.audit_events
for insert
to authenticated
with check (public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_task_completion_evidence" on public.task_completion_evidence;
create policy "authenticated_can_view_task_completion_evidence"
on public.task_completion_evidence
for select
to authenticated
using (
  submitted_by = auth.uid()
  or exists (
    select 1
    from public.tasks t
    where t.id = task_id
      and (t.assigned_to = auth.uid() or public.current_user_role_id() <= 3)
  )
);

drop policy if exists "authenticated_can_manage_task_completion_evidence" on public.task_completion_evidence;
create policy "authenticated_can_manage_task_completion_evidence"
on public.task_completion_evidence
for all
to authenticated
using (submitted_by = auth.uid() or public.current_user_role_id() <= 3)
with check (submitted_by = auth.uid() or public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_supervisor_notifications" on public.supervisor_notifications;
create policy "authenticated_can_view_supervisor_notifications"
on public.supervisor_notifications
for select
to authenticated
using (
  supervisor_id = auth.uid()
  or public.current_user_role_id() <= 2
);

drop policy if exists "authenticated_can_update_supervisor_notifications" on public.supervisor_notifications;
create policy "authenticated_can_update_supervisor_notifications"
on public.supervisor_notifications
for update
to authenticated
using (
  supervisor_id = auth.uid()
  or public.current_user_role_id() <= 2
)
with check (
  supervisor_id = auth.uid()
  or public.current_user_role_id() <= 2
);

drop policy if exists "managers_can_insert_supervisor_notifications" on public.supervisor_notifications;
create policy "managers_can_insert_supervisor_notifications"
on public.supervisor_notifications
for insert
to authenticated
with check (public.current_user_role_id() <= 3);

drop policy if exists "authenticated_can_view_catalog_items" on public.catalog_items;
create policy "authenticated_can_view_catalog_items"
on public.catalog_items
for select
to authenticated
using (is_active = true or public.is_manager_or_admin());

drop policy if exists "admins_can_manage_catalog_items" on public.catalog_items;
drop policy if exists "managers_can_manage_catalog_items" on public.catalog_items;
create policy "managers_can_manage_catalog_items"
on public.catalog_items
for all
to authenticated
using (public.is_manager_or_admin())
with check (public.is_manager_or_admin());

drop policy if exists "authenticated_can_view_orders" on public.orders;
create policy "authenticated_can_view_orders"
on public.orders
for select
to authenticated
using (
  agent_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_manage_orders" on public.orders;
create policy "authenticated_can_manage_orders"
on public.orders
for all
to authenticated
using (
  agent_id = auth.uid()
  or public.is_manager_or_admin()
)
with check (
  agent_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_view_order_items" on public.order_items;
create policy "authenticated_can_view_order_items"
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders
    where public.orders.id = order_id
      and (public.orders.agent_id = auth.uid() or public.is_manager_or_admin())
  )
);

drop policy if exists "authenticated_can_manage_order_items" on public.order_items;
create policy "authenticated_can_manage_order_items"
on public.order_items
for all
to authenticated
using (
  exists (
    select 1
    from public.orders
    where public.orders.id = order_id
      and (public.orders.agent_id = auth.uid() or public.is_manager_or_admin())
  )
)
with check (
  exists (
    select 1
    from public.orders
    where public.orders.id = order_id
      and (public.orders.agent_id = auth.uid() or public.is_manager_or_admin())
  )
);

drop policy if exists "authenticated_can_view_messages" on public.messages;
create policy "authenticated_can_view_messages"
on public.messages
for select
to authenticated
using (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_send_messages" on public.messages;
create policy "authenticated_can_send_messages"
on public.messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_update_messages" on public.messages;
create policy "authenticated_can_update_messages"
on public.messages
for update
to authenticated
using (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or public.is_manager_or_admin()
)
with check (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "authenticated_can_delete_messages" on public.messages;
create policy "authenticated_can_delete_messages"
on public.messages
for delete
to authenticated
using (
  sender_id = auth.uid()
  or recipient_id = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "agents_can_manage_school_visits" on public.school_visits;
create policy "agents_can_manage_school_visits"
on public.school_visits
for all
to authenticated
using (agent_id = auth.uid() or public.is_manager_or_admin())
with check (agent_id = auth.uid() or public.is_manager_or_admin());

drop policy if exists "agents_can_manage_school_follow_ups" on public.school_follow_ups;
create policy "agents_can_manage_school_follow_ups"
on public.school_follow_ups
for all
to authenticated
using (agent_id = auth.uid() or public.is_manager_or_admin())
with check (agent_id = auth.uid() or public.is_manager_or_admin());

drop policy if exists "authenticated_can_manage_debt_collections" on public.debt_collections;
create policy "authenticated_can_manage_debt_collections"
on public.debt_collections
for all
to authenticated
using (collected_by = auth.uid() or public.is_manager_or_admin())
with check (collected_by = auth.uid() or public.is_manager_or_admin());

drop policy if exists "agents_can_manage_school_sales" on public.school_sales;
create policy "agents_can_manage_school_sales"
on public.school_sales
for all
to authenticated
using (agent_id = auth.uid() or public.is_manager_or_admin())
with check (agent_id = auth.uid() or public.is_manager_or_admin());

drop policy if exists "authenticated_can_view_opportunity_activities" on public.opportunity_activities;
create policy "authenticated_can_view_opportunity_activities"
on public.opportunity_activities
for select
to authenticated
using (
  actor_id = auth.uid()
  or exists (
    select 1
    from public.school_sales s
    where s.id = opportunity_id
      and (s.agent_id = auth.uid() or public.current_user_role_id() <= 3)
  )
);

drop policy if exists "authenticated_can_manage_opportunity_activities" on public.opportunity_activities;
create policy "authenticated_can_manage_opportunity_activities"
on public.opportunity_activities
for all
to authenticated
using (
  actor_id = auth.uid()
  or public.current_user_role_id() <= 3
)
with check (
  actor_id = auth.uid()
  or public.current_user_role_id() <= 3
);

drop policy if exists "authenticated_can_view_pipeline_history" on public.pipeline_history;
create policy "authenticated_can_view_pipeline_history"
on public.pipeline_history
for select
to authenticated
using (
  exists (
    select 1
    from public.school_sales s
    where s.id = pipeline_id
      and (s.agent_id = auth.uid() or public.is_manager_or_admin())
  )
);

drop policy if exists "agents_can_manage_school_sample_distributions" on public.school_sample_distributions;
create policy "agents_can_manage_school_sample_distributions"
on public.school_sample_distributions
for all
to authenticated
using (agent_id = auth.uid() or public.is_manager_or_admin())
with check (agent_id = auth.uid() or public.is_manager_or_admin());

-- END FILE: supabase/schema.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates.sql
-- =========================================================
-- Updates for newly added Dashboard, Analytics, Geofencing, and Assignment features

-- 0. Update Tasks Table for Individual Assignment and Time Filtering
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS due_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS target_role INTEGER NOT NULL DEFAULT 2;

-- 0b. Schools table updates for onboarding tracking + external discovery
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS external_place_id TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS external_vicinity TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_name TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_title TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS feedback TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS samples_left TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS sample_book TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_ownership TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_ownership_other TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_population INTEGER;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_lifecycle_status TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS engagement_type TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS dealer_type TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS shop_category TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS selected_product TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS partner_subtype TEXT;
ALTER TABLE public.school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_url TEXT;
ALTER TABLE public.school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_path TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_schools_external_place_id
ON public.schools (external_place_id)
WHERE external_place_id IS NOT NULL;

DO $$ BEGIN
    ALTER TABLE public.schools
    DROP CONSTRAINT IF EXISTS schools_source_check;
    ALTER TABLE public.schools
    ADD CONSTRAINT schools_source_check CHECK (source IN ('manual', 'google'));
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- 1. Route Plans Table
CREATE TABLE IF NOT EXISTS public.route_plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'Route Plan',
    route_date DATE NOT NULL DEFAULT CURRENT_DATE,
    assigned_to UUID REFERENCES public.users(id) ON DELETE CASCADE,
    school_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'assigned',
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Geofences Table
CREATE TABLE IF NOT EXISTS public.geofences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    coordinates JSONB NOT NULL DEFAULT '[]'::jsonb,
    assigned_to UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. School Sample Distributions Table
CREATE TABLE IF NOT EXISTS public.school_sample_distributions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    agent_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    sample_name TEXT NOT NULL,
    sample_category TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    distributed_at TIMESTAMP WITH TIME ZONE,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3b. Debt Collections Table
CREATE TABLE IF NOT EXISTS public.debt_collections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    collected_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_reference TEXT,
    notes TEXT,
    collected_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Catalog Items Table
CREATE TABLE IF NOT EXISTS public.catalog_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,
    sku TEXT UNIQUE,
    item_type TEXT NOT NULL DEFAULT 'sale',
    unit_price NUMERIC(12,2) NOT NULL DEFAULT 0,
    stock_qty INTEGER NOT NULL DEFAULT 0,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Orders Table (For Revenue Analytics)
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL,
    school_name TEXT NOT NULL,
    school_phone TEXT,
    agent_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    order_number TEXT UNIQUE,
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_reference TEXT,
    checkout_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending',
    notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. School Sales Pipeline migrations
-- Source of truth schema lives in schema.sql; keep only ALTER/DO migrations here.

DO $$ BEGIN
    ALTER TABLE public.school_sales
        ADD COLUMN IF NOT EXISTS stage_contact_person TEXT,
        ADD COLUMN IF NOT EXISTS sample_quantity INTEGER,
        ADD COLUMN IF NOT EXISTS quotation_reference TEXT,
        ADD COLUMN IF NOT EXISTS decision_owner TEXT,
        ADD COLUMN IF NOT EXISTS negotiation_topic TEXT,
        ADD COLUMN IF NOT EXISTS loss_reason TEXT,
        ADD COLUMN IF NOT EXISTS dormant_reason TEXT,
        ADD COLUMN IF NOT EXISTS stage_updated_at TIMESTAMP WITH TIME ZONE,
        ADD COLUMN IF NOT EXISTS expected_close_date DATE,
        ADD COLUMN IF NOT EXISTS probability INTEGER NOT NULL DEFAULT 0;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.pipeline_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pipeline_id UUID NOT NULL REFERENCES public.school_sales(id) ON DELETE CASCADE,
    old_stage TEXT,
    new_stage TEXT NOT NULL,
    changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_pipeline_id
ON public.pipeline_history (pipeline_id);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_changed_at
ON public.pipeline_history (changed_at DESC);

CREATE OR REPLACE FUNCTION public.log_pipeline_stage_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, NULL, NEW.sale_status, auth.uid(), NEW.notes);
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND coalesce(NEW.sale_status, '') <> coalesce(OLD.sale_status, '') THEN
        INSERT INTO public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, OLD.sale_status, NEW.sale_status, auth.uid(), NEW.notes);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_school_sales_stage_change ON public.school_sales;
CREATE TRIGGER log_school_sales_stage_change
AFTER INSERT OR UPDATE ON public.school_sales
FOR EACH ROW EXECUTE PROCEDURE public.log_pipeline_stage_change();

DO $$ BEGIN
    UPDATE public.school_sales
    SET sale_status = 'lead'
    WHERE sale_status IN ('draft', 'pipeline') OR sale_status IS NULL;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE public.school_sales
    ALTER COLUMN sale_status SET DEFAULT 'lead';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE public.school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sale_status_check;
    ALTER TABLE public.school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sample_quantity_check;
    ALTER TABLE public.school_sales
    ADD CONSTRAINT school_sales_sale_status_check CHECK (
        sale_status IN (
            'lead',
            'contacted',
            'meeting_scheduled',
            'sample_issued',
            'quotation_sent',
            'decision_pending',
            'negotiation',
            'won',
            'lost',
            'dormant'
        )
    );
    ALTER TABLE public.school_sales
    ADD CONSTRAINT school_sales_sample_quantity_check CHECK (
        sample_quantity IS NULL OR sample_quantity >= 0
    );
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Enable Row Level Security (RLS) on all new tables
ALTER TABLE public.route_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geofences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_sample_distributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pipeline_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_collections ENABLE ROW LEVEL SECURITY;

-- Optional: Re-create missing permissive policies if needed
-- (Your schema.sql handles granular RLS policies already, these act as fallbacks if missing)
DO $$ BEGIN
    CREATE POLICY "Allow authenticated full access on route_plans" ON public.route_plans FOR ALL TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_pipeline_history"
    ON public.pipeline_history
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.school_sales s
        WHERE s.id = pipeline_id
          AND (s.agent_id = auth.uid() OR public.is_manager_or_admin())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_delete_messages"
    ON public.messages
    FOR DELETE
    TO authenticated
    USING (
      sender_id = auth.uid()
      OR recipient_id = auth.uid()
      OR public.is_manager_or_admin()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_manage_debt_collections"
    ON public.debt_collections
    FOR ALL
    TO authenticated
    USING (collected_by = auth.uid() OR public.is_manager_or_admin())
    WITH CHECK (collected_by = auth.uid() OR public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Social inbox sync tables for Facebook + WhatsApp bot
CREATE TABLE IF NOT EXISTS public.social_conversations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    channel text NOT NULL CHECK (channel IN ('facebook', 'whatsapp')),
    external_conversation_id text NOT NULL,
    participant_display text,
    participant_phone text,
    last_message_preview text,
    last_message_at timestamptz,
    raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE (channel, external_conversation_id)
);

CREATE TABLE IF NOT EXISTS public.social_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id uuid NOT NULL REFERENCES public.social_conversations(id) ON DELETE CASCADE,
    channel text NOT NULL CHECK (channel IN ('facebook', 'whatsapp')),
    external_message_id text NOT NULL,
    sender_name text,
    sender_id text,
    body text,
    sent_at timestamptz,
    raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
    UNIQUE (channel, external_message_id)
);

ALTER TABLE public.social_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.social_messages ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_social_conversations"
    ON public.social_conversations
    FOR SELECT
    TO authenticated
    USING (public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "service_role_can_manage_social_conversations"
    ON public.social_conversations
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_social_messages"
    ON public.social_messages
    FOR SELECT
    TO authenticated
    USING (public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "service_role_can_manage_social_messages"
    ON public.social_messages
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Stamped sample proof fields on schools
ALTER TABLE public.schools
ADD COLUMN IF NOT EXISTS sample_proof_url TEXT;

ALTER TABLE public.schools
ADD COLUMN IF NOT EXISTS sample_proof_path TEXT;

-- ROI support for sample distribution (Role 5 and admin analytics)
CREATE INDEX IF NOT EXISTS idx_sample_distributions_agent_school
ON public.school_sample_distributions (agent_id, school_id, distributed_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_agent_status
ON public.orders (agent_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_school_sales_agent_stage
ON public.school_sales (agent_id, sale_status, created_at DESC);

CREATE OR REPLACE VIEW public.v_agent_sample_roi AS
WITH sample_stats AS (
  SELECT
    d.agent_id,
    COALESCE(SUM(d.quantity), 0)::int AS samples_given,
    COUNT(DISTINCT d.school_id)::int AS schools_reached
  FROM public.school_sample_distributions d
  WHERE d.agent_id IS NOT NULL
  GROUP BY d.agent_id
),
revenue_stats AS (
  SELECT
    o.agent_id,
    COALESCE(
      SUM(
        CASE
          WHEN LOWER(COALESCE(o.status, '')) IN ('approved', 'paid')
          THEN COALESCE(o.checkout_amount, 0)
          ELSE 0
        END
      ),
      0
    )::numeric(12,2) AS revenue_earned
  FROM public.orders o
  WHERE o.agent_id IS NOT NULL
  GROUP BY o.agent_id
),
won_stats AS (
  SELECT
    s.agent_id,
    COALESCE(
      SUM(
        CASE
          WHEN LOWER(COALESCE(s.sale_status, '')) = 'won'
          THEN COALESCE(s.expected_value, 0)
          ELSE 0
        END
      ),
      0
    )::numeric(12,2) AS won_value
  FROM public.school_sales s
  WHERE s.agent_id IS NOT NULL
  GROUP BY s.agent_id
)
SELECT
  u.id AS agent_id,
  COALESCE(u.full_name, u.email, 'Unknown User') AS agent_name,
  COALESCE(ss.samples_given, 0) AS samples_given,
  COALESCE(ss.schools_reached, 0) AS schools_reached,
  COALESCE(rs.revenue_earned, 0)::numeric(12,2) AS revenue_earned,
  COALESCE(ws.won_value, 0)::numeric(12,2) AS won_value
FROM public.users u
LEFT JOIN sample_stats ss ON ss.agent_id = u.id
LEFT JOIN revenue_stats rs ON rs.agent_id = u.id
LEFT JOIN won_stats ws ON ws.agent_id = u.id
WHERE u.role IN (4, 5);

-- END FILE: supabase/schema_updates.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates_project_forms.sql
-- =========================================================
-- Project forms persistence for Admin publish -> Role 5 quick actions

create table if not exists public.project_forms (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  questions jsonb not null default '[]'::jsonb,
  assigned_user_ids uuid[] not null default '{}',
  published_at timestamptz not null default now(),
  created_by uuid references public.users (id) on delete set null,
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'project_forms'
      and column_name = 'assigned_user_ids'
  ) then
    alter table public.project_forms
      add column assigned_user_ids uuid[] not null default '{}';
  end if;
end $$;

create index if not exists idx_project_forms_published_at
  on public.project_forms (published_at desc);

alter table public.project_forms enable row level security;

drop policy if exists "authenticated_can_view_project_forms" on public.project_forms;
create policy "authenticated_can_view_project_forms"
on public.project_forms
for select
to authenticated
using (
  public.is_manager_or_admin()
  or auth.uid() = any (assigned_user_ids)
);

drop policy if exists "managers_can_publish_project_forms" on public.project_forms;
create policy "managers_can_publish_project_forms"
on public.project_forms
for insert
to authenticated
with check (public.is_manager_or_admin());

create table if not exists public.project_form_responses (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.project_forms (id) on delete cascade,
  form_title text not null,
  respondent_id uuid not null references public.users (id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_project_form_responses_form_title
  on public.project_form_responses (form_title);

create index if not exists idx_project_form_responses_submitted_at
  on public.project_form_responses (submitted_at desc);

alter table public.project_form_responses enable row level security;

drop policy if exists "assigned_users_can_submit_project_form_responses" on public.project_form_responses;
create policy "assigned_users_can_submit_project_form_responses"
on public.project_form_responses
for insert
to authenticated
with check (
  exists (
    select 1
    from public.project_forms f
    where f.id = project_form_responses.form_id
      and auth.uid() = any (f.assigned_user_ids)
  )
  and respondent_id = auth.uid()
);

drop policy if exists "managers_can_view_project_form_responses" on public.project_form_responses;
create policy "managers_can_view_project_form_responses"
on public.project_form_responses
for select
to authenticated
using (public.is_manager_or_admin());

-- Dummy data for testing (safe to re-run)
-- Assumes seeded users exist:
-- admin:   11111111-1111-1111-1111-111111111111
-- role 5:  bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb

insert into public.project_forms (
  id,
  title,
  description,
  questions,
  assigned_user_ids,
  published_at,
  created_by
)
values
  (
    'a1a1a1a1-1111-4444-8888-111111111111',
    'Term 2 School Readiness Check',
    'Collect readiness data from assigned schools before term opening.',
    '[
      {"title":"School Name","type":"shortAnswer","required":true,"options":[]},
      {"title":"Visit Date","type":"datePicker","required":true,"options":[]},
      {"title":"Head Teacher Contact","type":"phoneNumberInput","required":true,"options":[]},
      {"title":"Books Received?","type":"toggleSwitch","required":true,"options":[]},
      {"title":"Readiness Rating","type":"linearScale","required":true,"options":["1","2","3","4","5","6","7","8","9","10"]}
    ]'::jsonb,
    array['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid],
    now() - interval '2 days',
    '11111111-1111-1111-1111-111111111111'::uuid
  ),
  (
    'a2a2a2a2-2222-4444-8888-222222222222',
    'Weekly Route Feedback Form',
    'Capture route-level observations and blockers.',
    '[
      {"title":"Route Name","type":"shortAnswer","required":true,"options":[]},
      {"title":"Arrival Time","type":"timePicker","required":true,"options":[]},
      {"title":"Main Challenge","type":"paragraph","required":true,"options":[]},
      {"title":"Evidence Upload","type":"fileUpload","required":false,"options":[]},
      {"title":"Overall Experience","type":"ratingScale","required":true,"options":["1","2","3","4","5"]}
    ]'::jsonb,
    array['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid],
    now() - interval '1 day',
    '11111111-1111-1111-1111-111111111111'::uuid
  )
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  questions = excluded.questions,
  assigned_user_ids = excluded.assigned_user_ids,
  published_at = excluded.published_at,
  created_by = excluded.created_by;

insert into public.project_form_responses (
  id,
  form_id,
  form_title,
  respondent_id,
  answers,
  submitted_at
)
values
  (
    'b1b1b1b1-1111-4444-9999-111111111111',
    'a1a1a1a1-1111-4444-8888-111111111111'::uuid,
    'Term 2 School Readiness Check',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
    '{
      "School Name":"Nairobi Primary",
      "Visit Date":"2026-05-20",
      "Head Teacher Contact":"+254700123456",
      "Books Received?":"Yes",
      "Readiness Rating":"8"
    }'::jsonb,
    now() - interval '20 hours'
  ),
  (
    'b2b2b2b2-2222-4444-9999-222222222222',
    'a2a2a2a2-2222-4444-8888-222222222222'::uuid,
    'Weekly Route Feedback Form',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
    '{
      "Route Name":"Kisumu West Cluster",
      "Arrival Time":"09:10",
      "Main Challenge":"Delayed handover at first school.",
      "Evidence Upload":"route-photo-2026-05-21.jpg",
      "Overall Experience":"4"
    }'::jsonb,
    now() - interval '10 hours'
  )
on conflict (id) do update set
  form_id = excluded.form_id,
  form_title = excluded.form_title,
  respondent_id = excluded.respondent_id,
  answers = excluded.answers,
  submitted_at = excluded.submitted_at;

-- END FILE: supabase/schema_updates_project_forms.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates_sample_proof.sql
-- =========================================================
-- Add stamped sample proof fields on schools
begin;

alter table public.schools
  add column if not exists sample_proof_url text;

alter table public.schools
  add column if not exists sample_proof_path text;

commit;

-- END FILE: supabase/schema_updates_sample_proof.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates_tasks_pipeline.sql
-- =========================================================
-- Task + pipeline SQL updates for dashboard filtering and consistency

begin;

-- 1) Normalize task statuses before adding constraint
update public.tasks
set status = 'closed'
where lower(status) in ('complete', 'completed', 'done');

update public.tasks
set status = 'in_progress'
where lower(status) in ('in progress', 'progress');

update public.tasks
set status = 'open'
where lower(status) not in ('open', 'in_progress', 'closed');

-- 2) Enforce allowed task statuses
alter table public.tasks
  drop constraint if exists tasks_status_check;

alter table public.tasks
  add constraint tasks_status_check
  check (status in ('open', 'in_progress', 'closed'));

-- 3) Helpful indexes for admin dashboard filters
create index if not exists idx_tasks_status_due_at
  on public.tasks (status, due_at);

create index if not exists idx_tasks_target_role_status
  on public.tasks (target_role, status);

create index if not exists idx_school_sales_stage_updated_at
  on public.school_sales (sale_status, stage_updated_at desc);

commit;

-- END FILE: supabase/schema_updates_tasks_pipeline.sql

-- =========================================================
-- BEGIN FILE: supabase/seed.sql
-- =========================================================
-- ==========================================
-- Dummy Data Seed Script for Dehus App
-- Run this in your Supabase SQL Editor
-- ==========================================

-- 1. Insert Dummy Schools
INSERT INTO public.schools (
  id,
  name,
  phone,
  county,
  "focusAreas",
  book_category,
  latitude,
  longitude,
  photo_url,
  photo_path,
  capture_status,
  captured_by,
  captured_at,
  "isSynced"
)
VALUES 
  ('22222222-2222-2222-2222-222222222222', 'Nairobi Primary School', '0712345678', 'Nairobi', '["Mathematics", "Science"]'::jsonb, 'Book List', -1.2921, 36.8219, 'https://images.unsplash.com/photo-1503676260728-1c00da094a0b', 'schools/nairobi-primary.jpg', 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true),
  ('33333333-3333-3333-3333-333333333333', 'Mombasa High School', '0723456789', 'Mombasa', '["Languages", "Arts"]'::jsonb, 'Book Fund', -4.0435, 39.6682, 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1', 'schools/mombasa-high.jpg', 'Photo captured successfully', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true),
  ('44444444-4444-4444-4444-444444444444', 'Kisumu Boys', '0734567890', 'Kisumu', '["Sports", "Science"]'::jsonb, NULL, -0.1022, 34.7617, NULL, NULL, 'Location not captured yet', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true),
  ('55555555-5555-5555-5555-555555555555', 'Nakuru Girls', '0745678901', 'Nakuru', '["Mathematics", "Business"]'::jsonb, 'Book List', -0.3031, 36.0800, 'https://images.unsplash.com/photo-1497486751825-1233686d5d80', 'schools/nakuru-girls.jpg', 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true),
  ('66666666-6666-6666-6666-666666666666', 'Eldoret Academy', '0756789012', 'Uasin Gishu', '["Agriculture", "Science"]'::jsonb, NULL, 0.5143, 35.2698, NULL, NULL, 'Photo captured successfully', '11111111-1111-1111-1111-111111111111', now() - interval '1 day', true)
ON CONFLICT (id) DO UPDATE
SET name = excluded.name,
    phone = excluded.phone,
    county = excluded.county,
    "focusAreas" = excluded."focusAreas",
    book_category = excluded.book_category,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    photo_url = excluded.photo_url,
    photo_path = excluded.photo_path,
    capture_status = excluded.capture_status,
    captured_by = excluded.captured_by,
    captured_at = excluded.captured_at,
    "isSynced" = excluded."isSynced";

-- 2. Insert Dummy Tasks
-- Note: We assign these to roles (e.g., target_role = 2, 3, or 4) so they show up for everyone in those roles
INSERT INTO public.tasks (title, description, target_role, status, due_at, "isSynced")
VALUES
  ('Follow up with Nairobi Primary', 'Discuss the new curriculum books.', 2, 'open', now() + interval '2 days', true),
  ('Deliver supplies to Mombasa High', 'Ensure all requested materials are delivered.', 3, 'open', now() + interval '5 days', true),
  ('Check in on Kisumu Boys', 'Monthly routine check-in.', 3, 'in_progress', now() + interval '1 day', true),
  ('Nakuru Girls Evaluation', 'Evaluate the newly introduced testing methods.', 2, 'open', now() + interval '7 days', true),
  ('Eldoret Academy Proposal', 'Present the new business proposal to the principal.', 3, 'closed', now() - interval '1 day', true),
  ('Quarterly Regional Review', 'Review quarterly numbers for all coastal schools.', 2, 'open', now() + interval '14 days', true);

-- 3. Insert Dummy Geofences
-- Coordinates are stored as a JSONB array of objects matching your flutter map data structure
INSERT INTO public.geofences (name, description, region, coordinates)
VALUES
  ('Nairobi CBD Zone', 'Cover all schools within the central business district.', 'Nairobi', '[{"lat": -1.286389, "lng": 36.817223, "radius": 2000}]'::jsonb),
  ('Mombasa Island Area', 'Target coastal schools.', 'Mombasa', '[{"lat": -4.043477, "lng": 39.668206, "radius": 3500}]'::jsonb),
  ('Kisumu Lakefront', 'Schools near the lake area.', 'Kisumu', '[{"lat": -0.102210, "lng": 34.761713, "radius": 1500}]'::jsonb),
  ('Nakuru Town Center', 'Coverage area for central Nakuru.', 'Nakuru', '[{"lat": -0.303099, "lng": 36.080025, "radius": 2500}]'::jsonb);

-- ==========================================
-- 4. Insert Dummy Users with Different Roles
-- ==========================================
-- We insert directly into Supabase's auth.users table so they can actually log in.
-- Your database triggers will automatically map them into the public.users table.
--
-- All generated users use the password: password123
-- Add "region" to raw_user_meta_data if you want the trigger to populate users.region.

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alice.manager@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Alice Manager", "role": 2, "region": "Nairobi"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bob.bas@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Bob BAS", "role": 3, "region": "Coast"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'charlie.agent@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Charlie Agent", "role": 4, "region": "Rift Valley"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'diana.sales@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Diana Sales", "role": 2, "region": "Western"}', now(), now()),
  (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'edward.other@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Edward Grounds", "role": 5, "region": "Nyanza"}', now(), now())
ON CONFLICT DO NOTHING;

-- 4b. Dedicated field-agent workload data
-- Fixed UUID keeps the agent-linked tasks and geofence references stable across reruns.
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'faith.agent@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Faith Agent", "role": 4, "region": "Nairobi"}', now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.tasks (title, description, target_role, assigned_to, status, due_at, "isSynced")
VALUES
  ('Visit Nairobi Primary School', 'Confirm the current book list and capture the headteacher feedback.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '1 day', true),
  ('Follow up with Makueni High School', 'Call the school and confirm the book fund decision.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '2 days', true),
  ('Sell book fund package to Bora Education Centre', 'Present the offer and record the response.', 4, '11111111-1111-1111-1111-111111111111', 'in_progress', now() + interval '3 days', true),
  ('Check sample delivery for Green Pastures Academy', 'Make sure sample books were received and logged.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '4 days', true);

INSERT INTO public.geofences (name, description, region, coordinates, assigned_to)
VALUES
  ('Nairobi Field Agent Zone', 'Primary school coverage for the Nairobi field agent.', 'Nairobi', '[{"lat": -1.2921, "lng": 36.8219, "radius": 4000}]'::jsonb, '11111111-1111-1111-1111-111111111111'),
  ('Kiambu Visit Corridor', 'Support schools along the Kiambu route.', 'Kiambu', '[{"lat": -1.1714, "lng": 36.8356, "radius": 2500}]'::jsonb, '11111111-1111-1111-1111-111111111111');

INSERT INTO public.route_plans (
  id,
  title,
  route_date,
  assigned_to,
  school_ids,
  notes,
  status,
  created_by,
  "isSynced"
)
VALUES
  (
    '77777777-7777-7777-7777-777777777777',
    'Faith Agent Route Plan',
    current_date,
    '11111111-1111-1111-1111-111111111111',
    '["22222222-2222-2222-2222-222222222222", "33333333-3333-3333-3333-333333333333", "55555555-5555-5555-5555-555555555555"]'::jsonb,
    'Morning route covering Nairobi Primary, Mombasa High and Nakuru Girls.',
    'assigned',
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    '88888888-8888-8888-8888-888888888888',
    'BAS Coastal Route Plan',
    current_date + 1,
    '11111111-1111-1111-1111-111111111111',
    '["33333333-3333-3333-3333-333333333333", "44444444-4444-4444-4444-444444444444"]'::jsonb,
    'Follow-up route with Mombasa and Kisumu school visits.',
    'draft',
    '11111111-1111-1111-1111-111111111111',
    true
  )
ON CONFLICT (id) DO UPDATE
SET title = excluded.title,
    route_date = excluded.route_date,
    assigned_to = excluded.assigned_to,
    school_ids = excluded.school_ids,
    notes = excluded.notes,
    status = excluded.status,
    "isSynced" = excluded."isSynced";

INSERT INTO public.school_visits (
  school_id,
  agent_id,
  outcome,
  notes,
  photo_url,
  photo_path,
  latitude,
  longitude,
  visit_status,
  visited_at,
  "isSynced"
)
VALUES
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Principal interested in book list', 'Reviewed the English and Mathematics book list and captured follow-up needs.', 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655', 'visits/nairobi-primary-2026-05-09.jpg', -1.292100, 36.821900, 'completed', now() - interval '1 day', true),
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Book fund discussed', 'The school requested a formal package presentation next week.', 'https://images.unsplash.com/photo-1504384308090-c894fdcc538d', 'visits/mombasa-high-2026-05-08.jpg', -4.043500, 39.668200, 'completed', now() - interval '3 days', true),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Sample delivery confirmed', 'Sample books delivered and logged by the librarian.', NULL, NULL, -0.303100, 36.080000, 'completed', now() - interval '5 days', true),
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Initial introduction visit', 'Met the deputy principal and left a price list for the book list package.', 'https://images.unsplash.com/photo-1488190211105-8b0e65b80b4e', 'visits/kisumu-boys-2026-05-06.jpg', -0.102200, 34.761700, 'completed', now() - interval '7 days', true),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Follow-up visit on proposal', 'Reviewed the book fund quotation and answered questions about delivery timelines.', NULL, 'visits/eldoret-academy-2026-05-04.jpg', 0.514300, 35.269800, 'completed', now() - interval '9 days', true);

INSERT INTO public.school_follow_ups (
  school_id,
  agent_id,
  contact_person,
  next_step,
  due_at,
  notes,
  follow_up_status,
  completed_at,
  "isSynced"
)
VALUES
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Deputy Principal', 'Confirm book list choice and pricing.', now() + interval '2 days', 'Left the school with a brochure and sample request form.', 'open', NULL, true),
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Procurement Lead', 'Send book fund proposal via email.', now() + interval '1 day', 'Awaiting budget approval.', 'open', NULL, true),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Head Teacher', 'Schedule a follow-up call after the staff meeting.', now() + interval '4 days', 'Initial visit was positive.', 'open', NULL, true),
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Head of Department', 'Confirm teacher sample feedback and next steps.', now() + interval '3 days', 'Waiting for the head teacher to approve the quote.', 'open', NULL, true),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Library Assistant', 'Check if the book list order can be placed this week.', now() + interval '5 days', 'The library team asked for a revised package summary.', 'open', NULL, true);

INSERT INTO public.school_sales (
  school_id,
  agent_id,
  package_name,
  expected_value,
  notes,
  sale_status,
  stage_contact_person,
  quotation_reference,
  decision_owner,
  closed_at,
  "isSynced"
)
VALUES
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Book Fund Starter Package', 15000.00, 'Proposal shared during visit; awaiting confirmation.', 'decision_pending', 'Procurement Chair', NULL, 'Principal', NULL, true),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Book List Bundle', 9800.00, 'Request received from the principal for a refined quote.', 'quotation_sent', 'Deputy Principal', 'QT-2026-0555', NULL, NULL, true),
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Core Reader Package', 7200.00, 'Sale agreed in principle, waiting on payment date.', 'won', 'HOD English', NULL, NULL, now() - interval '2 hours', true),
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Starter School Bundle', 5600.00, 'Quoted during the first school visit and shared with the department head.', 'contacted', 'Deputy Principal', NULL, NULL, NULL, true),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Premium Book Fund Package', 22000.00, 'Proposal delivered after the follow-up meeting.', 'lead', NULL, NULL, NULL, NULL, true);

INSERT INTO public.school_sample_distributions (
  school_id,
  agent_id,
  sample_name,
  sample_category,
  quantity,
  notes,
  distributed_at,
  "isSynced"
)
VALUES
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Grade 1 Reader Pack', 'Primary', 2, 'Handed to the English panel lead.', now() - interval '1 day', true),
  ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Teacher Guide Kit', 'Reference', 1, 'Left with the procurement desk.', now() - interval '3 days', true),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Story Books Pack', 'Primary', 3, 'Sample set used for classroom demo.', now() - interval '5 days', true),
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Science Reader Sample', 'Secondary', 2, 'Used during the deputy principal demonstration.', now() - interval '7 days', true),
  ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Book Fund Overview Pack', 'Proposal', 1, 'Left with the head teacher after the presentation.', now() - interval '9 days', true);

-- 4c. Role 5 / grounds person demo data
-- This lets the same alerts view render with real assignments for role 5 users too.
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'grounds.role5@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Grounds Role5", "role": 5, "region": "Nyanza"}', now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.tasks (title, description, target_role, assigned_to, status, due_at, "isSynced")
VALUES
  ('Inspect Nyanza school route', 'Verify access roads and confirm the route timing for the day.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now() + interval '1 day', true),
  ('Check delivery point at Kisumu Boys', 'Confirm the unloading area and school contact point.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now() + interval '2 days', true);

INSERT INTO public.geofences (id, name, description, region, coordinates, assigned_to)
VALUES
  (
    '99999999-9999-9999-9999-999999999999',
    'Nyanza Grounds Coverage',
    'Coverage area for the role 5 demo user.',
    'Kisumu',
    '[{"lat": -0.102210, "lng": 34.761713, "radius": 3000}]'::jsonb,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  )
ON CONFLICT (id) DO UPDATE
SET name = excluded.name,
    description = excluded.description,
    region = excluded.region,
    coordinates = excluded.coordinates,
    assigned_to = excluded.assigned_to;

INSERT INTO public.route_plans (
  id,
  title,
  route_date,
  assigned_to,
  school_ids,
  notes,
  status,
  created_by,
  "isSynced"
)
VALUES
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Role 5 Daily Route',
    current_date,
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '["44444444-4444-4444-4444-444444444444", "55555555-5555-5555-5555-555555555555"]'::jsonb,
    'Grounds run covering Kisumu Boys and Nakuru Girls.',
    'assigned',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    true
  )
ON CONFLICT (id) DO UPDATE
SET title = excluded.title,
    route_date = excluded.route_date,
    assigned_to = excluded.assigned_to,
    school_ids = excluded.school_ids,
    notes = excluded.notes,
    status = excluded.status,
    "isSynced" = excluded."isSynced";

INSERT INTO public.school_visits (
  school_id,
  agent_id,
  outcome,
  notes,
  photo_url,
  photo_path,
  latitude,
  longitude,
  visit_status,
  visited_at,
  "isSynced"
)
VALUES
  (
    '44444444-4444-4444-4444-444444444444',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Route checked and marked safe',
    'Confirmed the road condition and left a message with the school contact.',
    NULL,
    'visits/kisumu-boys-route-check.jpg',
    -0.102200,
    34.761700,
    'completed',
    now() - interval '1 day',
    true
  );

-- Additional pipeline demo records for role-based viewing (roles 1, 2, and 5 dashboards)
INSERT INTO public.school_sales (
  school_id,
  agent_id,
  package_name,
  expected_value,
  notes,
  sale_status,
  stage_contact_person,
  sample_quantity,
  quotation_reference,
  decision_owner,
  negotiation_topic,
  loss_reason,
  dormant_reason,
  stage_updated_at,
  expected_close_date,
  probability,
  closed_at,
  "isSynced"
)
VALUES
  (
    '33333333-3333-3333-3333-333333333333',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Upper Primary Bundle',
    18400.00,
    'Manager review requested after quotation submission.',
    'quotation_sent',
    'Board Secretary',
    NULL,
    'QT-2026-0333',
    NULL,
    NULL,
    NULL,
    NULL,
    now() - interval '4 days',
    (current_date + 14),
    65,
    NULL,
    true
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Secondary Exam Pack',
    26200.00,
    'Budget committee requested a final discount pass.',
    'negotiation',
    'Bursar',
    NULL,
    NULL,
    NULL,
    'Final unit price and delivery terms',
    NULL,
    NULL,
    now() - interval '2 days',
    (current_date + 10),
    85,
    NULL,
    true
  ),
  (
    '55555555-5555-5555-5555-555555555555',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Grounds Delivery Companion Kit',
    4200.00,
    'Reactivated after dormancy for a new term cycle.',
    'contacted',
    'Grounds Supervisor',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    now() - interval '1 day',
    (current_date + 20),
    20,
    NULL,
    true
  ),
  (
    '66666666-6666-6666-6666-666666666666',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Operations Support Bundle',
    3100.00,
    'No response after multiple follow-ups.',
    'dormant',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    'No school response for 30+ days',
    now() - interval '35 days',
    NULL,
    0,
    NULL,
    true
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Literacy Expansion Package',
    28900.00,
    'Order confirmed and handover planned.',
    'won',
    'Head Teacher',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    now() - interval '6 hours',
    current_date,
    100,
    now() - interval '6 hours',
    true
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    '11111111-1111-1111-1111-111111111111',
    'Teacher Demo Samples Pack',
    6400.00,
    'Samples issued to panel for review.',
    'sample_issued',
    'English HOD',
    12,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    now() - interval '3 days',
    (current_date + 18),
    50,
    NULL,
    true
  ),
  (
    '44444444-4444-4444-4444-444444444444',
    '11111111-1111-1111-1111-111111111111',
    'Budget Saver Bundle',
    9300.00,
    'Opportunity closed after budget freeze.',
    'lost',
    'Deputy Principal',
    NULL,
    NULL,
    NULL,
    NULL,
    'Budget redirected to infrastructure repairs',
    NULL,
    now() - interval '20 days',
    NULL,
    0,
    NULL,
    true
  );

INSERT INTO public.school_follow_ups (
  school_id,
  agent_id,
  contact_person,
  next_step,
  due_at,
  notes,
  follow_up_status,
  completed_at,
  "isSynced"
)
VALUES
  (
    '55555555-5555-5555-5555-555555555555',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Grounds Supervisor',
    'Confirm the school gate opening time.',
    now() + interval '2 days',
    'Follow-up needed before the delivery truck leaves.',
    'open',
    NULL,
    true
  );

INSERT INTO public.school_sales (
  school_id,
  agent_id,
  package_name,
  expected_value,
  notes,
  sale_status,
  closed_at,
  "isSynced"
)
VALUES
  (
    '44444444-4444-4444-4444-444444444444',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Grounds Support Log',
    1500.00,
    'Logged the route support cost for the day.',
    'lead',
    NULL,
    true
  );

-- Pipeline history demo records for timeline view
INSERT INTO public.pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  NULL,
  'contacted',
  s.agent_id,
  now() - interval '10 days',
  'Initial outreach completed with procurement office.'
FROM public.school_sales s
WHERE s.package_name = 'Upper Primary Bundle'
LIMIT 1;

INSERT INTO public.pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'contacted',
  'meeting_scheduled',
  s.agent_id,
  now() - interval '8 days',
  'School requested a formal meeting with board secretary.'
FROM public.school_sales s
WHERE s.package_name = 'Upper Primary Bundle'
LIMIT 1;

INSERT INTO public.pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'meeting_scheduled',
  'quotation_sent',
  s.agent_id,
  now() - interval '4 days',
  'Quotation QT-2026-0333 submitted by email and hard copy.'
FROM public.school_sales s
WHERE s.package_name = 'Upper Primary Bundle'
LIMIT 1;

INSERT INTO public.pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  NULL,
  'quotation_sent',
  s.agent_id,
  now() - interval '6 days',
  'Initial quote delivered after sample feedback.'
FROM public.school_sales s
WHERE s.package_name = 'Book List Bundle'
LIMIT 1;

INSERT INTO public.pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'quotation_sent',
  'decision_pending',
  s.agent_id,
  now() - interval '3 days',
  'Moved to decision pending awaiting principal sign-off.'
FROM public.school_sales s
WHERE s.package_name = 'Book Fund Starter Package'
LIMIT 1;

INSERT INTO public.pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'decision_pending',
  'won',
  s.agent_id,
  now() - interval '6 hours',
  'Order approved and ready for checkout.'
FROM public.school_sales s
WHERE s.package_name = 'Literacy Expansion Package'
LIMIT 1;

INSERT INTO public.pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'contacted',
  'lost',
  s.agent_id,
  now() - interval '20 days',
  'Budget redirected to infrastructure, deal closed lost.'
FROM public.school_sales s
WHERE s.package_name = 'Budget Saver Bundle'
LIMIT 1;

INSERT INTO public.pipeline_history (
  pipeline_id,
  old_stage,
  new_stage,
  changed_by,
  changed_at,
  notes
)
SELECT
  s.id,
  'contacted',
  'dormant',
  s.agent_id,
  now() - interval '35 days',
  'No response after repeated follow-ups.'
FROM public.school_sales s
WHERE s.package_name = 'Operations Support Bundle'
LIMIT 1;

INSERT INTO public.school_sample_distributions (
  school_id,
  agent_id,
  sample_name,
  sample_category,
  quantity,
  notes,
  distributed_at,
  "isSynced"
)
VALUES
  (
    '55555555-5555-5555-5555-555555555555',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Delivery Check Sheet',
    'Operations',
    1,
    'Left with the school office for confirmation.',
    now() - interval '2 days',
    true
  );

INSERT INTO public.catalog_items (
  id,
  name,
  category,
  sku,
  item_type,
  unit_price,
  stock_qty,
  description,
  is_active,
  created_by,
  "isSynced"
)
VALUES
  (
    'f1111111-1111-1111-1111-111111111111',
    'Grade 1 Reader Pack',
    'Primary',
    'SL-PR-01',
    'sale',
    2850.00,
    120,
    'Core sale pack for lower primary.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    'f2222222-2222-2222-2222-222222222222',
    'Teacher Guide Kit',
    'Reference',
    'SL-RF-02',
    'sale',
    2700.00,
    60,
    'Teacher support pack for school sale orders.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    'f3333333-3333-3333-3333-333333333333',
    'Story Books Pack',
    'Primary',
    'SMPL-PR-01',
    'sample',
    0.00,
    16,
    'Starter reading sample for classroom demonstrations.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    'f4444444-4444-4444-4444-444444444444',
    'Reference Handbook',
    'Reference',
    'SMPL-RF-02',
    'sample',
    0.00,
    28,
    'Quick reference sample for school sample distribution.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    'f5555555-5555-5555-5555-555555555555',
    'CBC Mathematics Grade 4',
    'Primary',
    'SL-PR-05',
    'sale',
    850.00,
    500,
    'Approved CBC Mathematics course book for Grade 4.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    'f6666666-6666-6666-6666-666666666666',
    'CBC English Grade 4',
    'Primary',
    'SL-PR-06',
    'sale',
    900.00,
    450,
    'Approved CBC English course book for Grade 4.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    'f7777777-7777-7777-7777-777777777777',
    'High School Biology Form 1',
    'Secondary',
    'SL-SEC-01',
    'sale',
    1200.00,
    300,
    'Comprehensive Biology course book for Form 1.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    'f8888888-8888-8888-8888-888888888888',
    'High School Chemistry Form 1',
    'Secondary',
    'SL-SEC-02',
    'sale',
    1250.00,
    320,
    'Comprehensive Chemistry course book for Form 1.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    'f9999999-9999-9999-9999-999999999999',
    'Kiswahili Mufti Grade 5',
    'Primary',
    'SL-PR-07',
    'sale',
    850.00,
    600,
    'Standard Kiswahili textbook for Grade 5.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  ),
  (
    'faaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Secondary Science Sample Pack',
    'Secondary',
    'SMPL-SEC-01',
    'sample',
    0.00,
    50,
    'Sample pack containing excerpts from Biology, Chemistry, and Physics.',
    true,
    '11111111-1111-1111-1111-111111111111',
    true
  )
ON CONFLICT (sku) DO UPDATE
SET
  name = excluded.name,
  category = excluded.category,
  item_type = excluded.item_type,
  unit_price = excluded.unit_price,
  stock_qty = excluded.stock_qty,
  description = excluded.description,
  is_active = excluded.is_active,
  created_by = excluded.created_by,
  "isSynced" = excluded."isSynced";

INSERT INTO public.orders (
  id,
  school_id,
  school_name,
  school_phone,
  agent_id,
  order_number,
  payment_method,
  payment_reference,
  checkout_amount,
  status,
  notes,
  submitted_at,
  approved_at
)
VALUES
  (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    '22222222-2222-2222-2222-222222222222',
    'Nairobi Primary School',
    '0712345678',
    '11111111-1111-1111-1111-111111111111',
    'ORD-20260509-FAITH-001',
    'mpesa',
    'QWERTY1234',
    8400.00,
    'pending',
    'Package sold after school visit and WhatsApp follow-up.',
    now() - interval '1 day',
    NULL
  ),
  (
    'd1111111-d111-d111-d111-d11111111111',
    '55555555-5555-5555-5555-555555555555',
    'Nakuru Girls',
    '0745678901',
    '11111111-1111-1111-1111-111111111111',
    'ORD-20260509-FAITH-003',
    'bank_transfer',
    'BANK-REF-8888',
    24500.00,
    'approved',
    'High school science books bulk order.',
    now() - interval '4 days',
    now() - interval '3 days'
  ),
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '44444444-4444-4444-4444-444444444444',
    'Kisumu Boys',
    '0734567890',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'ORD-20260509-ROLE5-001',
    'cash',
    NULL,
    1500.00,
    'paid',
    'Grounds support checkout completed in cash.',
    now() - interval '2 days',
    now() - interval '2 days'
  )
ON CONFLICT (id) DO UPDATE
SET
  school_id = excluded.school_id,
  school_name = excluded.school_name,
  school_phone = excluded.school_phone,
  agent_id = excluded.agent_id,
  order_number = excluded.order_number,
  payment_method = excluded.payment_method,
  payment_reference = excluded.payment_reference,
  checkout_amount = excluded.checkout_amount,
  status = excluded.status,
  notes = excluded.notes,
  submitted_at = excluded.submitted_at,
  approved_at = excluded.approved_at;

INSERT INTO public.order_items (
  id,
  order_id,
  product_name,
  category,
  sku,
  quantity,
  unit_price,
  line_total,
  notes
)
VALUES
  (
    'ddddddd1-dddd-dddd-dddd-dddddddddddd',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'Grade 1 Reader Pack',
    'Primary',
    'SET-PR-01',
    2,
    2850.00,
    5700.00,
    'Included in the school visit order.'
  ),
  (
    'ddddddd2-dddd-dddd-dddd-dddddddddddd',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'Teacher Guide Kit',
    'Reference',
    'SET-RF-03',
    1,
    2700.00,
    2700.00,
    'Support material for the head teacher.'
  ),
  (
    'd1111112-d111-d111-d111-d11111111111',
    'd1111111-d111-d111-d111-d11111111111',
    'High School Biology Form 1',
    'Secondary',
    'SL-SEC-01',
    10,
    1200.00,
    12000.00,
    'Form 1 Biology Class Set'
  ),
  (
    'd1111113-d111-d111-d111-d11111111111',
    'd1111111-d111-d111-d111-d11111111111',
    'High School Chemistry Form 1',
    'Secondary',
    'SL-SEC-02',
    10,
    1250.00,
    12500.00,
    'Form 1 Chemistry Class Set'
  ),
  (
    'eeeeeee1-eeee-eeee-eeee-eeeeeeeeeeee',
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    'Delivery Check Sheet',
    'Operations',
    'CUSTOM',
    1,
    1500.00,
    1500.00,
    'Grounds support order.'
  )
ON CONFLICT (id) DO UPDATE
SET
  order_id = excluded.order_id,
  product_name = excluded.product_name,
  category = excluded.category,
  sku = excluded.sku,
  quantity = excluded.quantity,
  unit_price = excluded.unit_price,
  line_total = excluded.line_total,
  notes = excluded.notes;

INSERT INTO public.messages (
  id,
  sender_id,
  recipient_id,
  subject,
  body,
  related_school_id,
  related_task_id,
  is_read
)
VALUES
  (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '11111111-1111-1111-1111-111111111111',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Route plan ready',
    'Your route plan for today is ready. Please check the route list and geofence coverage before departure.',
    '44444444-4444-4444-4444-444444444444',
    NULL,
    false
  ),
  (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '11111111-1111-1111-1111-111111111111',
    'Route check complete',
    'I have confirmed the Kisumu Boys stop and the gate access point. The area is safe for the delivery team.',
    '44444444-4444-4444-4444-444444444444',
    NULL,
    true
  ),
  (
    'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
    '11111111-1111-1111-1111-111111111111',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Follow up reminder',
    'Please remember to update me after the Nakuru Girls stop with the school feedback.',
    '55555555-5555-5555-5555-555555555555',
    NULL,
    false
  )
ON CONFLICT (id) DO UPDATE
SET sender_id = excluded.sender_id,
    recipient_id = excluded.recipient_id,
    subject = excluded.subject,
    body = excluded.body,
    related_school_id = excluded.related_school_id,
    related_task_id = excluded.related_task_id,
    is_read = excluded.is_read;

UPDATE public.schools
SET
  captured_by = '11111111-1111-1111-1111-111111111111',
  captured_at = now() - interval '1 day',
  capture_status = coalesce(capture_status, 'GPS updated successfully')
WHERE id IN (
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333',
  '44444444-4444-4444-4444-444444444444',
  '55555555-5555-5555-5555-555555555555',
  '66666666-6666-6666-6666-666666666666'
);

-- (Optional Failsafe) 
-- If your trigger does not automatically map the 'role' and 'full_name' 
-- from auth.users over to the public.users table, run this update manually:
UPDATE public.users 
SET full_name = auth.users.raw_user_meta_data->>'full_name',
    role = (auth.users.raw_user_meta_data->>'role')::int,
    region = auth.users.raw_user_meta_data->>'region'
FROM auth.users 
WHERE public.users.id = auth.users.id AND public.users.full_name IS NULL;

-- ==========================================
-- 4d. Role 2 / Sales Manager Demo Data
-- ==========================================

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  ('22222222-aaaa-aaaa-aaaa-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'manager.role2@example.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name": "Demo Sales Manager", "role": 2, "region": "Nairobi"}', now(), now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.tasks (title, description, target_role, assigned_to, status, due_at, "isSynced")
VALUES
  ('Approve pending field orders', 'Review and approve all pending orders submitted by agents this week.', 2, '22222222-aaaa-aaaa-aaaa-222222222222', 'open', now() + interval '1 day', true),
  ('Review Nairobi route plans', 'Ensure all Nairobi schools have assigned agents for the upcoming week.', 2, '22222222-aaaa-aaaa-aaaa-222222222222', 'open', now() + interval '2 days', true);

-- Add an extra pending order for the manager to approve
INSERT INTO public.orders (
  id, school_id, school_name, school_phone, agent_id, order_number, payment_method, payment_reference, checkout_amount, status, notes, submitted_at, approved_at, "isSynced"
)
VALUES
  (
    'f0000000-f000-f000-f000-f00000000000',
    '33333333-3333-3333-3333-333333333333',
    'Mombasa High School',
    '0723456789',
    '11111111-1111-1111-1111-111111111111',
    'ORD-20260510-FAITH-002',
    'bank_transfer',
    'BANK-REF-9999',
    12500.00,
    'pending',
    'Large book fund order, pending manager approval.',
    now() - interval '2 hours',
    NULL,
    true
  )
ON CONFLICT (id) DO UPDATE
SET status = excluded.status,
    "isSynced" = excluded."isSynced";

-- Add a message to the manager
INSERT INTO public.messages (
  id, sender_id, recipient_id, subject, body, related_school_id, is_read, "isSynced"
)
VALUES
  (
    'f1111111-f111-f111-f111-f11111111111',
    '11111111-1111-1111-1111-111111111111',
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Order Approval Request',
    'Hi Manager, I have submitted a large order for Mombasa High School. Please review and approve the bank slip when possible.',
    '33333333-3333-3333-3333-333333333333',
    false,
    true
  )
ON CONFLICT (id) DO NOTHING;

-- Distribute some of the new dummy sample books
INSERT INTO public.school_sample_distributions (
  school_id, agent_id, sample_name, sample_category, quantity, notes, distributed_at, "isSynced"
)
VALUES
  (
    '55555555-5555-5555-5555-555555555555', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Secondary Science Sample Pack', 'Secondary', 1, 'Dropped off by Grounds Personnel alongside the main delivery.', now() - interval '2 hours', true
  )
ON CONFLICT DO NOTHING;


-- After running this script:
-- Refresh your Admin Dashboard screen in the app.
-- You should now see 10 Tasks and 6 Geofences listed in the counters!
-- Your Agent Tracker and Assign Task dropdowns will now have 6 users in them!


-- ==========================================
-- 5. Additional Mock Data for Geofence Polygons & Filterable Tasks
-- ==========================================

-- Insert proper Polygon geofences (requires >= 3 points to render a shape on the map)
INSERT INTO public.geofences (id, name, description, region, coordinates, assigned_to)
VALUES
  (gen_random_uuid(), 'Nairobi South Polygon', 'Detailed polygon mapping for southern Nairobi.', 'Nairobi', '[{"lat": -1.30, "lng": 36.80}, {"lat": -1.30, "lng": 36.85}, {"lat": -1.35, "lng": 36.85}, {"lat": -1.35, "lng": 36.80}]'::jsonb, '11111111-1111-1111-1111-111111111111'),
  (gen_random_uuid(), 'Mombasa North Coast', 'Polygon for northern coastal region coverage.', 'Mombasa', '[{"lat": -3.95, "lng": 39.70}, {"lat": -3.95, "lng": 39.75}, {"lat": -4.00, "lng": 39.75}, {"lat": -4.00, "lng": 39.70}]'::jsonb, '22222222-aaaa-aaaa-aaaa-222222222222'),
  (gen_random_uuid(), 'Kisumu Central Grid', 'Triangular grid for Kisumu central field operations.', 'Kisumu', '[{"lat": -0.09, "lng": 34.75}, {"lat": -0.09, "lng": 34.77}, {"lat": -0.11, "lng": 34.76}]'::jsonb, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

-- Insert dummy tasks designed to test the Daily, Weekly, and Monthly dashboard filters
INSERT INTO public.tasks (title, description, target_role, assigned_to, status, due_at, "isSynced")
VALUES
  -- Faith Agent (Role 4)
  ('Daily: Submit EOD Report', 'Submit end-of-day sales report for Nairobi schools.', 4, '11111111-1111-1111-1111-111111111111', 'open', now(), true),
  ('Weekly: Restock Samples', 'Pick up new sample books from the regional warehouse.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '3 days', true),
  ('Monthly: School Inventory Check', 'Perform a full inventory check of sample distributions for the month.', 4, '11111111-1111-1111-1111-111111111111', 'open', now() + interval '20 days', true),
  
  -- Sales Manager (Role 2)
  ('Daily: Morning Briefing', 'Quick sync with the sales team to review yesterday''s figures.', 2, '22222222-aaaa-aaaa-aaaa-222222222222', 'closed', now(), true),
  ('Monthly: Pipeline Review', 'Review all pipeline sales for the month and close out drafts.', 2, '22222222-aaaa-aaaa-aaaa-222222222222', 'in_progress', now() + interval '14 days', true),

  -- Grounds Person (Role 5)
  ('Daily: Inspect Vehicle', 'Perform daily routine check on delivery vehicle.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now(), true),
  ('Weekly: Service Route Validation', 'Validate newly added schools on the route map.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now() + interval '4 days', true),
  ('Monthly: Log Book Audit', 'Submit the monthly physical log book for audit.', 5, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'open', now() + interval '25 days', true);

-- ==========================================
-- 6. Role 3 Supervision Demo Data
-- ==========================================
INSERT INTO public.supervisor_alerts (user_id, region, alert_type, severity, status, message, acked_at, resolved_at, ack_sla_met, resolve_sla_met, escalated_to_admin)
VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kisumu', 'missed_checkin', 'red', 'open', 'Grounds user missed first check-in.', null, null, false, false, false),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kisumu', 'late_start', 'amber', 'resolved', 'Route start was delayed by 40 minutes.', now() - interval '5 hours', now() - interval '3 hours', true, true, false)
ON CONFLICT DO NOTHING;

INSERT INTO public.geofence_events (user_id, geofence_id, event_type, region, lat, lng, reason, status, created_at)
VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '99999999-9999-9999-9999-999999999999', 'breach', 'Kisumu', -0.0981, 34.7742, 'Detour due to road closure', 'open', now() - interval '2 hours')
ON CONFLICT DO NOTHING;

INSERT INTO public.supervisor_incidents (user_id, region, incident_type, severity, status, notes, created_by)
VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kisumu', 'boundary_breach', 'high', 'open', 'Repeated breach on western corridor.', '22222222-aaaa-aaaa-aaaa-222222222222')
ON CONFLICT DO NOTHING;

INSERT INTO public.supervisor_notes (supervisor_id, user_id, region, context_type, note, follow_up_at)
VALUES
  ('22222222-aaaa-aaaa-aaaa-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Kisumu', 'weekly_review', 'Improve first check-in discipline and submit route evidence by 9 AM.', now() + interval '7 days')
ON CONFLICT DO NOTHING;

INSERT INTO public.supervisor_notifications (
  supervisor_id, region, notification_type, title, body, payload, scheduled_for, sent_at
)
VALUES
  (
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Nairobi',
    'daily_digest',
    'Morning Supervision Digest',
    'You have 2 open alerts and 3 overdue tasks in your region.',
    '{"open_alerts": 2, "overdue_tasks": 3}'::jsonb,
    now() - interval '2 hours',
    now() - interval '2 hours'
  ),
  (
    '22222222-aaaa-aaaa-aaaa-222222222222',
    'Nairobi',
    'escalation',
    'Escalated Red Alert',
    'A red alert has remained unresolved beyond SLA.',
    '{"alert_type": "missed_checkin"}'::jsonb,
    now() - interval '30 minutes',
    now() - interval '30 minutes'
  )
ON CONFLICT DO NOTHING;

-- END FILE: supabase/seed.sql

-- =========================================================
-- BEGIN FILE: supabase/seed_sample_roi_dummy.sql
-- =========================================================
-- Dummy data for sample ROI testing (Role 5 + Admin)
-- Safe-ish rerun via fixed IDs + upserts where possible.

begin;

-- 1) Ensure demo users exist (role 5 grounds + role 4 agent)
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '92000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'grounds.demo@dehus.com',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Grounds Demo User","role":5,"region":"Nairobi"}',
    now(),
    now()
  ),
  (
    '92000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'agent.demo@dehus.com',
    crypt('password123', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    '{"full_name":"Agent Demo User","role":4,"region":"Nakuru"}',
    now(),
    now()
  )
on conflict (id) do nothing;

insert into public.users (id, email, full_name, phone, role, region)
values
  ('92000000-0000-0000-0000-000000000001', 'grounds.demo@dehus.com', 'Grounds Demo User', '0711000001', 5, 'Nairobi'),
  ('92000000-0000-0000-0000-000000000002', 'agent.demo@dehus.com', 'Agent Demo User', '0711000002', 4, 'Nakuru')
on conflict (id) do update set
  email = excluded.email,
  full_name = excluded.full_name,
  phone = excluded.phone,
  role = excluded.role,
  region = excluded.region;

-- 2) Pick up to 4 schools for linking data
with s as (
  select id, row_number() over (order by created_at desc nulls last, id) rn
  from public.schools
  limit 4
)
insert into public.school_sample_distributions (
  id, school_id, agent_id, sample_name, sample_category, quantity,
  stamped_receipt_url, stamped_receipt_path, notes, distributed_at, "isSynced"
)
select
  ('93000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  s.id,
  case when s.rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  case when s.rn % 2 = 0 then 'Teacher Guide Kit' else 'Grade 1 Reader Pack' end,
  case when s.rn % 2 = 0 then 'Reference' else 'Primary' end,
  (s.rn % 3) + 1,
  'https://images.unsplash.com/photo-1455390582262-044cdead277a?w=1200',
  'sample_receipts/demo_' || s.rn || '.jpg',
  'Dummy ROI receipt seed',
  now() - ((s.rn::text || ' days')::interval),
  true
from s
on conflict (id) do update set
  school_id = excluded.school_id,
  agent_id = excluded.agent_id,
  sample_name = excluded.sample_name,
  sample_category = excluded.sample_category,
  quantity = excluded.quantity,
  stamped_receipt_url = excluded.stamped_receipt_url,
  stamped_receipt_path = excluded.stamped_receipt_path,
  notes = excluded.notes,
  distributed_at = excluded.distributed_at,
  "isSynced" = excluded."isSynced";

-- 3) Orders for revenue earned metric
insert into public.orders (
  id, school_id, school_name, school_phone, agent_id, order_number,
  payment_method, payment_reference, checkout_amount, status, notes, submitted_at, approved_at, "isSynced"
)
select
  ('94000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  s.id,
  coalesce(sc.name, 'School ' || s.rn),
  coalesce(sc.phone, '0700000000'),
  case when s.rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  'DEMO-ROI-' || s.rn,
  'mpesa',
  'MPESA-DEMO-' || s.rn,
  (50000 + (s.rn * 10000))::numeric,
  case when s.rn % 3 = 0 then 'pending' else 'approved' end,
  'Dummy ROI order',
  now() - ((s.rn::text || ' days')::interval),
  now() - (((s.rn + 1)::text || ' days')::interval),
  true
from (
  select id, row_number() over (order by created_at desc nulls last, id) rn
  from public.schools
  limit 4
) s
left join public.schools sc on sc.id = s.id
on conflict (id) do update set
  school_id = excluded.school_id,
  school_name = excluded.school_name,
  school_phone = excluded.school_phone,
  agent_id = excluded.agent_id,
  checkout_amount = excluded.checkout_amount,
  status = excluded.status,
  notes = excluded.notes,
  submitted_at = excluded.submitted_at,
  approved_at = excluded.approved_at,
  "isSynced" = excluded."isSynced";

-- 4) School sales for won value metric
insert into public.school_sales (
  id, school_id, agent_id, package_name, expected_value, notes,
  sale_status, stage_updated_at, probability, closed_at, "isSynced"
)
select
  ('95000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  s.id,
  case when s.rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  'ROI Demo Package',
  (90000 + (s.rn * 12000))::numeric,
  'Dummy ROI pipeline',
  case when s.rn % 2 = 0 then 'won' else 'negotiation' end,
  now() - ((s.rn::text || ' days')::interval),
  case when s.rn % 2 = 0 then 100 else 70 end,
  case when s.rn % 2 = 0 then now() - ((s.rn::text || ' days')::interval) else null end,
  true
from (
  select id, row_number() over (order by created_at desc nulls last, id) rn
  from public.schools
  limit 4
) s
on conflict (id) do update set
  school_id = excluded.school_id,
  agent_id = excluded.agent_id,
  package_name = excluded.package_name,
  expected_value = excluded.expected_value,
  notes = excluded.notes,
  sale_status = excluded.sale_status,
  stage_updated_at = excluded.stage_updated_at,
  probability = excluded.probability,
  closed_at = excluded.closed_at,
  "isSynced" = excluded."isSynced";

commit;

-- END FILE: supabase/seed_sample_roi_dummy.sql

-- =========================================================
-- BEGIN FILE: supabase/storage_policies_sample_receipts.sql
-- =========================================================
-- Enable storage for stamped sample receipt photos
-- Run in Supabase SQL editor as a project admin.

begin;

-- 1) Ensure bucket exists (public for easy admin viewing via public URL)
insert into storage.buckets (id, name, public)
values ('schools', 'schools', true)
on conflict (id) do update set public = true;

-- Optional dedicated bucket (if you later switch app upload target)
insert into storage.buckets (id, name, public)
values ('sample-receipts', 'sample-receipts', true)
on conflict (id) do update set public = true;

-- 2) Policies for 'schools' bucket
drop policy if exists "authenticated_can_view_schools_bucket" on storage.objects;
create policy "authenticated_can_view_schools_bucket"
on storage.objects
for select
to authenticated
using (bucket_id = 'schools');

drop policy if exists "authenticated_can_upload_schools_bucket" on storage.objects;
create policy "authenticated_can_upload_schools_bucket"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'schools');

drop policy if exists "authenticated_can_update_schools_bucket" on storage.objects;
create policy "authenticated_can_update_schools_bucket"
on storage.objects
for update
to authenticated
using (bucket_id = 'schools')
with check (bucket_id = 'schools');

-- 3) Policies for dedicated 'sample-receipts' bucket
drop policy if exists "authenticated_can_view_sample_receipts_bucket" on storage.objects;
create policy "authenticated_can_view_sample_receipts_bucket"
on storage.objects
for select
to authenticated
using (bucket_id = 'sample-receipts');

drop policy if exists "authenticated_can_upload_sample_receipts_bucket" on storage.objects;
create policy "authenticated_can_upload_sample_receipts_bucket"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'sample-receipts');

drop policy if exists "authenticated_can_update_sample_receipts_bucket" on storage.objects;
create policy "authenticated_can_update_sample_receipts_bucket"
on storage.objects
for update
to authenticated
using (bucket_id = 'sample-receipts')
with check (bucket_id = 'sample-receipts');

commit;

-- END FILE: supabase/storage_policies_sample_receipts.sql

