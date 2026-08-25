-- Schema updates for Event Planning features

-- 1. Update events table
ALTER TABLE events
ADD COLUMN IF NOT EXISTS event_type text,
ADD COLUMN IF NOT EXISTS school_id uuid, -- Reference to schools table if it exists
ADD COLUMN IF NOT EXISTS expected_attendance integer,
ADD COLUMN IF NOT EXISTS budget numeric(10,2),
ADD COLUMN IF NOT EXISTS objectives text,
ADD COLUMN IF NOT EXISTS products_promoted text;

-- 2. Update event_assignments table
ALTER TABLE event_assignments
ADD COLUMN IF NOT EXISTS target_leads integer,
ADD COLUMN IF NOT EXISTS target_orders integer,
ADD COLUMN IF NOT EXISTS products_to_carry text,
ADD COLUMN IF NOT EXISTS samples_allocated text;

-- 3. Update event_checkins table
ALTER TABLE event_checkins
ADD COLUMN IF NOT EXISTS latitude numeric(10,6),
ADD COLUMN IF NOT EXISTS longitude numeric(10,6),
ADD COLUMN IF NOT EXISTS selfie_url text,
ADD COLUMN IF NOT EXISTS checkout_at timestamptz;

-- 4. Create event_leads table if it doesn't exist
CREATE TABLE IF NOT EXISTS event_leads (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid REFERENCES events(id) ON DELETE CASCADE,
    agent_id uuid,
    name text NOT NULL,
    school_name text,
    phone text,
    email text,
    interested_products text,
    purchase_timeline text,
    notes text,
    created_at timestamptz DEFAULT now()
);

-- 5. Create event_samples table for sample distribution
CREATE TABLE IF NOT EXISTS event_samples (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id uuid REFERENCES events(id) ON DELETE CASCADE,
    agent_id uuid,
    product_name text NOT NULL,
    quantity integer NOT NULL,
    recipient_name text,
    signature_url text,
    created_at timestamptz DEFAULT now()
);

-- 6. Update event_photos table
ALTER TABLE event_photos
ADD COLUMN IF NOT EXISTS agent_id uuid,
ADD COLUMN IF NOT EXISTS category text;

-- 7. Update event_expenses table
ALTER TABLE event_expenses
ADD COLUMN IF NOT EXISTS category text,
ADD COLUMN IF NOT EXISTS amount numeric(10,2),
ADD COLUMN IF NOT EXISTS status text DEFAULT 'Pending';

-- 8. Add tasks template functionality if needed (optional)
-- CREATE TABLE IF NOT EXISTS event_task_templates (...)

-- Ensure existing event_leads table has the new columns
ALTER TABLE event_leads 
ADD COLUMN IF NOT EXISTS school_name text,
ADD COLUMN IF NOT EXISTS email text,
ADD COLUMN IF NOT EXISTS interested_products text,
ADD COLUMN IF NOT EXISTS purchase_timeline text,
ADD COLUMN IF NOT EXISTS notes text;
