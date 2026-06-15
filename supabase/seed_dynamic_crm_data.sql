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
INSERT INTO public.orders (school_id, school_name, order_number, checkout_amount, status, created_at)
SELECT id, name, 'ORD-1001', 450000, 'completed', now() - interval '1 year'
FROM public.schools WHERE name = 'Greenwood High';

INSERT INTO public.orders (school_id, school_name, order_number, checkout_amount, status, created_at)
SELECT id, name, 'ORD-1002', 25000, 'pending', now() - interval '1 month'
FROM public.schools WHERE name = 'St. Andrews Academy';

-- 7. Add Lead Scores explicitly if the trigger didn't backfill
UPDATE public.schools SET lead_score = 85 WHERE name = 'St. Andrews Academy';
UPDATE public.schools SET lead_score = 95 WHERE name = 'Greenwood High';
UPDATE public.schools SET lead_score = 45 WHERE name = 'Sunshine Primary School';
