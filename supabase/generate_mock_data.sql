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
  id, school_id, sale_status, expected_value, stage_updated_at, probability, notes, "isSynced"
)
select
  ('91000000-0000-0000-0000-' || lpad(ss.rn::text, 12, '0'))::uuid as id,
  ss.id as school_id,
  sm.stage,
  sm.expected_value,
  now() - make_interval(days => ss.rn),
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
  sale_status = excluded.sale_status,
  expected_value = excluded.expected_value,
  stage_updated_at = excluded.stage_updated_at,
  probability = excluded.probability,
  notes = excluded.notes,
  "isSynced" = excluded."isSynced";

commit;
