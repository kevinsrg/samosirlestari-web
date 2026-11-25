# samosirlestari
# SamosirLestari

Website SamosirLestari.

## Supabase Authentication

Proyek ini sudah terhubung ke alur autentikasi Supabase di sisi browser:

- Pendaftaran akun
- Login email dan kata sandi
- Sesi login yang tersimpan otomatis
- Konfirmasi email Supabase
- Logout
- Sinkronisasi nama profil ke metadata akun

### 1. Buat project Supabase

1. Buka https://supabase.com dan buat project baru.
2. Catat Project URL dan anon/public key dari:
   `Project Settings -> API`.
3. Jangan pernah menaruh `service_role key` di file browser.

### 2. Isi konfigurasi lokal

Edit [supabase-config.js](supabase-config.js):

```javascript
window.SUPABASE_CONFIG = {
  url: "https://PROJECT_ID.supabase.co",
  anonKey: "YOUR_ANON_PUBLIC_KEY"
};
```

### 3. Aktifkan email auth

Di Supabase Dashboard:

1. Buka `Authentication -> Providers -> Email`.
2. Aktifkan Email provider.
3. Tentukan apakah konfirmasi email wajib melalui opsi `Confirm email`.
4. Tambahkan URL situs produksi ke:
   `Authentication -> URL Configuration -> Redirect URLs`.

Untuk pengujian lokal, buka situs melalui server HTTP, bukan hanya double-click file:

```powershell
python -m http.server 5500
```

Lalu buka `http://localhost:5500`.

## Saldo poin per akun

Saldo setiap akun dimulai dari **0** dan disimpan di Supabase, bukan di browser.
Jalankan [supabase-points.sql](supabase-points.sql) satu kali di
`Supabase Dashboard -> SQL Editor -> New query -> Run`. Skrip ini membuat
saldo nol untuk akun lama dan akun baru, serta mengaktifkan kebijakan agar
pengguna hanya dapat membaca saldo dan riwayat poin miliknya sendiri.

Bonus demo yang saat ini tersedia hanya dapat diterima satu kali per akun:

- Dukung tiap laporan contoh: 5 poin per laporan
- Catat setoran sampah contoh: 10 poin
- Pilih rute hijau contoh: 25 poin
- Gabung aksi bersih-bersih contoh: 100 poin

Setelah SQL dijalankan, login ulang untuk memuat saldo. Tombol aksi saat ini
masih berupa demo dan belum memverifikasi setoran, perjalanan, atau kehadiran
di server. Sebelum digunakan sebagai sistem hadiah produksi, sambungkan aksi
ke data transaksi yang terverifikasi di server.

### 4. SQL profil tambahan (opsional)

Jika profil perlu disimpan sebagai tabel database, jalankan SQL berikut di Supabase SQL Editor:

```sql
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can read own profile"
on public.profiles for select
using (auth.uid() = id);

create policy "Users can insert own profile"
on public.profiles for insert
with check (auth.uid() = id);

create policy "Users can update own profile"
on public.profiles for update
using (auth.uid() = id);
```

