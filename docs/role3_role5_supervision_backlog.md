# Role 3 Supervision Improvements Backlog (Role 5 Oversight)

## Scope
This backlog translates the agreed improvements into implementable work for the current Flutter + Supabase codebase.

## Current Baseline
- UI entry points:
  - `lib/features/admin/admin_dashboard_screen.dart`
  - `lib/features/admin/admin_dashboard_page.dart`
  - `lib/features/admin/admin_geofence_map_screen.dart`
- Data layer:
  - `supabase/schema.sql`
  - `supabase/seed.sql`
- Existing roles in use:
  - Role 3 (BAS / regional supervisor)
  - Role 5 (grounds / field operations)

## Phase 1 (P0): Region-Strict Supervision + Command Center

### 1. Region-scoped access control (backend)
- Add/verify policies so Role 3 can only view/manage Role 5 users and work items in the same region.
- Apply to: `users`, `tasks`, `geofences`, `route_plans`, and any related reporting views.
- Implementation:
  - Extend RLS policies in `supabase/schema.sql` using `current_user_region_from_jwt()`.
  - Ensure `geofences.region` is populated at insert/update.
- Acceptance:
  - Role 3 from `Nairobi` cannot query/update Role 5 records from `Mombasa`.

### 2. Role 3 command center screen (frontend)
- Add a dedicated dashboard section/card for Role 3 supervision.
- Core KPI cards:
  - Active Role 5 today
  - Overdue tasks
  - Geofence breaches
  - Unstarted routes
- Implementation:
  - New widget/page under `lib/features/admin/` (recommended: `role3_supervision_dashboard.dart`).
  - Add navigation entry from `admin_dashboard_screen.dart`.
- Acceptance:
  - KPI values update from live Supabase queries and honor region boundaries.

### 3. County filter as first-class control
- Place county filter at top of Role 3 views and persist selected county during session.
- Implementation:
  - Reuse county list already used in geofence screen.
  - Filter tasks/routes/geofence lists by county.
- Acceptance:
  - Switching county updates all visible supervision widgets consistently.

## Phase 2 (P1): Route + Geofence Governance

### 4. Route approval workflow (Role 3 -> Role 5)
- Add route lifecycle: `draft`, `submitted`, `approved`, `rejected`, `in_progress`, `completed`.
- Role 5 submits; Role 3 approves/rejects with optional note.
- Implementation:
  - DB: add status constraints + review fields in `route_plans` (`reviewed_by`, `reviewed_at`, `review_note`).
  - UI: action buttons in Role 3 route list.
- Acceptance:
  - Role 5 cannot mark route `in_progress` unless approved.

### 5. Geofence exception handling
- If Role 5 works outside assigned geofence, require reason and capture event.
- Implementation:
  - DB table: `geofence_events` with `event_type`, `user_id`, `region`, `lat`, `lng`, `reason`, `created_at`.
  - Role 3 UI list for unresolved exceptions.
- Acceptance:
  - Out-of-boundary event creates record; supervisor can mark resolved.

### 6. Real-time operational alerts
- Add near-real-time queue for:
  - missed check-in
  - boundary breach
  - overdue tasks
- Implementation:
  - Supabase Realtime subscription in Role 3 dashboard.
  - Alert badges + priority ordering.
- Acceptance:
  - New breach appears without app restart.

## Phase 3 (P1): Performance, Coaching, and SLA Tracking

### 7. Role 5 performance scorecard
- Weekly/monthly composite score from:
  - task completion rate
  - geofence compliance
  - on-time check-ins
  - data completeness
- Implementation:
  - Add SQL view/materialized view for aggregated metrics per Role 5 user.
  - Render sortable table + trend badges for Role 3.
- Acceptance:
  - Role 3 can rank their Role 5 users by period and county.

### 8. Coaching notes and follow-ups
- Role 3 can add coaching note tied to a user + incident/task.
- Implementation:
  - DB table: `supervisor_notes` (`supervisor_id`, `user_id`, `region`, `context_type`, `context_id`, `note`, `follow_up_at`).
  - UI: quick-add note modal in user detail card.
- Acceptance:
  - Notes are searchable by user and appear in timeline order.

### 9. Supervisor SLA metrics
- Track Role 3 response/resolve times for red alerts.
- Implementation:
  - Add timestamps on alert creation/acknowledge/resolve.
  - KPI tiles for `ack < 15min` and `resolve < 2h` compliance.
- Acceptance:
  - SLA compliance percentage visible and exportable.

## Phase 4 (P2): Exports, Audit, and Hardening

### 10. Regional report export
- Export county or region supervision summary to CSV/PDF.
- Implementation:
  - Build SQL query endpoint/view for export data.
  - Add export action in Role 3 dashboard.
- Acceptance:
  - Generated file includes KPI summary + user breakdown.

### 11. Audit trail
- Track critical Role 3 actions:
  - reassignment
  - approval/rejection
  - geofence edits
  - overrides
- Implementation:
  - DB table: `audit_events` with actor, action, entity, before/after snapshot.
- Acceptance:
  - Admin can filter audit entries by actor/date/action.

### 12. Data quality guardrails
- Enforce required completion payload for Role 5 tasks:
  - GPS
  - timestamp
  - optional evidence photo by task type
- Implementation:
  - Validation in app before submission.
  - DB constraint/check where applicable.
- Acceptance:
  - Incomplete payload cannot close task.

## Database Change Checklist
- `geofences.region` exists and is indexed.
- Add indexes for common supervisor queries:
  - `tasks(assigned_to, status, due_at)`
  - `users(role, region)`
  - `geofences(region, assigned_to)`
  - `route_plans(assigned_to, route_date, status)`
- Add/refresh RLS policies for Role 3 regional constraints.

## Suggested Delivery Sequence (2-week sprints)
1. Sprint 1: Phase 1 (P0)
2. Sprint 2: Phase 2 items 4-5
3. Sprint 3: Phase 2 item 6 + Phase 3 item 7
4. Sprint 4: Phase 3 items 8-9 + Phase 4 item 10
5. Sprint 5: Phase 4 items 11-12 + hardening

## Definition of Done (overall)
- Role 3 supervision flows are region-safe by policy and UI.
- County selection drives all maps/lists consistently.
- Route/geofence exceptions are actionable and auditable.
- Performance and SLA reporting is visible without manual SQL.
