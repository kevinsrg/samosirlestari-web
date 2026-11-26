# SamosirLestari

Website informasi dan pelaporan masalah lingkungan di Kabupaten Samosir.

## Menyiapkan Supabase

1. Buat project di https://supabase.com.
2. Salin Project URL dan anon/public key dari `Project Settings -> API`.
3. Isi nilai tersebut di [supabase-config.js](supabase-config.js).
   Jangan gunakan `service_role key` di browser.
4. Jalankan [supabase-reports.sql](supabase-reports.sql) melalui
   `Supabase Dashboard -> SQL Editor -> New query -> Run`. Jika tabel laporan
   sudah pernah dibuat, jalankan ulang skrip untuk menerapkan perubahan skema
   laporan tamu.

Untuk pengujian lokal, jalankan situs melalui server HTTP:

```powershell
python -m http.server 5500
```

Lalu buka `http://localhost:5500`.

## Laporan tanpa akun

Pengunjung dapat langsung memilih **Lapor sekarang** tanpa membuat akun atau
menyimpan kata sandi. Foto bukti, kategori, dan lokasi diperlukan; keterangan,
GPS, serta nomor WhatsApp bersifat opsional. Setelah terkirim, simpan nomor
referensi yang ditampilkan.

Laporan dan foto disimpan di Supabase dalam bucket privat. Akses anonim hanya
dapat mengirim laporan dan mengunggah foto ke folder khusus; pengunjung tidak
dapat membaca laporan melalui aplikasi. Nomor WhatsApp hanya untuk tindak lanjut
manual oleh pengelola dan tidak memicu pesan otomatis.

Form membatasi foto hingga 5 MB dan mengecilkannya di browser sebelum diunggah.
Kebijakan anon membatasi operasi dan folder, tetapi endpoint laporan tetap dapat
menerima spam otomatis. Untuk penggunaan publik dengan volume tinggi, tambahkan
CAPTCHA serta pembatasan laju di sisi server.

Fitur login, pendaftaran, profil akun, poin, dan riwayat akun tidak tersedia di
aplikasi. Data akun/laporan lama di Supabase tidak dihapus oleh perubahan ini.
