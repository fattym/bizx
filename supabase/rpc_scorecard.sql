-- RPC to fetch dynamic Role 5 Performance Scorecard data based on a date range
CREATE OR REPLACE FUNCTION public.get_role5_performance(p_start_date TIMESTAMPTZ, p_end_date TIMESTAMPTZ)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    region TEXT,
    total_tasks BIGINT,
    completed_tasks BIGINT,
    total_routes BIGINT,
    completed_routes BIGINT,
    total_visits BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id AS user_id,
        u.full_name,
        u.region,
        COUNT(DISTINCT t.id) AS total_tasks,
        COUNT(DISTINCT CASE WHEN t.status = 'closed' THEN t.id END) AS completed_tasks,
        COUNT(DISTINCT r.id) AS total_routes,
        COUNT(DISTINCT CASE WHEN r.status = 'completed' THEN r.id END) AS completed_routes,
        COUNT(DISTINCT sv.id) AS total_visits
    FROM public.users u
    LEFT JOIN public.tasks t ON t.assigned_to = u.id AND t.created_at >= p_start_date AND t.created_at <= p_end_date
    LEFT JOIN public.route_plans r ON r.assigned_to = u.id AND r.created_at >= p_start_date AND r.created_at <= p_end_date
    LEFT JOIN public.school_visits sv ON sv.agent_id = u.id AND sv.visited_at >= p_start_date AND sv.visited_at <= p_end_date
    WHERE u.role = 5
    GROUP BY u.id, u.full_name, u.region;
END;
$$;