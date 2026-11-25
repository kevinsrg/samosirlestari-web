create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (
    category in ('waste', 'streetlight', 'drainage', 'green_space', 'other')
  ),
  urgency text not null default 'medium' check (
    urgency in ('low', 'medium', 'high')
  ),
  description text not null default '' check (char_length(description) <= 300),
  location_label text not null check (char_length(location_label) between 1 and 200),
  latitude double precision,
  longitude double precision,
  photo_path text not null unique,
  status text not null default 'pending_verification' check (
    status in ('pending_verification', 'reviewing', 'handled', 'rejected')
  ),
  created_at timestamptz not null default now(),
  constraint reports_coordinates_valid check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180)
  ),
  constraint reports_photo_in_owner_folder check (
    split_part(photo_path, '/', 1) = user_id::text
  )
);

alter table public.reports enable row level security;

drop policy if exists "Users can read own reports" on public.reports;
create policy "Users can read own reports"
on public.reports for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can create own reports" on public.reports;
create policy "Users can create own reports"
on public.reports for insert to authenticated
with check ((select auth.uid()) = user_id);

revoke all on public.reports from anon, authenticated;
grant select, insert on public.reports to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'report-photos',
  'report-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can upload report photos to own folder" on storage.objects;
create policy "Users can upload report photos to own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'report-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can read report photos in own folder" on storage.objects;
create policy "Users can read report photos in own folder"
on storage.objects for select to authenticated
using (
  bucket_id = 'report-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can delete report photos in own folder" on storage.objects;
create policy "Users can delete report photos in own folder"
on storage.objects for delete to authenticated
using (
  bucket_id = 'report-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
