# Debug Android

Status mesin saat dicek:

- Android SDK siap.
- HP terdeteksi sebagai `RR8MA062CGF` / `SM A507FN`.
- APK debug berhasil dibuat dan diinstall.
- Aplikasi berhasil di-start lewat ADB.

Yang masih wajib diisi agar login, Firestore realtime, dan offline sync berjalan benar adalah Firebase config Android untuk package:

```text
com.example.pilotage_and_assistance_app
```

Cara paling mudah:

1. Buka Firebase Console.
2. Pilih project aplikasi.
3. Tambahkan Android app dengan package `com.example.pilotage_and_assistance_app`.
4. Download `google-services.json`.
5. Letakkan file itu di:

```text
frontend\android\app\google-services.json
```

Lalu jalankan:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_android_debug.ps1
```

Script akan membaca `google-services.json` dan mengirim nilainya ke app lewat `--dart-define`.

Alternatif tanpa `google-services.json`, set env var berikut di PowerShell sebelum debug:

```powershell
$env:FIREBASE_API_KEY="..."
$env:FIREBASE_ANDROID_APP_ID="..."
$env:FIREBASE_MESSAGING_SENDER_ID="..."
$env:FIREBASE_PROJECT_ID="..."
$env:FIREBASE_AUTH_DOMAIN="..."
$env:FIREBASE_STORAGE_BUCKET="..."
```

Setelah itu jalankan:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_android_debug.ps1
```

Tanpa env Firebase tersebut, app tetap bisa dibuild dan dibuka di HP, tetapi akan menampilkan halaman `Firebase belum siap`.
