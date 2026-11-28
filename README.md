# SamosirLestari

Website informasi dan pelaporan masalah lingkungan di Kabupaten Samosir.

## Menyiapkan Supabase

1. Buat project di https://supabase.com.
2. Salin Project URL dan anon/public key dari `Project Settings -> API`.
3. Isi nilai tersebut di [supabase-config.js](supabase-config.js).
   Jangan gunakan `service_role key` di browser.
4. Jalankan [supabase-reports.sql](supabase-reports.sql) melalui
   `Supabase Dashboard -> SQL Editor -> New query -> Run`. Jika tabel laporan
   sudah pernah dibuat, jalankan ulang skrip untuk menerapkan skema pelacakan
   status, dashboard pengelola, dan kebijakan akses.
   Fungsi `get_public_report_stats()` juga menyediakan hitungan agregat untuk
   beranda tanpa memberikan akses baca anonim ke baris laporan.

### Menyiapkan akun pengelola

1. Buat akun pengelola melalui `Supabase Dashboard -> Authentication -> Users`.
   Jangan menambahkan formulir pendaftaran admin di aplikasi publik.
2. Salin UUID akun dari daftar pengguna.
3. Jalankan perintah berikut di SQL Editor dengan mengganti UUID contoh:

   ```sql
   insert into public.report_admins (user_id)
   values ('00000000-0000-0000-0000-000000000000')
   on conflict (user_id) do nothing;
   ```

4. Buka **Portal pengelola** di aplikasi dan masuk menggunakan email serta kata
   sandi akun tersebut. Hapus akses dengan menghapus UUID dari
   `public.report_admins`.

Foto laporan warga tetap privat dan hanya dapat dilihat pengelola. Foto bukti
penyelesaian disimpan di bucket publik `report-resolution-photos`, sehingga
siapa pun yang memiliki nomor referensi dapat melihatnya melalui halaman cek
status. Nomor WhatsApp pelapor tidak dikembalikan oleh pencarian publik.
Foto laporan awal tetap privat dan tidak ditampilkan pada halaman cek status.

Untuk pengujian lokal, jalankan situs melalui server HTTP:

```powershell
python -m http.server 5500
```

Lalu buka `http://localhost:5500`.

## Laporan tanpa akun

Pengunjung dapat langsung memilih **Lapor sekarang** tanpa membuat akun atau
menyimpan kata sandi. Foto bukti, kategori, dan lokasi diperlukan; keterangan,
GPS, serta nomor WhatsApp bersifat opsional. Setelah terkirim, simpan nomor
referensi acak berformat `SL-XXXXXXXXXXXX` yang ditampilkan. Gunakan menu
**Status** untuk melihat status terkini, lokasi, tanggal laporan, catatan
pengelola, dan foto bukti penyelesaian jika tersedia.

Laporan dan foto disimpan di Supabase dalam bucket privat. Akses anonim hanya
dapat mengirim laporan dan mengunggah foto ke folder khusus, serta memeriksa
status lewat fungsi pencarian yang hanya mengembalikan informasi terbatas untuk
nomor referensi yang cocok. Pengunjung tidak mendapat akses baca langsung ke
tabel laporan. Nomor WhatsApp hanya untuk tindak lanjut manual oleh pengelola
dan tidak memicu pesan otomatis.

Form membatasi foto hingga 5 MB dan mengecilkannya di browser sebelum diunggah.
Kebijakan anon membatasi operasi dan folder, tetapi endpoint laporan tetap dapat
menerima spam otomatis. Untuk penggunaan publik dengan volume tinggi, tambahkan
CAPTCHA serta pembatasan laju di sisi server.

## Instalasi dan akses offline

Situs menyediakan `manifest.json` dan Service Worker untuk instalasi ke layar
utama serta cache halaman dan aset lokal. Sajikan situs melalui HTTPS atau
`localhost` agar Service Worker dapat berjalan. Beranda dan panduan pilah
sampah tersedia offline setelah kunjungan pertama; peta, data Supabase, dan
fitur yang membutuhkan jaringan tetap memerlukan koneksi internet.

## Kegiatan komunitas

Migrasi `supabase-reports.sql` juga menyiapkan tabel `community_events` dan
`event_registrations`. Daftar acara aktif dapat dibaca publik, sedangkan
pendaftaran tanpa akun dilakukan melalui fungsi `register_community_event`.
Nama dan nomor WhatsApp peserta hanya dapat dibaca pengelola yang terdaftar di
`report_admins`. Untuk mengumumkan salah satu contoh rencana acara, admin harus
mengisi tanggal, waktu, lokasi, dan informasi yang sudah dikonfirmasi, lalu
mengaktifkannya di Supabase.

Lokasi titik pengumpulan sampah dan rute pada aplikasi saat ini merupakan
perkiraan kawasan, bukan alamat fasilitas, jam operasional, atau panduan
navigasi resmi. Verifikasi akses, jarak, penerimaan sampah, dan kondisi setempat
sebelum berkunjung.

Fitur login, pendaftaran, profil akun, poin, dan riwayat akun tidak tersedia di
aplikasi. Data akun/laporan lama di Supabase tidak dihapus oleh perubahan ini.
