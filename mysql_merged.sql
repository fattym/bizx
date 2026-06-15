-- MARGED SQL
-- Combined on 2026-05-22 07:38:50 UTC
-- Source: all .sql files found in this project

-- =========================================================
-- BEGIN FILE: supabase/demo_geofences.sql
-- =========================================================
-- Demo county geofences for admin map visualization
-- Run this after schema/seed setup.

insert into geofences (name, description, region, coordinates)
values
  (
    'Nairobi County Demo',
    'Demo boundary for Nairobi county.',
    'Nairobi',
    '[{lat: -1.220, lng: 36.760}, {lat: -1.220, lng: 36.940}, {lat: -1.380, lng: 36.940}, {lat: -1.380, lng: 36.760}]'
  ),
  (
    'Mombasa County Demo',
    'Demo boundary for Mombasa county.',
    'Mombasa',
    '[{lat: -3.930, lng: 39.610}, {lat: -3.930, lng: 39.760}, {lat: -4.120, lng: 39.760}, {lat: -4.120, lng: 39.610}]'
  ),
  (
    'Kisumu County Demo',
    'Demo boundary for Kisumu county.',
    'Kisumu',
    '[{lat: -0.020, lng: 34.650}, {lat: -0.020, lng: 34.860}, {lat: -0.190, lng: 34.860}, {lat: -0.190, lng: 34.650}]'
  ),
  (
    'Nakuru County Demo',
    'Demo boundary for Nakuru county.',
    'Nakuru',
    '[{lat: -0.130, lng: 35.950}, {lat: -0.130, lng: 36.220}, {lat: -0.430, lng: 36.220}, {lat: -0.430, lng: 35.950}]'
  ),
  (
    'Kiambu County Demo',
    'Demo boundary for Kiambu county.',
    'Kiambu',
    '[{lat: -1.000, lng: 36.620}, {lat: -1.000, lng: 37.000}, {lat: -1.280, lng: 37.000}, {lat: -1.280, lng: 36.620}]'
  ),
  (
    'Uasin Gishu County Demo',
    'Demo boundary for Uasin Gishu county.',
    'Uasin Gishu',
    '[{lat: 0.350, lng: 35.100}, {lat: 0.350, lng: 35.450}, {lat: 0.000, lng: 35.450}, {lat: 0.000, lng: 35.100}]'
  );

-- END FILE: supabase/demo_geofences.sql

-- =========================================================
-- BEGIN FILE: supabase/generate_mock_data.sql
-- =========================================================
-- Generate mock tasks + pipeline data for dashboard testing
-- Safe to rerun: uses deterministic IDs and upserts.



-- 1) Ensure task status normalization in existing rows
update tasks
set status = 'closed'
where lower(status) in ('complete', 'completed', 'done');

update tasks
set status = 'in_progress'
where lower(status) in ('in progress', 'progress');

update tasks
set status = 'open'
where lower(status) not in ('open', 'in_progress', 'closed');

-- 2) Insert/update demo tasks across statuses and due dates
insert into tasks (
  id, title, description, target_role, assigned_to, status, due_at, created_by, isSynced
)
values
  ('90000000-0000-0000-0000-000000000001', 'Pipeline Follow-up Call', 'Call 3 schools and confirm next action.', 5, null, 'open', DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 DAY), null, true),
  ('90000000-0000-0000-0000-000000000002', 'Sample Delivery Review', 'Review sample delivery proof and update remarks.', 5, null, 'in_progress', DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 3 DAYS), null, true),
  ('90000000-0000-0000-0000-000000000003', 'Closed Task Demo', 'Already completed task for admin closed filter.', 5, null, 'closed', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY), null, true),
  ('90000000-0000-0000-0000-000000000004', 'Admin Visibility Task', 'Task to verify role 1 can filter by status.', 2, null, 'closed', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 DAYS), null, true)
ON DUPLICATE KEY UPDATE 
  title = VALUES(title),
  description = VALUES(description),
  target_role = VALUES(target_role),
  assigned_to = VALUES(assigned_to),
  status = VALUES(status),
  due_at = VALUES(due_at),
  created_by = VALUES(created_by),
  isSynced = VALUES(isSynced)

-- 3) Add/refresh social pipeline stage demo data from available schools
with selected_schools as (
  select id, row_number() over (order by created_at desc nulls last, id) as rn
  from schools
  limit 6
),
stage_matrix as (
  select * from (values
    (1, 'lead', 45000),
    (2, 'contacted', 60000),
    (3, 'meeting_scheduled', 90000),
    (4, 'negotiation', 140000),
    (5, 'won', 180000),
    (6, 'lost', 30000)
  ) as t(rn, stage, expected_value)
)
insert into school_sales (
  id, school_id, package_name, sale_status, expected_value, stage_updated_at, probability, notes, isSynced
)
select
  (CONCAT('91000000-0000-0000-0000-', lpad)(ss.rn, 12, '0')) as id,
  ss.id as school_id,
  'Generated Demo Package' as package_name,
  sm.stage,
  sm.expected_value,
  CURRENT_TIMESTAMP - ((CONCAT(ss.rn, ' days'))),
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
ON DUPLICATE KEY UPDATE 
  package_name = VALUES(package_name),
  sale_status = VALUES(sale_status),
  expected_value = VALUES(expected_value),
  stage_updated_at = VALUES(stage_updated_at),
  probability = VALUES(probability),
  notes = VALUES(notes),
  isSynced = VALUES(isSynced)



-- END FILE: supabase/generate_mock_data.sql

-- =========================================================
-- BEGIN FILE: supabase/schema.sql
-- =========================================================


create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = CURRENT_TIMESTAMP;
  return new;
end;
$$;

create or replace function role_id_from_text(role_text text)
returns integer
language plpgsql
immutable
as $$
begin
  if role_text is null or TRIM(role_text) = '' then
    return 5;
  end if;

  case lower(TRIM(role_text))
    when 'admin' then return 1;
    when 'sales manager' then return 2;
    when 'bas' then return 3;
    when 'agent' then return 4;
    when 'grounds person' then return 5;
    else
      begin
        return role_text;
      exception
        when others then
          return 5;
      end;
  end case;
end;
$$;

create table if not exists users (
  id VARCHAR(36) primary key references users (id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  role integer not null default 5,
  region text,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

-- Ensure region, phone and isSynced columns exist (in case table was created previously)
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'region') then
    alter table users add column region text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'phone') then
    alter table users add column phone text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'users' and column_name = 'isSynced') then
    alter table users add column isSynced BOOLEAN not null default false;
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
    alter table users
      alter column role drop default;
    alter table users
      alter column role type integer using role_id_from_text(role);
    alter table users
      alter column role set default 5;
  end if;
end $$;

alter table users
  alter column role set default 5;

create or replace function is_admin()
returns BOOLEAN
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from users
    where id = auth.uid()
      and role = 1
  );
$$;

create or replace function is_manager_or_admin()
returns BOOLEAN
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from users
    where id = auth.uid()
      and role <= 3
  );
$$;

create or replace function is_sales_manager()
returns BOOLEAN
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from users
    where id = auth.uid()
      and role <= 2
  );
$$;

create or replace function is_bas()
returns BOOLEAN
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from users
    where id = auth.uid()
      and role <= 3
  );
$$;

create or replace function current_user_role_id()
returns integer
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select role from users where id = auth.uid() limit 1),
    5
  );
$$;

create or replace function current_user_role_from_jwt()
returns integer
language sql
stable
as $$
  select role_id_from_text(
    coalesce(
      auth.jwt() -> 'user_metadata' ->> 'role',
      auth.jwt() -> 'app_metadata' ->> 'role'
    )
  );
$$;

create or replace function current_user_region_from_jwt()
returns text
language sql
stable
as $$
  select coalesce(
    auth.jwt() -> 'user_metadata' ->> 'region',
    auth.jwt() -> 'app_metadata' ->> 'region'
  );
$$;

create or replace function current_user_region()
returns text
language sql
security definer
set search_path = public
as $$
  select coalesce(
    (select nullif(TRIM(region), '') from users where id = auth.uid() limit 1),
    nullif(TRIM(current_user_region_from_jwt()), '')
  );
$$;

create table if not exists schools (
  id VARCHAR(36) primary key default (UUID()),
  name text not null,
  phone text not null,
  county text not null,
  source text not null default 'manual',
  external_place_id text,
  external_vicinity text,
  focusAreas JSON not null default '[]',
  book_category text,
  dealer_type text,
  shop_category text,
  selected_product text,
  partner_subtype text,
  latitude DOUBLE,
  longitude DOUBLE,
  gps_accuracy_meters DOUBLE,
  photo_url text,
  photo_path text,
  captured_by VARCHAR(36) references users (id) on delete set null,
  captured_at DATETIME,
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
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

-- Ensure isSynced column exists in schools
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'source') then
    alter table schools add column source text not null default 'manual';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'external_place_id') then
    alter table schools add column external_place_id text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'external_vicinity') then
    alter table schools add column external_vicinity text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'isSynced') then
    alter table schools add column isSynced BOOLEAN not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'book_category') then
    alter table schools add column book_category text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'dealer_type') then
    alter table schools add column dealer_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'shop_category') then
    alter table schools add column shop_category text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'selected_product') then
    alter table schools add column selected_product text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'partner_subtype') then
    alter table schools add column partner_subtype text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'gps_accuracy_meters') then
    alter table schools add column gps_accuracy_meters DOUBLE;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'photo_url') then
    alter table schools add column photo_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'photo_path') then
    alter table schools add column photo_path text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'captured_by') then
    alter table schools add column captured_by VARCHAR(36) references users (id) on delete set null;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'captured_at') then
    alter table schools add column captured_at DATETIME;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'capture_status') then
    alter table schools add column capture_status text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_name') then
    alter table schools add column contact_name text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_phone') then
    alter table schools add column contact_phone text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'contact_title') then
    alter table schools add column contact_title text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'feedback') then
    alter table schools add column feedback text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'notes') then
    alter table schools add column notes text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'samples_left') then
    alter table schools add column samples_left text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_book') then
    alter table schools add column sample_book text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_ownership') then
    alter table schools add column school_ownership text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_ownership_other') then
    alter table schools add column school_ownership_other text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_population') then
    alter table schools add column school_population integer;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'school_lifecycle_status') then
    alter table schools add column school_lifecycle_status text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'engagement_type') then
    alter table schools add column engagement_type text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_proof_url') then
    alter table schools add column sample_proof_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'schools' and column_name = 'sample_proof_path') then
    alter table schools add column sample_proof_path text;
  end if;
end $$;

do $$
begin
  if to_regclass('users') is not null then
    create index if not exists idx_users_role_region on users(role, region);
  end if;
  if to_regclass('tasks') is not null then
    create index if not exists idx_tasks_assigned_status_due on tasks(assigned_to, status, due_at);
  end if;
  if to_regclass('geofences') is not null then
    create index if not exists idx_geofences_region_assigned on geofences(region, assigned_to);
  end if;
  if to_regclass('route_plans') is not null then
    create index if not exists idx_route_plans_assigned_date_status on route_plans(assigned_to, route_date, status);
  end if;
end $$;

create unique index if not exists idx_schools_external_place_id
  on schools (external_place_id)
  where external_place_id is not null;

create table if not exists tasks (
  id VARCHAR(36) primary key default (UUID()),
  title text not null,
  description text not null,
  target_role integer not null default 2,
  due_at DATETIME,
  status text not null default 'open',
  created_by VARCHAR(36) references users (id) on delete set null,
  assigned_to VARCHAR(36) references users (id) on delete set null,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

-- Ensure isSynced column exists in tasks
do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'tasks' and column_name = 'isSynced') then
    alter table tasks add column isSynced BOOLEAN not null default false;
  end if;
end $$;

create table if not exists geofences (
  id VARCHAR(36) primary key default (UUID()),
  name text not null,
  description text,
  region text,
  coordinates JSON not null default '[]',
  assigned_to VARCHAR(36) references users (id) on delete set null,
  created_by VARCHAR(36) references users (id) on delete set null,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
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
    alter table geofences add column region text;
  end if;
end $$;

create table if not exists route_plans (
  id VARCHAR(36) primary key default (UUID()),
  title text not null,
  route_date date not null,
  assigned_to VARCHAR(36) references users (id) on delete set null,
  school_ids JSON not null default '[]',
  notes text,
  status text not null default 'assigned',
  created_by VARCHAR(36) references users (id) on delete set null,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'reviewed_by') then
    alter table route_plans add column reviewed_by VARCHAR(36) references users (id) on delete set null;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'reviewed_at') then
    alter table route_plans add column reviewed_at DATETIME;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'route_plans' and column_name = 'review_note') then
    alter table route_plans add column review_note text;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'route_plans_status_check'
      and conrelid = 'route_plans'
  ) then
    alter table route_plans
      add constraint route_plans_status_check
      check (status in ('draft', 'submitted', 'approved', 'rejected', 'assigned', 'in_progress', 'completed'));
  end if;
end $$;

create table if not exists geofence_events (
  id VARCHAR(36) primary key default (UUID()),
  user_id VARCHAR(36) not null references users (id) on delete cascade,
  geofence_id VARCHAR(36) references geofences (id) on delete set null,
  event_type text not null,
  region text,
  lat DOUBLE,
  lng DOUBLE,
  reason text,
  status text not null default 'open',
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  resolved_at DATETIME
);

create table if not exists supervisor_alerts (
  id VARCHAR(36) primary key default (UUID()),
  user_id VARCHAR(36) not null references users (id) on delete cascade,
  region text,
  alert_type text not null,
  severity text not null default 'amber',
  status text not null default 'open',
  message text,
  acked_at DATETIME,
  resolved_at DATETIME,
  ack_sla_met BOOLEAN default false,
  resolve_sla_met BOOLEAN default false,
  escalated_to_admin BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP
);

create table if not exists supervisor_incidents (
  id VARCHAR(36) primary key default (UUID()),
  user_id VARCHAR(36) not null references users (id) on delete cascade,
  region text,
  incident_type text not null,
  severity text not null default 'high',
  status text not null default 'open',
  notes text,
  created_by VARCHAR(36) references users (id) on delete set null,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

create table if not exists supervisor_notes (
  id VARCHAR(36) primary key default (UUID()),
  supervisor_id VARCHAR(36) not null references users (id) on delete cascade,
  user_id VARCHAR(36) not null references users (id) on delete cascade,
  region text,
  context_type text,
  context_id VARCHAR(36),
  note text not null,
  follow_up_at DATETIME,
  created_at DATETIME not null default CURRENT_TIMESTAMP
);

create table if not exists audit_events (
  id VARCHAR(36) primary key default (UUID()),
  actor_id VARCHAR(36) references users (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  region text,
  before_data JSON,
  after_data JSON,
  created_at DATETIME not null default CURRENT_TIMESTAMP
);

create table if not exists task_completion_evidence (
  id VARCHAR(36) primary key default (UUID()),
  task_id VARCHAR(36) not null references tasks (id) on delete cascade,
  submitted_by VARCHAR(36) not null references users (id) on delete cascade,
  gps_lat DOUBLE,
  gps_lng DOUBLE,
  proof_url text,
  proof_type text,
  created_at DATETIME not null default CURRENT_TIMESTAMP
);

create table if not exists supervisor_notifications (
  id VARCHAR(36) primary key default (UUID()),
  supervisor_id VARCHAR(36) not null references users (id) on delete cascade,
  region text,
  notification_type text not null,
  title text not null,
  body text not null,
  payload JSON not null default '{}',
  scheduled_for DATETIME not null default CURRENT_TIMESTAMP,
  sent_at DATETIME,
  read_at DATETIME,
  created_at DATETIME not null default CURRENT_TIMESTAMP
);

create index if not exists idx_supervisor_alerts_status_created
  on supervisor_alerts(status, created_at);
create index if not exists idx_supervisor_alerts_region
  on supervisor_alerts(region);
create index if not exists idx_supervisor_notifications_supervisor_scheduled
  on supervisor_notifications(supervisor_id, scheduled_for);
create index if not exists idx_supervisor_notifications_read_at
  on supervisor_notifications(read_at);

create or replace function process_supervisor_alert_sla()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_count integer := 0;
begin
  -- Mark open red alerts older than 15 minutes as SLA-breached for ack.
  update supervisor_alerts
  set ack_sla_met = false
  where status = 'open'
    and lower(coalesce(severity, '')) = 'red'
    and created_at <= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 15 MINUTES)
    and coalesce(ack_sla_met, true) = true;
  get diagnostics affected_count = row_count;

  -- Escalate unresolved red alerts older than 2 hours.
  with to_escalate as (
    update supervisor_alerts
    set escalated_to_admin = true
    where status = 'open'
      and lower(coalesce(severity, '')) = 'red'
      and created_at <= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 2 HOURS)
      and coalesce(escalated_to_admin, false) = false
    returning id, user_id, region, alert_type
  )
  insert into supervisor_notifications (
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
    CURRENT_TIMESTAMP
  from to_escalate e
  join users u
    on u.role = 3
   and lower(coalesce(u.region, '')) = lower(coalesce(e.region, ''));

  return affected_count;
end;
$$;

create or replace function queue_supervisor_daily_digests()
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
  if to_char(CURRENT_TIMESTAMP, 'HH24:MI') between '07:00' and '07:10' then
    insert into supervisor_notifications (
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
          from supervisor_alerts a
          where lower(coalesce(a.region, '')) = lower(coalesce(s.region, ''))
            and a.status = 'open'
        ),
        'overdue_tasks', (
          select count(*)
          from tasks t
          join users u on u.id = t.assigned_to
          where u.role = 5
            and lower(coalesce(u.region, '')) = lower(coalesce(s.region, ''))
            and t.due_at < CURRENT_TIMESTAMP
            and lower(coalesce(t.status, '')) not in ('closed', 'completed')
        )
      ),
      CURRENT_TIMESTAMP
    from users s
    where s.role = 3;
    get diagnostics batch_count = row_count;
    inserted_count := inserted_count + batch_count;
  end if;

  -- Evening digest at 18:00 local DB time.
  if to_char(CURRENT_TIMESTAMP, 'HH24:MI') between '18:00' and '18:10' then
    insert into supervisor_notifications (
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
          from supervisor_alerts a
          where lower(coalesce(a.region, '')) = lower(coalesce(s.region, ''))
            and a.status = 'resolved'
            and a.resolved_at >= date_trunc('day', CURRENT_TIMESTAMP)
        ),
        'completed_routes', (
          select count(*)
          from route_plans r
          join users u on u.id = r.assigned_to
          where u.role = 5
            and lower(coalesce(u.region, '')) = lower(coalesce(s.region, ''))
            and lower(coalesce(r.status, '')) = 'completed'
            and r.route_date = current_date
        )
      ),
      CURRENT_TIMESTAMP
    from users s
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
    alter table route_plans add column isSynced BOOLEAN not null default false;
  end if;
end $$;

create table if not exists catalog_items (
  id VARCHAR(36) primary key default (UUID()),
  name text not null,
  category text not null,
  sku text not null unique,
  item_type text not null default 'sale',
  unit_price numeric(12,2) not null default 0,
  stock_qty integer not null default 0,
  description text,
  is_active BOOLEAN not null default true,
  isSynced BOOLEAN not null default false,
  created_by VARCHAR(36) references users (id) on delete set null,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'isSynced') then
    alter table catalog_items add column isSynced BOOLEAN not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'is_active') then
    alter table catalog_items add column is_active BOOLEAN not null default true;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'catalog_items' and column_name = 'item_type') then
    alter table catalog_items add column item_type text not null default 'sale';
  end if;
end $$;

create table if not exists orders (
  id VARCHAR(36) primary key default (UUID()),
  school_id VARCHAR(36) references schools (id) on delete set null,
  school_name text not null,
  school_phone text,
  agent_id VARCHAR(36) references users (id) on delete set null,
  order_number text not null unique,
  payment_method text not null default 'cash',
  payment_reference text,
  checkout_amount numeric(12,2) not null default 0,
  status text not null default 'pending',
  notes text,
  submitted_at DATETIME,
  approved_at DATETIME,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'orders' and column_name = 'isSynced') then
    alter table orders add column isSynced BOOLEAN not null default false;
  end if;
end $$;

create table if not exists order_items (
  id VARCHAR(36) primary key default (UUID()),
  order_id VARCHAR(36) not null references orders (id) on delete cascade,
  product_name text not null,
  category text,
  sku text,
  quantity integer not null default 1,
  unit_price numeric(12,2) not null default 0,
  line_total numeric(12,2) not null default 0,
  notes text,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'order_items' and column_name = 'isSynced') then
    alter table order_items add column isSynced BOOLEAN not null default false;
  end if;
end $$;

create table if not exists messages (
  id VARCHAR(36) primary key default (UUID()),
  sender_id VARCHAR(36) not null references users (id) on delete cascade,
  recipient_id VARCHAR(36) not null references users (id) on delete cascade,
  subject text not null,
  body text not null,
  related_school_id VARCHAR(36) references schools (id) on delete set null,
  related_task_id VARCHAR(36) references tasks (id) on delete set null,
  is_read BOOLEAN not null default false,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'messages' and column_name = 'isSynced') then
    alter table messages add column isSynced BOOLEAN not null default false;
  end if;
end $$;

create table if not exists school_visits (
  id VARCHAR(36) primary key default (UUID()),
  school_id VARCHAR(36) not null references schools (id) on delete cascade,
  agent_id VARCHAR(36) references users (id) on delete set null,
  outcome text,
  notes text,
  photo_url text,
  photo_path text,
  latitude DOUBLE,
  longitude DOUBLE,
  visit_status text not null default 'completed',
  visited_at DATETIME not null default CURRENT_TIMESTAMP,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_visits' and column_name = 'isSynced') then
    alter table school_visits add column isSynced BOOLEAN not null default false;
  end if;
end $$;

create table if not exists school_follow_ups (
  id VARCHAR(36) primary key default (UUID()),
  school_id VARCHAR(36) not null references schools (id) on delete cascade,
  agent_id VARCHAR(36) references users (id) on delete set null,
  contact_person text,
  next_step text,
  due_at DATETIME,
  notes text,
  follow_up_status text not null default 'open',
  completed_at DATETIME,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_follow_ups' and column_name = 'isSynced') then
    alter table school_follow_ups add column isSynced BOOLEAN not null default false;
  end if;
end $$;

create table if not exists debt_collections (
  id VARCHAR(36) primary key default (UUID()),
  school_id VARCHAR(36) not null references schools (id) on delete cascade,
  collected_by VARCHAR(36) references users (id) on delete set null,
  amount numeric(12,2) not null check (amount > 0),
  payment_method text not null default 'cash',
  payment_reference text,
  notes text,
  collected_at DATETIME not null default CURRENT_TIMESTAMP,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

create table if not exists school_sales (
  id VARCHAR(36) primary key default (UUID()),
  school_id VARCHAR(36) not null references schools (id) on delete cascade,
  agent_id VARCHAR(36) references users (id) on delete set null,
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
  stage_updated_at DATETIME,
  expected_close_date date,
  probability integer not null default 0 check (probability >= 0 and probability <= 100),
  closed_at DATETIME,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'isSynced') then
    alter table school_sales add column isSynced BOOLEAN not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'next_action') then
    alter table school_sales add column next_action text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'next_action_date') then
    alter table school_sales add column next_action_date date;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'last_activity_at') then
    alter table school_sales add column last_activity_at DATETIME;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'forecast_category') then
    alter table school_sales add column forecast_category text default 'pipeline';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'risk_level') then
    alter table school_sales add column risk_level text default 'low';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'weighted_forecast') then
    alter table school_sales add column weighted_forecast numeric(12,2) default 0;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sales' and column_name = 'stage_sla_due_at') then
    alter table school_sales add column stage_sla_due_at DATETIME;
  end if;
end $$;

create index if not exists idx_school_sales_stage_sla_due_at
  on school_sales (stage_sla_due_at);
create index if not exists idx_school_sales_next_action_date
  on school_sales (next_action_date);
create index if not exists idx_school_sales_risk_level
  on school_sales (risk_level);

create table if not exists opportunity_activities (
  id VARCHAR(36) primary key default (UUID()),
  opportunity_id VARCHAR(36) not null references school_sales (id) on delete cascade,
  school_id VARCHAR(36) references schools (id) on delete set null,
  actor_id VARCHAR(36) references users (id) on delete set null,
  activity_type text not null,
  activity_outcome text,
  notes text,
  next_action text,
  next_action_date date,
  created_at DATETIME not null default CURRENT_TIMESTAMP
);

create index if not exists idx_opportunity_activities_opportunity
  on opportunity_activities (opportunity_id, created_at desc);

create or replace function refresh_school_sale_metrics()
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
    new.stage_sla_due_at := CURRENT_TIMESTAMP + make_interval(days => v_sla_days);
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

drop trigger if exists derive_school_sale_metrics on school_sales;
create trigger derive_school_sale_metrics
before insert or update on school_sales
for each row execute procedure refresh_school_sale_metrics();

create or replace function enforce_school_sale_followup()
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
    if nullif(TRIM(coalesce(new.next_action, '')), '') is null then
      new.next_action := 'Follow up call';
    end if;
    if new.next_action_date is null then
      new.next_action_date := current_date + 2;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_school_sale_followup_trigger on school_sales;
create trigger enforce_school_sale_followup_trigger
before insert or update on school_sales
for each row execute procedure enforce_school_sale_followup();

update school_sales
set
  next_action = coalesce(nullif(TRIM(next_action), ''), 'Follow up call'),
  next_action_date = coalesce(next_action_date, current_date + 2)
where lower(coalesce(sale_status, 'lead')) not in ('won', 'lost', 'dormant')
  and (
    nullif(TRIM(coalesce(next_action, '')), '') is null
    or next_action_date is null
  );

create or replace function sync_opportunity_activity_to_sale()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if nullif(TRIM(coalesce(new.next_action, '')), '') is null then
    raise exception 'next_action is required when logging opportunity activity';
  end if;
  if new.next_action_date is null then
    raise exception 'next_action_date is required when logging opportunity activity';
  end if;

  update school_sales
  set
    last_activity_at = new.created_at,
    next_action = new.next_action,
    next_action_date = new.next_action_date,
    stage_updated_at = CURRENT_TIMESTAMP
  where id = new.opportunity_id;

  return new;
end;
$$;

drop trigger if exists sync_opportunity_activity_to_sale_trigger on opportunity_activities;
create trigger sync_opportunity_activity_to_sale_trigger
after insert on opportunity_activities
for each row execute procedure sync_opportunity_activity_to_sale();

create or replace function enforce_role5_task_completion_evidence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_role5 BOOLEAN := false;
  v_has_evidence BOOLEAN := false;
begin
  if lower(coalesce(new.status, '')) not in ('closed', 'completed') then
    return new;
  end if;

  if lower(coalesce(old.status, '')) in ('closed', 'completed') then
    return new;
  end if;

  select exists (
    select 1 from users u
    where u.id = new.assigned_to
      and u.role = 5
  ) into v_is_role5;

  if not v_is_role5 then
    return new;
  end if;

  select exists (
    select 1
    from task_completion_evidence e
    where e.task_id = new.id
      and e.gps_lat is not null
      and e.gps_lng is not null
      and nullif(TRIM(coalesce(e.proof_url, '')), '') is not null
  ) into v_has_evidence;

  if not v_has_evidence then
    raise exception 'Role 5 task completion requires evidence with GPS and proof_url';
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_role5_task_completion_evidence_trigger on tasks;
create trigger enforce_role5_task_completion_evidence_trigger
before update on tasks
for each row execute procedure enforce_role5_task_completion_evidence();

create or replace function generate_overdue_followup_alerts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_count integer := 0;
begin
  insert into supervisor_alerts (
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
    CURRENT_TIMESTAMP
  from school_sales s
  join users u on u.id = s.agent_id
  where u.role = 5
    and s.next_action_date is not null
    and s.next_action_date < current_date
    and lower(coalesce(s.sale_status, '')) not in ('won', 'lost', 'dormant')
    and not exists (
      select 1
      from supervisor_alerts a
      where a.user_id = s.agent_id
        and a.alert_type = 'overdue_followup'
        and a.status = 'open'
        and a.created_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 24 HOURS)
    );

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create table if not exists pipeline_history (
  id VARCHAR(36) primary key default (UUID()),
  pipeline_id VARCHAR(36) not null references school_sales (id) on delete cascade,
  old_stage text,
  new_stage text not null,
  changed_by VARCHAR(36) references users (id) on delete set null,
  changed_at DATETIME not null default CURRENT_TIMESTAMP,
  notes text
);

create index if not exists idx_pipeline_history_pipeline_id
  on pipeline_history (pipeline_id);

create index if not exists idx_pipeline_history_changed_at
  on pipeline_history (changed_at desc);

create or replace function log_pipeline_stage_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
    values (new.id, null, new.sale_status, auth.uid(), new.notes);
    return new;
  end if;

  if tg_op = 'UPDATE' and coalesce(new.sale_status, '') <> coalesce(old.sale_status, '') then
    insert into pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
    values (new.id, old.sale_status, new.sale_status, auth.uid(), new.notes);
  end if;

  return new;
end;
$$;

create table if not exists school_sample_distributions (
  id VARCHAR(36) primary key default (UUID()),
  school_id VARCHAR(36) not null references schools (id) on delete cascade,
  agent_id VARCHAR(36) references users (id) on delete set null,
  sample_name text not null,
  sample_category text,
  quantity integer not null default 1,
  stamped_receipt_url text,
  stamped_receipt_path text,
  notes text,
  distributed_at DATETIME not null default CURRENT_TIMESTAMP,
  isSynced BOOLEAN not null default false,
  created_at DATETIME not null default CURRENT_TIMESTAMP,
  updated_at DATETIME not null default CURRENT_TIMESTAMP
);

do $$
begin
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'isSynced') then
    alter table school_sample_distributions add column isSynced BOOLEAN not null default false;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'stamped_receipt_url') then
    alter table school_sample_distributions add column stamped_receipt_url text;
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'school_sample_distributions' and column_name = 'stamped_receipt_path') then
    alter table school_sample_distributions add column stamped_receipt_path text;
  end if;
end $$;

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into users (id, email, full_name, phone, role, region)
  values (
    new.id,
    new.email,
    coalesce(nullif(TRIM(new.raw_user_meta_data ->> 'full_name'), ''), 'Not Captured'),
    coalesce(nullif(TRIM(new.raw_user_meta_data ->> 'phone'), ''), 'Not Captured'),
    role_id_from_text(new.raw_user_meta_data ->> 'role'),
    coalesce(nullif(TRIM(new.raw_user_meta_data ->> 'region'), ''), 'Not Captured')
  )
  ON DUPLICATE KEY UPDATE 
  title = VALUES(title),
  description = VALUES(description),
  questions = VALUES(questions),
  assigned_user_ids = VALUES(assigned_user_ids),
  published_at = VALUES(published_at),
  created_by = VALUES(created_by)

insert into project_form_responses (
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
    'a1a1a1a1-1111-4444-8888-111111111111',
    'Term 2 School Readiness Check',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '{
      "School Name":"Nairobi Primary",
      "Visit Date":"2026-05-20",
      "Head Teacher Contact":"+254700123456",
      "Books Received?":Yes,
      "Readiness Rating":8
    }',
    DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 20 HOURS)
  ),
  (
    'b2b2b2b2-2222-4444-9999-222222222222',
    'a2a2a2a2-2222-4444-8888-222222222222',
    'Weekly Route Feedback Form',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '{
      "Route Name":"Kisumu West Cluster",
      "Arrival Time":"09:10",
      "Main Challenge":"Delayed handover at first school.",
      "Evidence Upload":"route-photo-2026-05-21.jpg",
      "Overall Experience":4
    }',
    DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 10 HOURS)
  )
ON DUPLICATE KEY UPDATE 
  form_id = VALUES(form_id),
  form_title = VALUES(form_title),
  respondent_id = VALUES(respondent_id),
  answers = VALUES(answers),
  submitted_at = VALUES(submitted_at)

-- END FILE: supabase/schema_updates_project_forms.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates_sample_proof.sql
-- =========================================================
-- Add stamped sample proof fields on schools


alter table schools
  add column if not exists sample_proof_url text;

alter table schools
  add column if not exists sample_proof_path text;



-- END FILE: supabase/schema_updates_sample_proof.sql

-- =========================================================
-- BEGIN FILE: supabase/schema_updates_tasks_pipeline.sql
-- =========================================================
-- Task + pipeline SQL updates for dashboard filtering and consistency



-- 1) Normalize task statuses before adding constraint
update tasks
set status = 'closed'
where lower(status) in ('complete', 'completed', 'done');

update tasks
set status = 'in_progress'
where lower(status) in ('in progress', 'progress');

update tasks
set status = 'open'
where lower(status) not in ('open', 'in_progress', 'closed');

-- 2) Enforce allowed task statuses
alter table tasks
  drop constraint if exists tasks_status_check;

alter table tasks
  add constraint tasks_status_check
  check (status in ('open', 'in_progress', 'closed'));

-- 3) Helpful indexes for admin dashboard filters
create index if not exists idx_tasks_status_due_at
  on tasks (status, due_at);

create index if not exists idx_tasks_target_role_status
  on tasks (target_role, status);

create index if not exists idx_school_sales_stage_updated_at
  on school_sales (sale_status, stage_updated_at desc);



-- END FILE: supabase/schema_updates_tasks_pipeline.sql

-- =========================================================
-- BEGIN FILE: supabase/seed.sql
-- =========================================================
-- ==========================================
-- Dummy Data Seed Script for Dehus App
-- Run this in your Supabase SQL Editor
-- ==========================================

-- 1. Insert Dummy Schools
INSERT INTO schools (
  id,
  name,
  phone,
  county,
  focusAreas,
  book_category,
  latitude,
  longitude,
  photo_url,
  photo_path,
  capture_status,
  captured_by,
  captured_at,
  isSynced
)
VALUES 
  ('22222222-2222-2222-2222-222222222222', 'Nairobi Primary School', '0712345678', 'Nairobi', '[Mathematics, Science]', 'Book List', -1.2921, 36.8219, 'https://images.unsplash.com/photo-1503676260728-1c00da094a0b', 'schools/nairobi-primary.jpg', 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY), true),
  ('33333333-3333-3333-3333-333333333333', 'Mombasa High School', '0723456789', 'Mombasa', '[Languages, Arts]', 'Book Fund', -4.0435, 39.6682, 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1', 'schools/mombasa-high.jpg', 'Photo captured successfully', '11111111-1111-1111-1111-111111111111', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY), true),
  ('44444444-4444-4444-4444-444444444444', 'Kisumu Boys', '0734567890', 'Kisumu', '[Sports, Science]', NULL, -0.1022, 34.7617, NULL, NULL, 'Location not captured yet', '11111111-1111-1111-1111-111111111111', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY), true),
  ('55555555-5555-5555-5555-555555555555', 'Nakuru Girls', '0745678901', 'Nakuru', '[Mathematics, Business]', 'Book List', -0.3031, 36.0800, 'https://images.unsplash.com/photo-1497486751825-1233686d5d80', 'schools/nakuru-girls.jpg', 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY), true),
  ('66666666-6666-6666-6666-666666666666', 'Eldoret Academy', '0756789012', 'Uasin Gishu', '[Agriculture, Science]', NULL, 0.5143, 35.2698, NULL, NULL, 'Photo captured successfully', '11111111-1111-1111-1111-111111111111', DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY), true)
ON DUPLICATE KEY UPDATE 
  email = VALUES(email),
  full_name = VALUES(full_name),
  phone = VALUES(phone),
  role = VALUES(role),
  region = VALUES(region)

-- 2) Pick up to 4 schools for linking data
with s as (
  select id, row_number() over (order by created_at desc nulls last, id) rn
  from schools
  limit 4
)
insert into school_sample_distributions (
  id, school_id, agent_id, sample_name, sample_category, quantity,
  stamped_receipt_url, stamped_receipt_path, notes, distributed_at, isSynced
)
select
  (CONCAT('93000000-0000-0000-0000-', lpad)(rn, 12, '0')),
  s.id,
  case when s.rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'
    else '92000000-0000-0000-0000-000000000001'
  end,
  case when s.rn % 2 = 0 then 'Teacher Guide Kit' else 'Grade 1 Reader Pack' end,
  case when s.rn % 2 = 0 then 'Reference' else 'Primary' end,
  (s.rn % 3) + 1,
  'https://images.unsplash.com/photo-1455390582262-044cdead277a?w=1200',
  CONCAT('sample_receipts/demo_', s.rn) || '.jpg',
  'Dummy ROI receipt seed',
  CURRENT_TIMESTAMP - ((CONCAT(s.rn, ' days'))),
  true
from s
ON DUPLICATE KEY UPDATE 
  school_id = VALUES(school_id),
  agent_id = VALUES(agent_id),
  sample_name = VALUES(sample_name),
  sample_category = VALUES(sample_category),
  quantity = VALUES(quantity),
  stamped_receipt_url = VALUES(stamped_receipt_url),
  stamped_receipt_path = VALUES(stamped_receipt_path),
  notes = VALUES(notes),
  distributed_at = VALUES(distributed_at),
  isSynced = VALUES(isSynced)

-- 3) Orders for revenue earned metric
insert into orders (
  id, school_id, school_name, school_phone, agent_id, order_number,
  payment_method, payment_reference, checkout_amount, status, notes, submitted_at, approved_at, isSynced
)
select
  (CONCAT('94000000-0000-0000-0000-', lpad)(rn, 12, '0')),
  s.id,
  coalesce(sc.name, CONCAT('School ', s.rn)),
  coalesce(sc.phone, '0700000000'),
  case when s.rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'
    else '92000000-0000-0000-0000-000000000001'
  end,
  CONCAT('DEMO-ROI-', s.rn),
  'mpesa',
  CONCAT('MPESA-DEMO-', s.rn),
  (50000 + (s.rn * 10000)),
  case when s.rn % 3 = 0 then 'pending' else 'approved' end,
  'Dummy ROI order',
  CURRENT_TIMESTAMP - ((CONCAT(s.rn, ' days'))),
  CURRENT_TIMESTAMP - (((s.rn + 1) || ' days')),
  true
from (
  select id, row_number() over (order by created_at desc nulls last, id) rn
  from schools
  limit 4
) s
left join schools sc on sc.id = s.id
ON DUPLICATE KEY UPDATE 
  school_id = VALUES(school_id),
  school_name = VALUES(school_name),
  school_phone = VALUES(school_phone),
  agent_id = VALUES(agent_id),
  checkout_amount = VALUES(checkout_amount),
  status = VALUES(status),
  notes = VALUES(notes),
  submitted_at = VALUES(submitted_at),
  approved_at = VALUES(approved_at),
  isSynced = VALUES(isSynced)

-- 4) School sales for won value metric
insert into school_sales (
  id, school_id, agent_id, package_name, expected_value, notes,
  sale_status, stage_updated_at, probability, closed_at, isSynced
)
select
  (CONCAT('95000000-0000-0000-0000-', lpad)(rn, 12, '0')),
  s.id,
  case when s.rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'
    else '92000000-0000-0000-0000-000000000001'
  end,
  'ROI Demo Package',
  (90000 + (s.rn * 12000)),
  'Dummy ROI pipeline',
  case when s.rn % 2 = 0 then 'won' else 'negotiation' end,
  CURRENT_TIMESTAMP - ((CONCAT(s.rn, ' days'))),
  case when s.rn % 2 = 0 then 100 else 70 end,
  case when s.rn % 2 = 0 then CURRENT_TIMESTAMP - ((CONCAT(s.rn, ' days'))) else null end,
  true
from (
  select id, row_number() over (order by created_at desc nulls last, id) rn
  from schools
  limit 4
) s
ON DUPLICATE KEY UPDATE 
  school_id = VALUES(school_id),
  agent_id = VALUES(agent_id),
  package_name = VALUES(package_name),
  expected_value = VALUES(expected_value),
  notes = VALUES(notes),
  sale_status = VALUES(sale_status),
  stage_updated_at = VALUES(stage_updated_at),
  probability = VALUES(probability),
  closed_at = VALUES(closed_at),
  isSynced = VALUES(isSynced)



-- END FILE: supabase/seed_sample_roi_dummy.sql

-- =========================================================
-- BEGIN FILE: supabase/storage_policies_sample_receipts.sql
-- =========================================================
-- Enable storage for stamped sample receipt photos
-- Run in Supabase SQL editor as a project admin.



-- 1) Ensure bucket exists (public for easy admin viewing via public URL)
insert into storage.buckets (id, name, public)
values ('schools', 'schools', true)
ON DUPLICATE KEY UPDATE  public = true

-- Optional dedicated bucket (if you later switch app upload target)
insert into storage.buckets (id, name, public)
values ('sample-receipts', 'sample-receipts', true)
ON DUPLICATE KEY UPDATE  public = true

-- 2) Policies for 'schools' bucket

create policy authenticated_can_view_schools_bucket
on storage.objects
for select
to authenticated
using (bucket_id = 'schools');


create policy authenticated_can_upload_schools_bucket
on storage.objects
for insert
to authenticated
with check (bucket_id = 'schools');


create policy authenticated_can_update_schools_bucket
on storage.objects
for update
to authenticated
using (bucket_id = 'schools')
with check (bucket_id = 'schools');

-- 3) Policies for dedicated 'sample-receipts' bucket

create policy authenticated_can_view_sample_receipts_bucket
on storage.objects
for select
to authenticated
using (bucket_id = 'sample-receipts');


create policy authenticated_can_upload_sample_receipts_bucket
on storage.objects
for insert
to authenticated
with check (bucket_id = 'sample-receipts');


create policy authenticated_can_update_sample_receipts_bucket
on storage.objects
for update
to authenticated
using (bucket_id = 'sample-receipts')
with check (bucket_id = 'sample-receipts');



-- END FILE: supabase/storage_policies_sample_receipts.sql
