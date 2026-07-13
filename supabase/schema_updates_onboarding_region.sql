-- Migration: role 1 region dashboard additions + role 5 onboarding field updates
-- Date: 2026-07-09

-- =============================================================================
-- 1. ROLE 5 ONBOARDING: Migrate existing Distributor records to Institution
-- =============================================================================
UPDATE public.schools
SET dealer_type = 'Institution'
WHERE lower(dealer_type) = 'distributor';

UPDATE public.schools
SET shop_category = 'Distributor'
WHERE lower(shop_category) = 'independent';

-- =============================================================================
-- 2. ROLE 5 ONBOARDING: Add new columns for expanded onboarding fields
-- =============================================================================
-- samples_to_be_returned: new Yes/No indicator for sample returns
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS samples_to_be_returned text;

-- learning_materials: multi-select stock for Bookshop / Institution (Course Books, ECD Books, Reference, Teacher Guides)
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS learning_materials jsonb DEFAULT '[]'::jsonb;

-- institution_category_other: free-text subcategory when partner_subtype = 'Others' for Institutions
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS institution_category_other text;

-- book_programs: expanded multi-select for School Book Program (Book List, Book Fund)
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS book_programs jsonb DEFAULT '[]'::jsonb;

-- =============================================================================
-- 3. ROLE 1 REGION SECTION: Index optimization for regional aggregation queries
-- =============================================================================
-- The new admin Regions page aggregates sales, visits, and schools by region.
-- It derives region from users.region or schools.county. Add composite indexes
-- to keep those queries fast as data grows.
CREATE INDEX IF NOT EXISTS idx_schools_county_captured_at
  ON public.schools (county, captured_at);

CREATE INDEX IF NOT EXISTS idx_school_visits_school_visited_at
  ON public.school_visits (school_id, visited_at);

CREATE INDEX IF NOT EXISTS idx_school_sales_school_created
  ON public.school_sales (school_id, created_at);

-- =============================================================================
-- 4. ROLE 5 ONBOARDING: Backfill / cleanup notes
-- =============================================================================
-- Reset free-text fields for fresh onboarding data shape
UPDATE public.schools
SET institution_category_other = NULL
WHERE dealer_type = 'Institution';

-- Ensure nullsafe for new columns on existing rows
UPDATE public.schools
SET samples_to_be_returned = NULL,
    learning_materials = '[]'::jsonb,
    book_programs = '[]'::jsonb
WHERE samples_to_be_returned IS NULL
   OR learning_materials IS NULL
   OR book_programs IS NULL;
