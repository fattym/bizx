-- 1. Clean up existing mock data to avoid conflicts (Optional, but recommended for a clean start)
-- TRUNCATE public.school_sales, public.school_visits, public.opportunity_activities, public.schools CASCADE;

-- 2. Insert realistic Schools
INSERT INTO public.schools (id, name, phone, county, school_ownership, school_population, book_category, "focusAreas", lead_score, created_at)
VALUES 
  (gen_random_uuid(), 'St. Andrews Academy', '0711222333', 'Nairobi', 'Private', 1200, 'Book Fund', '["Mathematics", "Science"]', 85, now() - interval '45 days'),
  (gen_random_uuid(), 'Sunshine Primary School', '0722333444', 'Kiambu', 'Public', 800, 'Government Supply', '["Literacy"]', 45, now() - interval '32 days'),
  (gen_random_uuid(), 'Greenwood High', '0733444555', 'Mombasa', 'Private', 1500, 'Book Fund', '["Technology", "Art"]', 95, now() - interval '10 days'),
  (gen_random_uuid(), 'Hillcrest International', '0744555666', 'Nairobi', 'Private', 600, 'Premium', '["All Subjects"]', 60, now() - interval '5 days'),
  (gen_random_uuid(), 'Riverbank School', '0755666777', 'Nakuru', 'Public', 450, 'Standard', '["Physical Ed"]', 20, now() - interval '65 days')
ON CONFLICT DO NOTHING;

-- 3. Insert Sales Opportunities (linked to the schools we just made)
-- We use a subquery to get IDs to ensure they match
INSERT INTO public.school_sales (id, school_id, package_name, expected_value, sale_status, probability, next_action, next_action_date, risk_level, created_at)
SELECT 
  gen_random_uuid(), 
  id, 
  'Annual Book Subscription', 
  CASE 
    WHEN name = 'St. Andrews Academy' THEN 500000 
    WHEN name = 'Greenwood High' THEN 750000 
    ELSE 150000 
  END,
  CASE 
    WHEN name = 'St. Andrews Academy' THEN 'negotiation'
    WHEN name = 'Sunshine Primary School' THEN 'sample_issued'
    WHEN name = 'Greenwood High' THEN 'won'
    WHEN name = 'Hillcrest International' THEN 'lead'
    ELSE 'lost'
  END,
  CASE 
    WHEN name = 'St. Andrews Academy' THEN 70
    WHEN name = 'Greenwood High' THEN 100
    ELSE 20
  END,
  'Finalize contract signature',
  current_date + 3,
  'low',
  now() - interval '20 days'
FROM public.schools
WHERE name IN ('St. Andrews Academy', 'Sunshine Primary School', 'Greenwood High', 'Hillcrest International', 'Riverbank School');

-- 4. Insert some Field Visits
INSERT INTO public.school_visits (school_id, outcome, notes, visited_at)
SELECT id, 'Positive meeting with Headteacher', 'Discussed new curriculum requirements.', now() - interval '2 days'
FROM public.schools WHERE name = 'St. Andrews Academy';

INSERT INTO public.school_visits (school_id, outcome, notes, visited_at)
SELECT id, 'Dropped off sample books', 'Librarian was very impressed.', now() - interval '5 days'
FROM public.schools WHERE name = 'Sunshine Primary School';

-- 5. Insert Opportunity Activities (to populate the timeline)
INSERT INTO public.opportunity_activities (opportunity_id, school_id, activity_type, activity_outcome, notes, next_action, next_action_date, created_at)
SELECT s.id, s.school_id, 'Call', 'Answered', 'Followed up on the quotation sent last week.', 'Send revised invoice', current_date + 1, now() - interval '1 day'
FROM public.school_sales s 
JOIN public.schools sch ON s.school_id = sch.id
WHERE sch.name = 'St. Andrews Academy';

-- 6. Insert some Orders for Financials
with demo_greenwood as (
  select id, name
  from public.schools
  where name = 'Greenwood High'
  order by created_at desc nulls last, id
  limit 1
)
INSERT INTO public.orders (school_id, school_name, order_number, checkout_amount, status, created_at)
SELECT id, name, 'ORD-1001', 450000, 'completed', now() - interval '1 year'
FROM demo_greenwood
ON CONFLICT (order_number) DO UPDATE SET
  school_id = excluded.school_id,
  school_name = excluded.school_name,
  checkout_amount = excluded.checkout_amount,
  status = excluded.status,
  created_at = excluded.created_at;

with demo_st_andrews as (
  select id, name
  from public.schools
  where name = 'St. Andrews Academy'
  order by created_at desc nulls last, id
  limit 1
)
INSERT INTO public.orders (school_id, school_name, order_number, checkout_amount, status, created_at)
SELECT id, name, 'ORD-1002', 25000, 'pending', now() - interval '1 month'
FROM demo_st_andrews
ON CONFLICT (order_number) DO UPDATE SET
  school_id = excluded.school_id,
  school_name = excluded.school_name,
  checkout_amount = excluded.checkout_amount,
  status = excluded.status,
  created_at = excluded.created_at;

-- 6b. Seed order items for the demo orders so itemized views render properly
INSERT INTO public.order_items (
  id, order_id, product_name, category, sku, quantity, unit_price, line_total, notes, "isSynced"
)
SELECT
  '97100000-0000-0000-0000-000000000001',
  o.id,
  'Annual Reader Pack',
  'Primary',
  'DR-AP-01',
  30,
  5000.00,
  150000.00,
  'Seeded line item for demo order.',
  true
FROM public.orders o
WHERE o.order_number = 'ORD-1001'
ON CONFLICT (id) DO UPDATE SET
  order_id = excluded.order_id,
  product_name = excluded.product_name,
  category = excluded.category,
  sku = excluded.sku,
  quantity = excluded.quantity,
  unit_price = excluded.unit_price,
  line_total = excluded.line_total,
  notes = excluded.notes,
  "isSynced" = excluded."isSynced";

INSERT INTO public.order_items (
  id, order_id, product_name, category, sku, quantity, unit_price, line_total, notes, "isSynced"
)
SELECT
  '97100000-0000-0000-0000-000000000002',
  o.id,
  'Teacher Guide Bundle',
  'Reference',
  'DG-TG-01',
  5,
  15000.00,
  75000.00,
  'Seeded line item for demo order.',
  true
FROM public.orders o
WHERE o.order_number = 'ORD-1001'
ON CONFLICT (id) DO UPDATE SET
  order_id = excluded.order_id,
  product_name = excluded.product_name,
  category = excluded.category,
  sku = excluded.sku,
  quantity = excluded.quantity,
  unit_price = excluded.unit_price,
  line_total = excluded.line_total,
  notes = excluded.notes,
  "isSynced" = excluded."isSynced";

INSERT INTO public.order_items (
  id, order_id, product_name, category, sku, quantity, unit_price, line_total, notes, "isSynced"
)
SELECT
  '97100000-0000-0000-0000-000000000003',
  o.id,
  'Revision Books',
  'Secondary',
  'DG-RB-01',
  10,
  1800.00,
  18000.00,
  'Seeded line item for demo order.',
  true
FROM public.orders o
WHERE o.order_number = 'ORD-1002'
ON CONFLICT (id) DO UPDATE SET
  order_id = excluded.order_id,
  product_name = excluded.product_name,
  category = excluded.category,
  sku = excluded.sku,
  quantity = excluded.quantity,
  unit_price = excluded.unit_price,
  line_total = excluded.line_total,
  notes = excluded.notes,
  "isSynced" = excluded."isSynced";

-- 7. Add Lead Scores explicitly if the trigger didn't backfill
UPDATE public.schools SET lead_score = 85 WHERE name = 'St. Andrews Academy';
UPDATE public.schools SET lead_score = 95 WHERE name = 'Greenwood High';
UPDATE public.schools SET lead_score = 45 WHERE name = 'Sunshine Primary School';

-- 8. Add explicit sales demo rows for admin dashboards and ROI screens
with demo_schools as (
  select id, name, phone, row_number() over (order by created_at desc nulls last, id) as rn
  from public.schools
  where name in (
    'St. Andrews Academy',
    'Sunshine Primary School',
    'Greenwood High',
    'Hillcrest International',
    'Riverbank School'
  )
)
insert into public.school_sales (
  id, school_id, agent_id, package_name, expected_value, notes,
  sale_status, stage_updated_at, expected_close_date, probability, closed_at, "isSynced"
)
select
  ('96000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  id,
  case when rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  'Sales Demo Package',
  case
    when name = 'St. Andrews Academy' then 210000
    when name = 'Greenwood High' then 340000
    when name = 'Hillcrest International' then 185000
    when name = 'Sunshine Primary School' then 125000
    else 90000
  end,
  'Seeded sales demo row',
  case
    when name = 'St. Andrews Academy' then 'negotiation'
    when name = 'Greenwood High' then 'won'
    when name = 'Hillcrest International' then 'quotation_sent'
    when name = 'Sunshine Primary School' then 'contacted'
    else 'lead'
  end,
  now() - interval '2 days',
  current_date + 14,
  case
    when name = 'Greenwood High' then 100
    when name = 'St. Andrews Academy' then 80
    when name = 'Hillcrest International' then 65
    when name = 'Sunshine Primary School' then 40
    else 25
  end,
  case
    when name = 'Greenwood High' then now() - interval '2 days'
    else null
  end,
  true
from demo_schools
on conflict (id) do nothing;

with demo_schools as (
  select id, name, phone, row_number() over (order by created_at desc nulls last, id) as rn
  from public.schools
  where name in (
    'St. Andrews Academy',
    'Sunshine Primary School',
    'Greenwood High',
    'Hillcrest International',
    'Riverbank School'
  )
)
insert into public.orders (
  id, school_id, school_name, school_phone, agent_id, order_number,
  payment_method, payment_reference, checkout_amount, status, notes, submitted_at, approved_at, "isSynced"
)
select
  ('97000000-0000-0000-0000-' || lpad(rn::text, 12, '0'))::uuid,
  id,
  name,
  coalesce(phone, '0700000000'),
  case when rn % 2 = 0
    then '92000000-0000-0000-0000-000000000002'::uuid
    else '92000000-0000-0000-0000-000000000001'::uuid
  end,
  'SALES-DEMO-' || rn,
  case
    when name = 'Greenwood High' then 'mpesa'
    when name = 'Hillcrest International' then 'bank'
    else 'cash'
  end,
  case
    when name = 'Greenwood High' then 'MPESA-DEMO-9001'
    when name = 'Hillcrest International' then 'BANK-DEMO-9002'
    else null
  end,
  case
    when name = 'St. Andrews Academy' then 210000
    when name = 'Greenwood High' then 340000
    when name = 'Hillcrest International' then 185000
    when name = 'Sunshine Primary School' then 125000
    else 90000
  end,
  case
    when name = 'Greenwood High' then 'approved'
    when name = 'Hillcrest International' then 'pending'
    else 'paid'
  end,
  'Seeded sales order',
  now() - interval '2 days',
  case
    when name = 'Hillcrest International' then null
    else now() - interval '1 day'
  end,
  true
from demo_schools
on conflict (id) do nothing;
