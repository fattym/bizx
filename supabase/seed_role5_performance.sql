-- Seed script to populate Role 5 Performance Scorecard data
-- This script will find existing Role 5 users and assign them some tasks, route plans, and school visits.

DO $$
DECLARE
  v_user_id UUID;
  v_school_id UUID;
  v_user_count INT := 0;
BEGIN
  -- We need a school ID to log visits against.
  SELECT id INTO v_school_id FROM public.schools LIMIT 1;

  -- Loop through up to 3 existing Role 5 users
  FOR v_user_id IN (SELECT id FROM public.users WHERE role = 5 LIMIT 3) LOOP
    v_user_count := v_user_count + 1;

    -- 1. Insert Tasks (Mix of closed, open, and in_progress)
    INSERT INTO public.tasks (assigned_to, title, description, status, due_at, target_role, created_at)
    VALUES 
      (v_user_id, 'Follow up with ' || v_user_count || ' priority schools', 'Call headteachers to confirm orders.', 'closed', now() - interval '2 days', 5, now() - interval '10 days'),
      (v_user_id, 'Deliver Book Samples', 'Deliver new syllabus samples.', 'in_progress', now() + interval '1 day', 5, now() - interval '2 days'),
      (v_user_id, 'Submit Weekly Field Report', 'Submit expense and field report.', 'closed', now() - interval '5 days', 5, now() - interval '15 days'),
      (v_user_id, 'Review Geofence Compliance', 'Review exceptions with supervisor.', 'open', now() - interval '1 day', 5, now() - interval '4 days');
      
    -- 2. Insert Route Plans (Mix of completed, approved, and assigned)
    INSERT INTO public.route_plans (assigned_to, route_date, status, title, created_at)
    VALUES 
      (v_user_id, current_date - 2, 'completed', 'Route Plan - ' || to_char(current_date - 2, 'YYYY-MM-DD'), now() - interval '3 days'),
      (v_user_id, current_date - 1, 'completed', 'Route Plan - ' || to_char(current_date - 1, 'YYYY-MM-DD'), now() - interval '2 days'),
      (v_user_id, current_date, 'assigned', 'Route Plan - ' || to_char(current_date, 'YYYY-MM-DD'), now() - interval '1 day'),
      (v_user_id, current_date + 1, 'approved', 'Route Plan - ' || to_char(current_date + 1, 'YYYY-MM-DD'), now() - interval '12 hours');
      
    -- 3. Insert School Visits (If we found a school)
    IF v_school_id IS NOT NULL THEN
      INSERT INTO public.school_visits (school_id, agent_id, outcome, notes, visited_at)
      VALUES 
        (v_school_id, v_user_id, 'Met with principal', 'Discussed new curriculum rollout', now() - interval '1 day'),
        (v_school_id, v_user_id, 'Dropped samples', 'Left 5 books for review', now() - interval '3 days');
        
      -- Add a 3rd visit for the first user to give them a slightly higher score
      IF v_user_count = 1 THEN
         INSERT INTO public.school_visits (school_id, agent_id, outcome, notes, visited_at)
         VALUES (v_school_id, v_user_id, 'Follow up', 'Checking on order status', now() - interval '5 days');
      END IF;
    END IF;
  END LOOP;

  -- Optional: If no Role 5 users exist, we could create dummy users, but since the system relies on auth.users, 
  -- it is safer to only attach data to existing users created via the UI.
END;
$$;