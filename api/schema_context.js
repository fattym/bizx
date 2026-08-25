const SCHEMA_CONTEXT = `
DeHeus Sales Application Database Schema:

ROLES (users.role):
1 = Admin, 2 = Sales Manager, 3 = BAS (Business Advisor Supervisor), 4 = Agent, 5 = Grounds Person/Sales Rep

CORE TABLES:

users (auth users linked via auth.users(id)):
- id (uuid PK), email, full_name, phone, role (1-5), region (text), sub_region (text), region_id (FK to regions), isSynced
- Role 1 = full access, Role 2 = sales manager oversight, Role 3 = regional supervisor, Role 4 = agent, Role 5 = field sales rep

regions:
- id (uuid PK), region (text: Nairobi North, Lake, South Rift, North Rift, Coast, Mt Kenya, National), sub_region (text), counties (text), assigned_to (FK users), supervisor_id (FK users)

schools (CRM - institutions):
- id (uuid PK), name, phone, county, source ('manual'|'google'), focusAreas (jsonb), book_category, dealer_type, shop_category
- latitude, longitude, lead_score (0-100 auto-calculated), school_level, designation, projected_quantity
- contact_name, contact_phone, contact_email, feedback, notes
- captured_by (FK users), capture_status, photo_url
- school_ownership, school_population, school_lifecycle_status, engagement_type
- sample_proof_url, samples_left, sample_books
- competitor_analysis, learning_materials (jsonb), book_programs (jsonb)
- region_id (FK regions), isSynced

tasks (assignments):
- id (uuid PK), title, description, target_role (default 2), due_at, status ('open'|'in_progress'|'closed')
- created_by (FK auth.users), assigned_to (FK users), isSynced
- Role 5 tasks require GPS evidence (task_completion_evidence) to close

geofences (geographic zones):
- id (uuid PK), name, description, region, coordinates (jsonb: polygon or point with radius)
- assigned_to (FK users), created_by (FK auth.users)

route_plans (daily/weekly routes):
- id (uuid PK), title, route_date (date), assigned_to (FK users), school_ids (jsonb array)
- status: 'draft'|'submitted'|'approved'|'rejected'|'assigned'|'in_progress'|'completed'
- notes, reviewed_by (FK users), reviewed_at, review_note, isSynced
- Role 5 can only update their own routes to 'submitted', 'in_progress', 'completed'

SALES PIPELINE:

school_sales (CRM opportunities):
- id (uuid PK), school_id (FK schools), agent_id (FK users), package_name, expected_value (numeric)
- sale_status: 'lead'|'contacted'|'meeting_scheduled'|'sample_issued'|'quotation_sent'|'decision_pending'|'negotiation'|'won'|'lost'|'dormant'
- probability (0-100), weighted_forecast (auto: expected_value * probability / 100)
- stage_contact_person, sample_quantity, quotation_reference, decision_owner
- negotiation_topic, loss_reason, dormant_reason
- next_action (auto: 'Follow up call' + 2 days if blank), next_action_date
- expected_close_date, forecast_category, risk_level ('low'|'medium'|'high' auto)
- stage_sla_due_at (3/5/7 days depending on stage), last_activity_at
- region_id (FK regions), isSynced

opportunity_activities (activity log):
- id (uuid PK), opportunity_id (FK school_sales), school_id (FK schools), actor_id (FK users)
- activity_type ('Call'|'Meeting'|...), activity_outcome, notes, next_action, next_action_date
- Auto-syncs to parent school_sales on insert

pipeline_history (stage change audit):
- id (uuid PK), pipeline_id (FK school_sales), old_stage, new_stage, changed_by (FK users), changed_at, notes

orders (checkout/sales):
- id (uuid PK), school_id (FK schools), school_name (denormalized), school_phone
- agent_id (FK users), order_number (unique), payment_method ('cash'|'mpesa'|'bank_transfer')
- payment_reference, checkout_amount, status ('pending'|'approved'|'paid'|'completed')
- notes, submitted_at, approved_at, region_id (FK regions), isSynced

order_items:
- id (uuid PK), order_id (FK orders), product_name, category, sku, quantity, unit_price, line_total, notes, isSynced

SAMPLES & VISITS:

school_visits:
- id (uuid PK), school_id (FK schools), agent_id (FK users), outcome, notes
- photo_url, latitude, longitude, visit_status, visited_at, isSynced

school_follow_ups:
- id (uuid PK), school_id (FK schools), agent_id (FK users), contact_person, next_step
- due_at, notes, follow_up_status ('open'|'completed'), completed_at, isSynced

school_sample_distributions:
- id (uuid PK), school_id (FK schools), agent_id (FK users), sample_name, sample_category
- client_type, quantity, returned_qty, stamped_receipt_url, notes, distributed_at, isSynced

sample_requests:
- id (uuid PK), request_code (unique), school_id (FK schools), client_type, requested_by (FK users)
- purpose, notes, status ('PENDING'|'APPROVED'|'REJECTED'), rejection_reason
- needed_by, requested_at, reviewed_at, reviewed_by (FK users), items (jsonb), isSynced

task_completion_evidence:
- id (uuid PK), task_id (FK tasks), submitted_by (FK users)
- gps_lat, gps_lng, proof_url, proof_type, created_at

CATALOG:

catalog_items:
- id (uuid PK), name, category, sku (unique), item_type ('sale'|'sample')
- unit_price, stock_qty, description, is_active, isSynced
- created_by (FK auth.users)

EVENTS:

events:
- id (uuid PK), name, event_type, organization, venue, region, subregion
- start_at, end_at, expected_attendance, budget, objectives, products (jsonb), notes
- status ('scheduled'|'ongoing'|'completed'|'cancelled'), created_by (FK auth.users), isSynced

event_assignments:
- id (uuid PK), event_id (FK events), agent_id (FK users), assigned_by (FK auth.users)
- schedule (jsonb), products (jsonb), samples (jsonb), marketing_materials (jsonb), targets (jsonb), notes

event_checkins:
- id (uuid PK), event_id (FK events), agent_id (FK users), checkin_at, gps_lat, gps_lng
- geofence_verified, qr_verified, selfie_url, checkin_type ('checkin'|'checkout'), location_text, notes

event_tasks:
- id (uuid PK), event_id (FK events), title, description, required, completed, completed_by (FK users), completed_at, evidence_url, sort_order

event_leads:
- id (uuid PK), event_id (FK events), agent_id (FK users), lead_name, school_id (FK schools)
- phone, email, interested_products (jsonb), purchase_timeline, notes

event_samples:
- id (uuid PK), event_id (FK events), product_id (FK catalog_items), quantity, recipient
- recipient_signature, distributed_by (FK users), distributed_at, notes

event_expenses:
- id (uuid PK), event_id (FK events), submitted_by (FK users), expense_type, amount, currency ('KES')
- receipt_url, status ('pending'|'approved'|'rejected'), approved_by (FK users), approved_at, notes

event_reports:
- id (uuid PK), event_id (FK events), created_by (FK users), summary
- attendance_count, visitors_count, schools_count, qualified_leads_count, orders_count, revenue
- products_sold (jsonb), expenses_summary (jsonb), challenges, recommendations

SUPERVISOR & MONITORING:

supervisor_alerts:
- id (uuid PK), user_id (FK users), region, alert_type ('missed_checkin'|'late_start'|'overdue_followup')
- severity ('amber'|'red'), status ('open'|'acked'|'resolved'), message
- acked_at, resolved_at, ack_sla_met, resolve_sla_met, escalated_to_admin, created_at
- SLA: red alerts must be acked within 15 min, unresolved red alerts escalate after 2 hours

supervisor_incidents:
- id (uuid PK), user_id (FK users), region, incident_type, severity, status, notes, created_by, created_at, updated_at

supervisor_notes:
- id (uuid PK), supervisor_id (FK users), user_id (FK users), region, context_type, context_id, note, follow_up_at, created_at

supervisor_notifications:
- id (uuid PK), supervisor_id (FK users), region, notification_type ('daily_digest'|'evening_summary'|'escalation')
- title, body, payload (jsonb), scheduled_for, sent_at, read_at, created_at

audit_events:
- id (uuid PK), actor_id (FK users), action, entity_type, entity_id, region
- before_data (jsonb), after_data (jsonb), created_at

SOCIAL INBOX:

social_conversations:
- id (uuid PK), channel ('facebook'|'whatsapp'), external_conversation_id (unique)
- participant_display, participant_phone, last_message_preview, last_message_at, raw_payload (jsonb)

social_messages:
- id (uuid PK), conversation_id (FK social_conversations), channel, external_message_id (unique)
- sender_name, sender_id, body, sent_at, raw_payload (jsonb)

PROJECT FORMS:

project_forms:
- id (uuid PK), title, description, questions (jsonb), assigned_user_ids (uuid array)
- published_at, created_by (FK users), created_at

project_form_responses:
- id (uuid PK), form_id (FK project_forms), form_title, respondent_id (FK users)
- answers (jsonb), submitted_at, created_at

targets:
- id (uuid PK), scope ('regional'|'agent'|'business_advisor'|'sales_rep')
- region_id (FK regions), sub_region, assigned_to (FK users)
- target_type ('product_sales'|'customer_visits'|'collections'|'new_customers'|'sample_distribution'|'consignment')
- target_period ('daily'|'weekly'|'monthly'|'quarterly'|'yearly'|'ytd')
- target_data (jsonb), created_at, updated_at

KEY BUSINESS RULES:
- Users authenticate via Supabase Auth, profile synced to public.users via trigger
- Role 5 (field agents) must provide GPS + photo evidence to close tasks
- School lead_score auto-calculated from population, book_category, focusAreas
- School sales weighted_forecast = expected_value * probability / 100
- School sales SLA: lead/contacted=3 days, meeting/sample=5 days, quotation/negotiation=7 days
- Risk level: high if next_action missing or overdue, medium if due tomorrow, low if won/lost
- Route plans: Role 5 can only submit/in_progress/complete their own routes
- Daily digests at 07:00-07:10, evening summaries at 18:00-18:10 for Role 3 supervisors
- Orders created atomically with order_items and school_sales via RPC create_school_sale_checkout()
`;

const DB_SCHEMA_PROMPT = `You are an AI assistant for the DeHeus sales application. You have complete knowledge of the database schema and business logic below. Use this knowledge to answer questions accurately.

${SCHEMA_CONTEXT}

When answering:
- Reference exact table and column names when relevant
- Explain relationships between entities
- Describe business rules and validation logic
- Suggest appropriate queries or data to look at for specific questions
- Be specific about role-based access and data visibility
- If asked about data, describe what tables/columns contain that information`;

module.exports = { SCHEMA_CONTEXT, DB_SCHEMA_PROMPT };
