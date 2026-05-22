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
      and (
        auth.uid() = any (f.assigned_user_ids)
        or coalesce(array_length(f.assigned_user_ids, 1), 0) = 0
        or public.is_manager_or_admin()
      )
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
