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

-- 1b. Extra geocoded schools for stronger map coverage
-- Coordinates are seeded as ready-to-pin values.
INSERT INTO public.schools (
  id,
  name,
  phone,
  county,
  "focusAreas",
  book_category,
  latitude,
  longitude,
  capture_status,
  captured_by,
  captured_at,
  "isSynced"
)
VALUES
  ('a1000000-0000-0000-0000-000000000001', 'Westlands Academy', '0701000001', 'Nairobi', '["Mathematics","Languages"]'::jsonb, 'Book List', -1.2676, 36.8108, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000002', 'Thika Road School', '0701000002', 'Kiambu', '["Science","ICT"]'::jsonb, 'Book Fund', -1.2037, 36.8931, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000003', 'Machakos Township School', '0701000003', 'Machakos', '["Business","Mathematics"]'::jsonb, 'Book List', -1.5177, 37.2634, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000004', 'Kajiado Central School', '0701000004', 'Kajiado', '["Languages","Arts"]'::jsonb, 'Book Fund', -1.8521, 36.7768, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000005', 'Meru Greenhill School', '0701000005', 'Meru', '["Science","Agriculture"]'::jsonb, 'Book List', 0.0463, 37.6559, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000006', 'Kakamega East School', '0701000006', 'Kakamega', '["Mathematics","Science"]'::jsonb, 'Book Fund', 0.2827, 34.7519, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000007', 'Kisii Hills School', '0701000007', 'Kisii', '["Languages","Business"]'::jsonb, 'Book List', -0.6773, 34.7796, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000008', 'Nyeri Highlands Academy', '0701000008', 'Nyeri', '["Science","ICT"]'::jsonb, 'Book Fund', -0.4201, 36.9476, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000009', 'Kericho Springs School', '0701000009', 'Kericho', '["Agriculture","Mathematics"]'::jsonb, 'Book List', -0.3687, 35.2831, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000010', 'Bungoma Ridge School', '0701000010', 'Bungoma', '["Science","Sports"]'::jsonb, 'Book Fund', 0.5635, 34.5606, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000011', 'Garissa Model School', '0701000011', 'Garissa', '["Languages","Mathematics"]'::jsonb, 'Book List', -0.4532, 39.6401, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true),
  ('a1000000-0000-0000-0000-000000000012', 'Malindi Coast Academy', '0701000012', 'Kilifi', '["Arts","Languages"]'::jsonb, 'Book Fund', -3.2175, 40.1169, 'GPS updated successfully', '11111111-1111-1111-1111-111111111111', now() - interval '2 day', true)
ON CONFLICT (id) DO UPDATE
SET name = excluded.name,
    phone = excluded.phone,
    county = excluded.county,
    "focusAreas" = excluded."focusAreas",
    book_category = excluded.book_category,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
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

-- Dummy sample catalog items for onboarding/sample pages

-- Limited to 70 catalog items as requested
INSERT INTO public.catalog_items (id, name, category, sku, item_type, unit_price, stock_qty, description, is_active, created_by, "isSynced") VALUES
('ad6a61ec-427d-4ec3-84a9-f229979cf473', 'Language Activities LB', 'Pre-Primary', '9879966645180', 'sale', 715.01, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('ae529b24-787b-4e2f-b472-85a760c5a086', 'Language Activities LB (Sample)', 'Pre-Primary', 'SMPL-9879966645180', 'sample', 715.01, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('db8f2153-7d4c-4a55-9a09-f29f3a587832', 'Environmental Activities LB', 'Pre-Primary', '9879966645203', 'sale', 627.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('681789a2-7c01-4d2a-bf64-53a06b0aa8b4', 'Environmental Activities LB (Sample)', 'Pre-Primary', 'SMPL-9879966645203', 'sample', 627.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('85f599f8-e44a-4529-aeff-62350c4f96ef', 'Mathematics Activities LB', 'Pre-Primary', '9879966645227', 'sale', 682.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('1d7bf13b-3da6-4073-8e26-e284d8f4da1b', 'Mathematics Activities LB (Sample)', 'Pre-Primary', 'SMPL-9879966645227', 'sample', 682.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('926fc7dc-2394-4213-a3ff-e489836aa658', 'Creative Activities LB', 'Pre-Primary', '9789966645241', 'sale', 643.5, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('50c3ea63-c578-421a-925a-280e7a4702c8', 'Creative Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645241', 'sample', 643.5, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('933efcc3-7385-4e0a-a13a-cc9dc4efedf1', 'Christian Religious Education Activities LB', 'Pre-Primary', '9789966645265', 'sale', 682.01, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('72f23288-bdfd-4902-8548-d72dc11884dc', 'Christian Religious Education Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645265', 'sample', 682.01, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('6471444d-f190-4ad6-869e-97f01328976c', 'Language Activities TG', 'Pre-Primary', '9789966645197', 'sale', 825.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('fcb4e0ce-07db-448f-b1c3-5bef7c75cd58', 'Language Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645197', 'sample', 825.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('a06beaf0-0f23-46b9-977e-378feb83290c', 'Environmental Activities TG', 'Pre-Primary', '9789966645210', 'sale', 825.01, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('d1598551-b4d5-4d4b-aacf-633b0ac99c8e', 'Environmental Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645210', 'sample', 825.01, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('c6099e52-4d42-4f4a-b6c2-06419a974b42', 'Mathematics Activities TG', 'Pre-Primary', '9789966645234', 'sale', 774.35, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('6fe1f6d9-2d8b-4fe7-bfaa-0157b6ede689', 'Mathematics Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645234', 'sample', 774.35, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('f8227578-f8d0-4bd8-a7c3-1a6d787d8801', 'Creative Activities TG', 'Pre-Primary', '9789966645258', 'sale', 730.38, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('d1ee9936-888b-494c-88fe-b262250c4c10', 'Creative Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645258', 'sample', 730.38, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('4d8d7948-4e92-4b89-af11-0a4a4643fb32', 'Christian Religious Education Activities TG', 'Pre-Primary', '9789966645272', 'sale', 697.7, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('5d38e05c-0c88-4467-a360-991a73e812d4', 'Christian Religious Education Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645272', 'sample', 697.7, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('cd1bfecd-66aa-4b3a-86aa-aba7ac0995cb', 'Language Activities LB', 'Pre-Primary', '9789966645289', 'sale', 715.01, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('bf19d014-b409-4e60-a4d4-f7990a1683a9', 'Language Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645289', 'sample', 715.01, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('ea41b7c3-bf34-457f-80fd-618bbfdb4b69', 'Environmental Activities LB', 'Pre-Primary', '9789966645302', 'sale', 698.51, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('d90b5512-252e-422c-800b-02160d9ddb55', 'Environmental Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645302', 'sample', 698.51, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('0072345d-a738-46df-a9de-3a71b90a68c7', 'Mathematics Activities LB', 'Pre-Primary', '9789966645326', 'sale', 682.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('130b5936-e079-4c87-9019-a2b6fcc6cf00', 'Mathematics Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645326', 'sample', 682.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('ec70aec1-a1f2-4c81-814f-befbc2436b2e', 'Creative Activities LB', 'Pre-Primary', '9789966645340', 'sale', 649.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('65b2d327-9fd6-48d7-a196-dc708d51ec6d', 'Creative Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966645340', 'sample', 649.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('48b6f230-dee2-49eb-95ae-1937810a06e8', 'Christian Religious Education Activities LB', 'Pre-Primary', '9789966644701', 'sale', 616.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('92c6a996-0a06-46d2-a218-055705ea412c', 'Christian Religious Education Activities LB (Sample)', 'Pre-Primary', 'SMPL-9789966644701', 'sample', 616.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('912832cf-8b78-456f-882a-5d4c84cec60a', 'Language Activities TG', 'Pre-Primary', '9789966645296', 'sale', 825.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('be3370a3-5b91-4b31-ad64-715e54c39e75', 'Language Activities TG (Sample)', 'Pre-Primary', 'SMPL-9789966645296', 'sample', 825.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('853aed80-dd14-479e-b530-7c46c75d90f3', 'Longhorn charts: Insects [Approved]', 'Wall Charts', '9789966315311', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('ea35a87d-229b-4905-8df1-5f3e409dbe4e', 'Longhorn charts: Insects [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315311', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('dbe77e0e-5dfc-4530-8be9-a8d6f3e9c210', 'Longhorn charts Numbers 1-10 [Approved]', 'Wall Charts', '9789966315335', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('91a4fd9a-8a47-4efd-b481-647b0f26fd86', 'Longhorn charts Numbers 1-10 [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315335', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('cc60c918-9448-4191-8b92-3bb5dd0c2cd3', 'Longhorn charts: Plants [Approved]', 'Wall Charts', '9789966315359', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('bdb47b18-2e0f-40cc-bad8-578aa893d26a', 'Longhorn charts: Plants [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315359', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('dd101da1-e303-4b66-914e-6c5ff380190f', 'Longhorn charts: Parts Of The Body [Approved]', 'Wall Charts', '9789966315342', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('e56a4beb-8b2b-43b8-9ce1-cf8af0630299', 'Longhorn charts: Parts Of The Body [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315342', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('9a162458-ed07-497b-acff-554a07c2fe1f', 'Longhorn charts: Shapes [Approved]', 'Wall Charts', '9789966744118', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('5aa5dc95-f9ac-4e0a-987b-dbfc8c7f98f7', 'Longhorn charts: Shapes [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966744118', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('9dbbcbc6-1951-4e39-b3db-94e0a0bf7e1f', 'Longhorn charts: Furniture Use At Home [Approved]', 'Wall Charts', '9789966315304', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('bd598dbd-3f58-48eb-bdb0-bb3263b6d85d', 'Longhorn charts: Furniture Use At Home [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315304', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('8cf665eb-45fa-4cf1-a70d-feb8eab533eb', 'Longhorn charts: Food Eaten At Home [Approved]', 'Wall Charts', '9789966315274', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('db160dee-892e-43cd-ae9c-994a2606ede7', 'Longhorn charts: Food Eaten At Home [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315274', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('3268553e-543c-4fee-a235-aa131fe799af', 'Longhorn charts: Family Members [Approved]', 'Wall Charts', '9789966315267', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('4c0d644e-a877-4624-a54a-2a53a7582fdd', 'Longhorn charts: Family Members [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315267', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('a1bcbbd9-c11d-4291-96f0-614a69ff925f', 'Longhorn charts: Clothes Worn By Family Members [Approved]', 'Wall Charts', '9789966315236', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('cc226b29-0d6b-4a9c-9a99-95b1f2128ab9', 'Longhorn charts: Clothes Worn By Family Members [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315236', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('2330f0bf-a563-4e76-974f-0c9872af297a', 'Longhorn charts: Utensils Use At Home [Approved]', 'Wall Charts', '9789966315380', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('8e62e6f1-ce73-4e5d-9a06-68a126b933d8', 'Longhorn charts: Utensils Use At Home [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315380', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('c3731399-a271-4d66-aad9-bc8c3b980837', 'Longhorn charts: Means Of Transport [Approved]', 'Wall Charts', '9789966315328', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('b0cfd845-2bc0-4345-8251-bf368c68a1dd', 'Longhorn charts: Means Of Transport [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315328', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('78996551-8da1-4670-a02f-5f339d1b3e7d', 'Longhorn charts: Fruits We Eat [Approved]', 'Wall Charts', '9789966315298', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('ffe471db-e3ba-4f54-8429-cc8923e08b7e', 'Longhorn charts: Fruits We Eat [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315298', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('9f9364de-88e2-482b-92d2-088b5e43f490', 'Longhorn charts: Fruit Trees [Approved]', 'Wall Charts', '9789966315281', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('43414ca0-85d2-4306-8e32-631dd22d3528', 'Longhorn charts: Fruit Trees [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315281', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('a27c2a71-f4de-4fa5-9426-2ecd5103f2cd', 'Longhorn charts: Domestic Animals [Approved]', 'Wall Charts', '9789966315250', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('24ce4db8-9701-4c6e-ad57-3095466d732b', 'Longhorn charts: Domestic Animals [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315250', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('fd255863-69cf-4e1b-909b-3aa560ee6b18', 'Longhorn charts: Weather [Approved]', 'Wall Charts', '9789966315397', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('4fcf987d-fa2f-435d-8588-0e8c7603ffb9', 'Longhorn charts: Weather [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315397', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('612598bd-f92d-4e3c-a243-1a0f974d43b4', 'Longhorn charts: Wild Animals [Approved]', 'Wall Charts', '9789966315403', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('ed81e3d2-34e9-4663-b006-441e84a6738f', 'Longhorn charts: Wild Animals [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315403', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('57668f56-f5d6-40ee-a3b8-14ec7351b258', 'Longhorn charts: Colours [Approved]', 'Wall Charts', '9789966315243', 'sale', 325.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('aec46e28-e700-4dd1-a12a-1b9a2f573555', 'Longhorn charts: Colours [Approved] (Sample)', 'Wall Charts', 'SMPL-9789966315243', 'sample', 325.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('227bfcec-0547-44e6-8c90-8de91247bd6d', 'Balaam and the Donkey', 'General', '9789966314383', 'sale', 267.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('9e0a31f0-9597-46e8-b621-09579dbcfb99', 'Balaam and the Donkey (Sample)', 'General', 'SMPL-9789966314383', 'sample', 267.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true),
('ddd9785a-07ac-469e-9b5d-96f731b4e90c', 'Battle of Jericho', 'General', '9789966314390', 'sale', 267.0, 100, 'Longhorn Publisher Book', true, '11111111-1111-1111-1111-111111111111', true),
('94b4d1bd-579b-49b2-9357-67a937a5f45c', 'Battle of Jericho (Sample)', 'General', 'SMPL-9789966314390', 'sample', 267.0, 50, 'Sample for distribution', true, '11111111-1111-1111-1111-111111111111', true)
ON CONFLICT (sku) DO NOTHING;
