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

create or replace function public.get_public_report_stats()
returns table (
  total_reports bigint,
  in_progress_reports bigint,
  completed_reports bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    pg_catalog.count(*)::bigint,
    pg_catalog.count(*) filter (where report.status = 'reviewing')::bigint,
    pg_catalog.count(*) filter (where report.status = 'handled')::bigint
  from public.reports as report;
$$;

revoke all on function public.get_public_report_stats() from public, anon, authenticated;
grant execute on function public.get_public_report_stats() to anon;

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

create table if not exists public.community_events (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 160),
  description text not null default '' check (char_length(description) <= 2000),
  location_label text not null check (char_length(location_label) between 3 and 200),
  latitude double precision,
  longitude double precision,
  starts_at timestamptz,
  ends_at timestamptz,
  capacity integer check (capacity is null or capacity > 0),
  is_active boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_events_dates_valid check (
    (starts_at is null and ends_at is null)
    or (starts_at is not null and ends_at is not null and ends_at > starts_at)
  ),
  constraint community_events_active_has_dates check (
    not is_active or (starts_at is not null and ends_at is not null)
  ),
  constraint community_events_coordinates_valid check (
    (latitude is null and longitude is null)
    or (latitude between -90 and 90 and longitude between -180 and 180)
  )
);

create index if not exists community_events_active_starts_at_idx
on public.community_events (starts_at)
where is_active;

alter table public.community_events enable row level security;
revoke all on public.community_events from anon, authenticated;
grant select (
  id,
  title,
  description,
  location_label,
  latitude,
  longitude,
  starts_at,
  ends_at,
  capacity,
  is_active
) on public.community_events to anon;
grant select, insert, update, delete on public.community_events to authenticated;

drop policy if exists "Public can read active community events" on public.community_events;
create policy "Public can read active community events"
on public.community_events for select to anon, authenticated
using (
  is_active
  and starts_at is not null
  and ends_at >= now()
);

drop policy if exists "Admins can read all community events" on public.community_events;
create policy "Admins can read all community events"
on public.community_events for select to authenticated
using ((select public.is_report_admin()));

drop policy if exists "Admins can create community events" on public.community_events;
create policy "Admins can create community events"
on public.community_events for insert to authenticated
with check ((select public.is_report_admin()));

drop policy if exists "Admins can update community events" on public.community_events;
create policy "Admins can update community events"
on public.community_events for update to authenticated
using ((select public.is_report_admin()))
with check ((select public.is_report_admin()));

drop policy if exists "Admins can delete community events" on public.community_events;
create policy "Admins can delete community events"
on public.community_events for delete to authenticated
using ((select public.is_report_admin()));

create table if not exists public.event_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.community_events(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 2 and 100),
  whatsapp text not null check (char_length(whatsapp) between 8 and 30),
  whatsapp_normalized text not null
    check (whatsapp_normalized ~ '^[0-9]{8,15}$'),
  registered_at timestamptz not null default now(),
  constraint event_registrations_unique_phone unique (event_id, whatsapp_normalized)
);

create index if not exists event_registrations_event_id_idx
on public.event_registrations (event_id);

alter table public.event_registrations enable row level security;
revoke all on public.event_registrations from anon, authenticated;
grant select on public.event_registrations to authenticated;

drop policy if exists "Admins can view event registrations" on public.event_registrations;
create policy "Admins can view event registrations"
on public.event_registrations for select to authenticated
using ((select public.is_report_admin()));

create or replace function public.register_community_event(
  p_event_id uuid,
  p_name text,
  p_whatsapp text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event record;
  v_name text;
  v_whatsapp text;
  v_whatsapp_normalized text;
  v_registration_id uuid;
  v_registration_count integer;
begin
  v_name := pg_catalog.btrim(coalesce(p_name, ''));
  v_whatsapp := pg_catalog.btrim(coalesce(p_whatsapp, ''));
  v_whatsapp_normalized := pg_catalog.regexp_replace(v_whatsapp, '[^0-9]', '', 'g');

  if pg_catalog.char_length(v_name) < 2 or pg_catalog.char_length(v_name) > 100 then
    raise exception using errcode = '22023', message = 'Nama harus berisi 2 sampai 100 karakter.';
  end if;

  if pg_catalog.char_length(v_whatsapp_normalized) < 8
     or pg_catalog.char_length(v_whatsapp_normalized) > 15 then
    raise exception using errcode = '22023', message = 'Nomor WhatsApp harus berisi 8 sampai 15 angka.';
  end if;

  select event.id, event.capacity, event.starts_at, event.ends_at, event.is_active
  into v_event
  from public.community_events as event
  where event.id = p_event_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'Pendaftaran acara ini sudah tidak tersedia.';
  end if;

  if not v_event.is_active
     or v_event.starts_at is null
     or v_event.ends_at <= now() then
    raise exception using errcode = 'P0001', message = 'Pendaftaran acara ini sudah tidak tersedia.';
  end if;

  if exists (
    select 1
    from public.event_registrations as registration
    where registration.event_id = p_event_id
      and registration.whatsapp_normalized = v_whatsapp_normalized
  ) then
    raise exception using errcode = '23505', message = 'Nomor WhatsApp ini sudah terdaftar untuk acara tersebut.';
  end if;

  if v_event.capacity is not null then
    select pg_catalog.count(*)::integer
    into v_registration_count
    from public.event_registrations as registration
    where registration.event_id = p_event_id;

    if v_registration_count >= v_event.capacity then
      raise exception using errcode = 'P0001', message = 'Kuota acara sudah penuh.';
    end if;
  end if;

  insert into public.event_registrations (
    event_id,
    full_name,
    whatsapp,
    whatsapp_normalized
  )
  values (
    p_event_id,
    v_name,
    v_whatsapp,
    v_whatsapp_normalized
  )
  returning id into v_registration_id;

  return v_registration_id;
end;
$$;

revoke all on function public.register_community_event(uuid, text, text)
from public, anon, authenticated;
grant execute on function public.register_community_event(uuid, text, text)
to anon, authenticated;

insert into public.community_events (
  id,
  title,
  description,
  location_label,
  latitude,
  longitude,
  starts_at,
  ends_at,
  capacity,
  is_active
)
values
  (
    'a0000000-0000-4000-8000-000000000001',
    'Aksi Bersih Pantai Pasir Putih Parbaba',
    'Contoh rencana kegiatan. Pengelola perlu memastikan mitra, tanggal, titik kumpul, dan kebutuhan peserta sebelum memublikasikannya.',
    'Pantai Pasir Putih Parbaba (titik area perkiraan)',
    2.5658,
    98.6747,
    null,
    null,
    null,
    false
  ),
  (
    'a0000000-0000-4000-8000-000000000002',
    'Penanaman Pohon di Pangururan',
    'Contoh rencana kegiatan. Jenis pohon, izin lokasi, tanggal, titik kumpul, dan mitra pelaksana harus dikonfirmasi sebelum dipublikasikan.',
    'Pangururan (titik area perkiraan)',
    2.6098,
    98.7062,
    null,
    null,
    null,
    false
  ),
  (
    'a0000000-0000-4000-8000-000000000003',
    'Gotong Royong Pilah Sampah di Tuktuk',
    'Contoh rencana kegiatan. Pengelola perlu memastikan lokasi, tanggal, fasilitas pemilahan, dan tujuan penyaluran sampah sebelum memublikasikannya.',
    'Tuktuk Siadong (titik area perkiraan)',
    2.6571,
    98.8552,
    null,
    null,
    null,
    false
  )
on conflict (id) do nothing;
