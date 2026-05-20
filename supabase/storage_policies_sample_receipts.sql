-- Enable storage for stamped sample receipt photos
-- Run in Supabase SQL editor as a project admin.

begin;

-- 1) Ensure bucket exists (public for easy admin viewing via public URL)
insert into storage.buckets (id, name, public)
values ('schools', 'schools', true)
on conflict (id) do update set public = true;

-- Optional dedicated bucket (if you later switch app upload target)
insert into storage.buckets (id, name, public)
values ('sample-receipts', 'sample-receipts', true)
on conflict (id) do update set public = true;

-- 2) Policies for 'schools' bucket
drop policy if exists "authenticated_can_view_schools_bucket" on storage.objects;
create policy "authenticated_can_view_schools_bucket"
on storage.objects
for select
to authenticated
using (bucket_id = 'schools');

drop policy if exists "authenticated_can_upload_schools_bucket" on storage.objects;
create policy "authenticated_can_upload_schools_bucket"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'schools');

drop policy if exists "authenticated_can_update_schools_bucket" on storage.objects;
create policy "authenticated_can_update_schools_bucket"
on storage.objects
for update
to authenticated
using (bucket_id = 'schools')
with check (bucket_id = 'schools');

-- 3) Policies for dedicated 'sample-receipts' bucket
drop policy if exists "authenticated_can_view_sample_receipts_bucket" on storage.objects;
create policy "authenticated_can_view_sample_receipts_bucket"
on storage.objects
for select
to authenticated
using (bucket_id = 'sample-receipts');

drop policy if exists "authenticated_can_upload_sample_receipts_bucket" on storage.objects;
create policy "authenticated_can_upload_sample_receipts_bucket"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'sample-receipts');

drop policy if exists "authenticated_can_update_sample_receipts_bucket" on storage.objects;
create policy "authenticated_can_update_sample_receipts_bucket"
on storage.objects
for update
to authenticated
using (bucket_id = 'sample-receipts')
with check (bucket_id = 'sample-receipts');

commit;
