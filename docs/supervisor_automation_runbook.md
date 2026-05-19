# Supervisor Automation Runbook

## Purpose
Schedules automated escalation and digest generation for Role 3 supervision.

## Prerequisites
- `supabase/schema.sql` has been applied.
- `pg_cron` extension is enabled in your Postgres project.

## Functions
- `public.process_supervisor_alert_sla()`
- `public.queue_supervisor_daily_digests()`

## Recommended schedules
```sql
-- Every 5 minutes: process red-alert SLA and escalations
select cron.schedule(
  'process-supervisor-alert-sla',
  '*/5 * * * *',
  $$select public.process_supervisor_alert_sla();$$
);

-- Every 15 minutes: generate overdue follow-up alerts from CRM opportunities
select cron.schedule(
  'generate-overdue-followup-alerts',
  '*/15 * * * *',
  $$select public.generate_overdue_followup_alerts();$$
);

-- Every 10 minutes: queue 7:00 AM and 6:00 PM digest windows
select cron.schedule(
  'queue-supervisor-digests',
  '*/10 * * * *',
  $$select public.queue_supervisor_daily_digests();$$
);
```

## Manual test
```sql
select public.process_supervisor_alert_sla();
select public.queue_supervisor_daily_digests();
```

## Verify output
- `public.supervisor_notifications`
- `public.supervisor_alerts.escalated_to_admin`
