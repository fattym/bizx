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
end $$;

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
  or public.current_user_role_from_jwt() <= 2
  or (
    public.current_user_role_from_jwt() <= 3
    and region = public.current_user_region_from_jwt()
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
  or public.is_sales_manager()
);

drop policy if exists "admins_can_manage_tasks" on public.tasks;
drop policy if exists "managers_can_manage_tasks" on public.tasks;
create policy "managers_can_manage_tasks"
on public.tasks
for all
to authenticated
using (public.is_manager_or_admin())
with check (public.is_manager_or_admin());

drop policy if exists "authenticated_can_view_geofences" on public.geofences;
create policy "authenticated_can_view_geofences"
on public.geofences
for select
to authenticated
using (
  assigned_to = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "managers_can_manage_geofences" on public.geofences;
create policy "managers_can_manage_geofences"
on public.geofences
for all
to authenticated
using (public.is_manager_or_admin())
with check (public.is_manager_or_admin());

drop policy if exists "authenticated_can_view_route_plans" on public.route_plans;
create policy "authenticated_can_view_route_plans"
on public.route_plans
for select
to authenticated
using (
  assigned_to = auth.uid()
  or public.is_manager_or_admin()
);

drop policy if exists "managers_can_manage_route_plans" on public.route_plans;
create policy "managers_can_manage_route_plans"
on public.route_plans
for all
to authenticated
using (public.is_manager_or_admin())
with check (public.is_manager_or_admin());

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
