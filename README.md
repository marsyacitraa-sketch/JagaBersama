# JagaBersama — Family Health Monitoring & Management System

Aplikasi Android berbasis **Flutter (Material Design 3)** dan **Supabase (Free Tier)** untuk membantu keluarga mencatat, mengelola, memantau perkembangan pemeriksaan kesehatan, menyimpan dokumen medis, serta mengatur jadwal kontrol seluruh anggota keluarga.

---

## Fitur Utama

- **Manajemen Akun, Grup Keluarga & Peran (Hybrid)**:
  - Autentikasi Email & Password + Reset Kata Sandi via **OTP 6-digit in-app**.
  - 3 Peran: **Admin Utama (`owner`)**, **Pengelola (`caretaker`)**, dan **Anggota (`member`)**.
  - Mendukung **Profil Tanpa Akun** (untuk orang tua/lansia atau anak tanpa HP) lengkap dengan **Kode Klaim** jika kelak ingin dihubungkan ke akun baru.
  - Pengaturan privasi profil dewasa (`Privat`, `Lihat Saja`, `Lihat & Input`) yang ditegakkan hingga level Row Level Security (RLS) PostgreSQL.
- **Pencatatan & Pemantauan Kesehatan**:
  - Form fleksibel (Tekanan Darah, Gula Darah Puasa/Sewaktu/Setelah Makan, Suhu Tubuh, Denyut Nadi, Berat & Tinggi Badan + IMT otomatis, Keluhan & Catatan).
  - Indikator status kesehatan otomatis (Normal, Waspada, Tinggi/Rendah) & identitas pencatat (`recorded_by`).
  - Grafik tren Harian, Mingguan, dan Bulanan menggunakan `fl_chart`.
- **Dokumen & Jadwal Kesehatan + Ramah Lansia**:
  - Upload foto (dikompresi otomatis di Flutter agar hemat Storage 1 GB Supabase) dan PDF ke bucket privat `health-documents`.
  - Kalender jadwal kontrol & pengingat alarm lokal (`flutter_local_notifications`).
  - **Mode Teks Besar (Ramah Lansia)** (`Aa`) & Log Aktivitas keluarga.

---

## Panduan Setup Supabase (Gratis)

1. Buat proyek baru di [Supabase](https://supabase.com/).
2. Buka **SQL Editor -> New Query**, salin seluruh isi file `database_schema.sql`, lalu klik **Run**.
3. Pengaturan Autentikasi di **Authentication -> Providers -> Email**:
   - Opsional (disarankan untuk kemudahan pengguna lansia): matikan **Confirm email** agar pengguna baru bisa langsung masuk setelah daftar.
   - Untuk fitur **Lupa Kata Sandi (OTP 6-digit)**: buka **Authentication -> Email Templates -> Reset Password**, pastikan template menampilkan kode token (`{{ .Token }}`).
4. Catat **Project URL** dan **anon public key** di **Project Settings -> API**.

---

## Cara Build `.apk` Otomatis via GitHub Actions

1. Push proyek ini ke repositori GitHub Anda (branch `main` atau `master`).
2. Buka repositori di GitHub → **Settings → Secrets and variables → Actions → New repository secret**:
   - `SUPABASE_URL`: URL proyek Supabase Anda.
   - `SUPABASE_ANON_KEY`: Anon Key proyek Supabase Anda.
3. Buka tab **Actions** → pilih workflow **Build JagaBersama Android APK** (atau jalankan manual via **Run workflow**).
4. Setelah selesai, unduh file **`jagabersama-release-apk`** (`app-release.apk`) di bagian **Artifacts** pada halaman workflow run.

---

## Menjalankan Secara Lokal (Opsional jika Flutter SDK Terpasang)

Salin `env.example.json` menjadi `env.json`, isi URL & Anon Key Supabase Anda, lalu jalankan:

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

Atau build APK secara lokal:

```bash
flutter build apk --release --dart-define-from-file=env.json
```
