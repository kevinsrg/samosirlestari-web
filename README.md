# samosirlestari
# SamosirLestari

Website SamosirLestari.

## Supabase Authentication

Proyek ini sudah terhubung ke alur autentikasi Supabase di sisi browser:

- Pendaftaran akun
- Login email dan kata sandi
- Sesi login yang tersimpan otomatis
- Konfirmasi email Supabase
- Pemulihan kata sandi melalui email
- Logout
- Sinkronisasi nama profil ke metadata akun
- Laporan dapat dikirim tanpa akun; akun hanya dibutuhkan untuk fitur profil,
  poin, dan riwayat laporan akun

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
5. Untuk pemulihan kata sandi, tambahkan URL berikut sebagai Redirect URL:
   `https://kevinsrg.github.io/samosirlestari-web/?password-reset=1`.
   Untuk pengujian lokal, tambahkan
   `http://localhost:5500/index.html?password-reset=1`.

Untuk pengujian lokal, buka situs melalui server HTTP, bukan hanya double-click file:

```powershell
python -m http.server 5500
```

Lalu buka `http://localhost:5500`.

## Laporan foto di Supabase

Form laporan mengunggah foto ke bucket privat `report-photos` dan menyimpan
detailnya ke tabel `public.reports`. Pengguna dapat mengirim laporan tanpa akun;
nomor WhatsApp bersifat opsional untuk tindak lanjut pengelola. Laporan tamu
tidak dapat dibaca lewat aplikasi dan tidak muncul di riwayat akun. Foto serta
data laporan tidak dipublikasikan ke feed umum.
Beranda dan profil menghitung laporan dikirim, ditangani, dan menunggu tindak
lanjut dari data laporan milik akun. Peta hanya menampilkan laporan privat milik
akun yang memiliki koordinat GPS. Feed publik, data CO₂, aksi komunitas, lencana,
lokasi bank sampah, dan rekomendasi rute belum tersedia karena belum ada sumber
data terverifikasi untuk fitur-fitur tersebut.

Jalankan [supabase-reports.sql](supabase-reports.sql) melalui
`Supabase Dashboard -> SQL Editor -> New query -> Run`. Jalankan ulang skrip ini
jika tabel laporan sudah pernah dibuat: skrip juga menerapkan perubahan skema
untuk laporan tamu. Skrip membuat bucket privat dan kebijakan Row Level Security
agar akun hanya membaca laporannya sendiri, sementara tamu hanya dapat mengirim
laporan/foto ke folder khusus tanpa izin membaca data. Unggahan dibatasi sampai
5 MB; browser mengecilkan foto dan mengubahnya ke JPEG sebelum diunggah.

Setelah SQL berhasil dijalankan, buka situs melalui HTTPS atau localhost dan
gunakan **Lapor Masalah** tanpa perlu masuk. Pilih foto, kategori, isi lokasi
dan keterangan, lalu kirim. GPS dan nomor WhatsApp bersifat opsional. Laporan
baru berstatus `Menunggu verifikasi`; setelah laporan tamu terkirim, simpan
nomor referensi yang ditampilkan. Riwayat dan foto laporan akun tetap hanya
tersedia setelah masuk.

Kebijakan anon membatasi jenis operasi dan folder unggahan, tetapi endpoint
laporan tamu tetap dapat menerima spam otomatis. Untuk penggunaan publik dengan
volume tinggi, tambahkan CAPTCHA dan pembatasan laju di sisi server sebelum
mengandalkan laporan tamu sebagai kanal terverifikasi.

## Saldo poin per akun

Saldo setiap akun disimpan di Supabase, bukan di browser. Jalankan
[supabase-points.sql](supabase-points.sql) satu kali di
`Supabase Dashboard -> SQL Editor -> New query -> Run`. Skrip ini membuat
saldo nol untuk akun yang belum memiliki catatan saldo dan menyiapkan saldo nol
untuk akun baru, serta mengaktifkan kebijakan agar pengguna hanya dapat membaca
saldo dan riwayat poin miliknya sendiri. Skrip juga mencabut akses browser ke
RPC hadiah demo; jalankan ulang skrip ini jika versi sebelumnya sudah pernah
dipasang.

Aplikasi saat ini tidak memberikan poin dari tombol demo karena setoran,
perjalanan, dukungan, dan kehadiran belum diverifikasi. Saldo maupun riwayat poin
lama tidak dihapus atau diubah otomatis; saldo lama mungkin masih berisi poin
demo yang diberikan sebelum perubahan ini dan belum dapat dianggap sebagai
hadiah terverifikasi. Saldo ditampilkan sebagai notifikasi di dalam aplikasi,
bukan sebagai halaman poin tersendiri.

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

