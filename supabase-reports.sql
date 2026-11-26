create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  report_ref text default ('SL-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  category text not null check (
    category in ('waste', 'streetlight', 'drainage', 'green_space', 'other')
  ),
  urgency text not null default 'medium' check (
    urgency in ('low', 'medium', 'high')
  ),
  description text not null default '' check (char_length(description) <= 300),
  location_label text not null check (char_length(location_label) between 1 and 200),
  contact_whatsapp text,
  admin_note text,
  resolved_photo_url text,
  latitude double precision,
  longitude double precision,
  photo_path text not null unique,
  status text not null default 'pending_verification',
  created_at timestamptz not null default now(),
  constraint reports_coordinates_valid check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180)
  ),
  constraint reports_photo_in_owner_folder check (
    (user_id is not null and split_part(photo_path, '/', 1) = user_id::text)
    or (user_id is null and split_part(photo_path, '/', 1) = 'guest')
  )
);

alter table public.reports alter column user_id drop not null;
alter table public.reports add column if not exists report_ref text;
alter table public.reports alter column report_ref set default
  ('SL-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)));
alter table public.reports add column if not exists status text not null default 'pending_verification';
alter table public.reports add column if not exists contact_whatsapp text;
alter table public.reports add column if not exists admin_note text;
alter table public.reports add column if not exists resolved_photo_url text;

update public.reports
set report_ref = 'SL-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
where report_ref is null;

alter table public.reports alter column report_ref set not null;
alter table public.reports drop constraint if exists reports_report_ref_format;
alter table public.reports add constraint reports_report_ref_format
check (report_ref ~ '^SL-[A-Z0-9]{12}$');
create unique index if not exists reports_report_ref_unique_idx
on public.reports(report_ref);

alter table public.reports drop constraint if exists reports_status_check;
alter table public.reports drop constraint if exists reports_status_allowed;
alter table public.reports add constraint reports_status_allowed
check (status in ('pending_verification', 'reviewing', 'handled', 'rejected'));

alter table public.reports drop constraint if exists reports_photo_in_owner_folder;
alter table public.reports add constraint reports_photo_in_owner_folder check (
  (user_id is not null and split_part(photo_path, '/', 1) = user_id::text)
  or (user_id is null and split_part(photo_path, '/', 1) = 'guest')
);
alter table public.reports drop constraint if exists reports_contact_whatsapp_length;
alter table public.reports add constraint reports_contact_whatsapp_length check (
  contact_whatsapp is null or char_length(contact_whatsapp) <= 30
);
alter table public.reports drop constraint if exists reports_admin_note_length;
alter table public.reports add constraint reports_admin_note_length
check (admin_note is null or char_length(admin_note) <= 2000);

create table if not exists public.report_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.report_admins enable row level security;
revoke all on public.report_admins from anon, authenticated;
drop policy if exists "Users can check own report admin status" on public.report_admins;
create policy "Users can check own report admin status"
on public.report_admins for select to authenticated
using ((select auth.uid()) = user_id);
grant select (user_id) on public.report_admins to authenticated;

create or replace function public.is_report_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.report_admins
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_report_admin() from public, anon, authenticated;
grant execute on function public.is_report_admin() to authenticated;

alter table public.reports enable row level security;
drop policy if exists "Users can read own reports" on public.reports;
drop policy if exists "Users can create own reports" on public.reports;
drop policy if exists "Guests can create reports" on public.reports;
drop policy if exists "Admins can read reports" on public.reports;
drop policy if exists "Admins can update reports" on public.reports;

create policy "Guests can create reports"
on public.reports for insert to anon
with check (
  user_id is null
  and split_part(photo_path, '/', 1) = 'guest'
);

create policy "Admins can read reports"
on public.reports for select to authenticated
using ((select public.is_report_admin()));

create policy "Admins can update reports"
on public.reports for update to authenticated
using ((select public.is_report_admin()))
with check ((select public.is_report_admin()));

revoke all on public.reports from anon, authenticated;
grant insert (
  id,
  user_id,
  report_ref,
  category,
  urgency,
  description,
  location_label,
  contact_whatsapp,
  latitude,
  longitude,
  photo_path
) on public.reports to anon;
grant select, update on public.reports to authenticated;

create or replace function public.lookup_report_by_reference(p_reference text)
returns table (
  report_ref text,
  category text,
  location_label text,
  status text,
  created_at timestamptz,
  admin_note text,
  resolved_photo_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    report.report_ref,
    report.category,
    report.location_label,
    report.status,
    report.created_at,
    report.admin_note,
    report.resolved_photo_url
  from public.reports as report
  where report.report_ref = pg_catalog.upper(pg_catalog.btrim(p_reference))
  limit 1;
$$;

revoke all on function public.lookup_report_by_reference(text) from public, anon, authenticated;
grant execute on function public.lookup_report_by_reference(text) to anon, authenticated;

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

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'report-resolution-photos',
  'report-resolution-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = true,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can upload report photos to own folder" on storage.objects;
drop policy if exists "Guests can upload report photos" on storage.objects;
create policy "Guests can upload report photos"
on storage.objects for insert to anon
with check (
  bucket_id = 'report-photos'
  and (storage.foldername(name))[1] = 'guest'
);

drop policy if exists "Users can read report photos in own folder" on storage.objects;
drop policy if exists "Admins can read report photos" on storage.objects;
create policy "Admins can read report photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'report-photos'
  and (select public.is_report_admin())
);

drop policy if exists "Users can delete report photos in own folder" on storage.objects;
drop policy if exists "Admins can upload resolution photos" on storage.objects;
create policy "Admins can upload resolution photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'report-resolution-photos'
  and (select public.is_report_admin())
);

drop policy if exists "Admins can delete resolution photos" on storage.objects;
create policy "Admins can delete resolution photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'report-resolution-photos'
  and (select public.is_report_admin())
);
