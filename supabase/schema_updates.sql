-- Updates for newly added Dashboard, Analytics, Geofencing, and Assignment features

-- 0. Update Tasks Table for Individual Assignment and Time Filtering
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS due_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS target_role INTEGER NOT NULL DEFAULT 2;

-- 0b. Schools table updates for onboarding tracking + external discovery
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS external_place_id TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS external_vicinity TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_name TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS contact_title TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS feedback TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS samples_left TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS sample_book TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_ownership TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_ownership_other TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_population INTEGER;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS school_lifecycle_status TEXT;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS engagement_type TEXT;
ALTER TABLE public.school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_url TEXT;
ALTER TABLE public.school_sample_distributions ADD COLUMN IF NOT EXISTS stamped_receipt_path TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_schools_external_place_id
ON public.schools (external_place_id)
WHERE external_place_id IS NOT NULL;

DO $$ BEGIN
    ALTER TABLE public.schools
    DROP CONSTRAINT IF EXISTS schools_source_check;
    ALTER TABLE public.schools
    ADD CONSTRAINT schools_source_check CHECK (source IN ('manual', 'google'));
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- 1. Route Plans Table
CREATE TABLE IF NOT EXISTS public.route_plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL DEFAULT 'Route Plan',
    route_date DATE NOT NULL DEFAULT CURRENT_DATE,
    assigned_to UUID REFERENCES public.users(id) ON DELETE CASCADE,
    school_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'assigned',
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Geofences Table
CREATE TABLE IF NOT EXISTS public.geofences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    coordinates JSONB NOT NULL DEFAULT '[]'::jsonb,
    assigned_to UUID REFERENCES public.users(id) ON DELETE CASCADE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. School Sample Distributions Table
CREATE TABLE IF NOT EXISTS public.school_sample_distributions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    agent_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    sample_name TEXT NOT NULL,
    sample_category TEXT,
    quantity INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    distributed_at TIMESTAMP WITH TIME ZONE,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3b. Debt Collections Table
CREATE TABLE IF NOT EXISTS public.debt_collections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    collected_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_reference TEXT,
    notes TEXT,
    collected_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. Catalog Items Table
CREATE TABLE IF NOT EXISTS public.catalog_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT,
    sku TEXT UNIQUE,
    item_type TEXT NOT NULL DEFAULT 'sale',
    unit_price NUMERIC(12,2) NOT NULL DEFAULT 0,
    stock_qty INTEGER NOT NULL DEFAULT 0,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Orders Table (For Revenue Analytics)
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL,
    school_name TEXT NOT NULL,
    school_phone TEXT,
    agent_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    order_number TEXT UNIQUE,
    payment_method TEXT NOT NULL DEFAULT 'cash',
    payment_reference TEXT,
    checkout_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending',
    notes TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    "isSynced" BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. School Sales Pipeline migrations
-- Source of truth schema lives in schema.sql; keep only ALTER/DO migrations here.

DO $$ BEGIN
    ALTER TABLE public.school_sales
        ADD COLUMN IF NOT EXISTS stage_contact_person TEXT,
        ADD COLUMN IF NOT EXISTS sample_quantity INTEGER,
        ADD COLUMN IF NOT EXISTS quotation_reference TEXT,
        ADD COLUMN IF NOT EXISTS decision_owner TEXT,
        ADD COLUMN IF NOT EXISTS negotiation_topic TEXT,
        ADD COLUMN IF NOT EXISTS loss_reason TEXT,
        ADD COLUMN IF NOT EXISTS dormant_reason TEXT,
        ADD COLUMN IF NOT EXISTS stage_updated_at TIMESTAMP WITH TIME ZONE,
        ADD COLUMN IF NOT EXISTS expected_close_date DATE,
        ADD COLUMN IF NOT EXISTS probability INTEGER NOT NULL DEFAULT 0;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.pipeline_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pipeline_id UUID NOT NULL REFERENCES public.school_sales(id) ON DELETE CASCADE,
    old_stage TEXT,
    new_stage TEXT NOT NULL,
    changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc'::text, now()),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_pipeline_id
ON public.pipeline_history (pipeline_id);

CREATE INDEX IF NOT EXISTS idx_pipeline_history_changed_at
ON public.pipeline_history (changed_at DESC);

CREATE OR REPLACE FUNCTION public.log_pipeline_stage_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, NULL, NEW.sale_status, auth.uid(), NEW.notes);
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND coalesce(NEW.sale_status, '') <> coalesce(OLD.sale_status, '') THEN
        INSERT INTO public.pipeline_history (pipeline_id, old_stage, new_stage, changed_by, notes)
        VALUES (NEW.id, OLD.sale_status, NEW.sale_status, auth.uid(), NEW.notes);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_school_sales_stage_change ON public.school_sales;
CREATE TRIGGER log_school_sales_stage_change
AFTER INSERT OR UPDATE ON public.school_sales
FOR EACH ROW EXECUTE PROCEDURE public.log_pipeline_stage_change();

DO $$ BEGIN
    UPDATE public.school_sales
    SET sale_status = 'lead'
    WHERE sale_status IN ('draft', 'pipeline') OR sale_status IS NULL;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE public.school_sales
    ALTER COLUMN sale_status SET DEFAULT 'lead';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE public.school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sale_status_check;
    ALTER TABLE public.school_sales
    DROP CONSTRAINT IF EXISTS school_sales_sample_quantity_check;
    ALTER TABLE public.school_sales
    ADD CONSTRAINT school_sales_sale_status_check CHECK (
        sale_status IN (
            'lead',
            'contacted',
            'meeting_scheduled',
            'sample_issued',
            'quotation_sent',
            'decision_pending',
            'negotiation',
            'won',
            'lost',
            'dormant'
        )
    );
    ALTER TABLE public.school_sales
    ADD CONSTRAINT school_sales_sample_quantity_check CHECK (
        sample_quantity IS NULL OR sample_quantity >= 0
    );
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Enable Row Level Security (RLS) on all new tables
ALTER TABLE public.route_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.geofences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_sample_distributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pipeline_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_collections ENABLE ROW LEVEL SECURITY;

-- Optional: Re-create missing permissive policies if needed
-- (Your schema.sql handles granular RLS policies already, these act as fallbacks if missing)
DO $$ BEGIN
    CREATE POLICY "Allow authenticated full access on route_plans" ON public.route_plans FOR ALL TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_view_pipeline_history"
    ON public.pipeline_history
    FOR SELECT
    TO authenticated
    USING (
      EXISTS (
        SELECT 1
        FROM public.school_sales s
        WHERE s.id = pipeline_id
          AND (s.agent_id = auth.uid() OR public.is_manager_or_admin())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_delete_messages"
    ON public.messages
    FOR DELETE
    TO authenticated
    USING (
      sender_id = auth.uid()
      OR recipient_id = auth.uid()
      OR public.is_manager_or_admin()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "authenticated_can_manage_debt_collections"
    ON public.debt_collections
    FOR ALL
    TO authenticated
    USING (collected_by = auth.uid() OR public.is_manager_or_admin())
    WITH CHECK (collected_by = auth.uid() OR public.is_manager_or_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
