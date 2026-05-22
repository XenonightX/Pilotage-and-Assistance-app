# Migrasi MySQL ke Firebase Firestore

Dokumen ini memetakan dump MySQL `pilotage_and_assistance_app` ke struktur Firestore yang mendukung realtime listener dan offline sync.

## Prinsip Migrasi

- Firestore sudah mendukung read, write, listen, dan query dari cache lokal. Saat koneksi kembali online, perubahan lokal otomatis dikirim ke server.
- Android dan iOS mengaktifkan persistence secara default. Aplikasi ini juga menyetel `persistenceEnabled: true` saat inisialisasi Firestore.
- Firestore bukan SQL: tidak ada `JOIN`, stored procedure, trigger, `AUTO_INCREMENT`, atau `LIKE '%keyword%'`.
- Jangan menyimpan password dari tabel `users` di Firestore. Gunakan Firebase Authentication, lalu simpan profil dan role di koleksi `users`.

Referensi resmi:
- https://firebase.google.com/docs/firestore/manage-data/enable-offline
- https://firebase.flutter.dev/docs/firestore/usage

## Koleksi Firestore

### `users/{uid}`

Sumber MySQL: `users`

Gunakan UID Firebase Auth sebagai document ID.

Field:

```json
{
  "legacy_id": 1,
  "name": "Super Admin",
  "email": "superadmin@gmail.com",
  "role": "superadmin",
  "signature_data": null,
  "created_at": "2025-11-21 10:36:44",
  "updated_at": "2026-04-29 09:52:38",
  "search_tokens": ["super", "admin", "superadmin@gmail.com"]
}
```

Catatan:
- `password`, `remember_token`, dan `email_verified_at` tidak perlu dimigrasikan ke Firestore.
- Untuk import akun lama, buat akun di Firebase Auth dulu, lalu tulis profil ke `users/{uid}` dengan `legacy_id`.
- Role valid: `superadmin`, `admin`, `pilot`, `tugboat`.

### `activity_logs/{docId}`

Sumber MySQL aktif saat ini: `activity_logs`

Ini adalah data yang dipakai API `get_pilotages.php`, `add_pilotages.php`, `update_pilotages.php`, stats, dan PDF.

Field inti:

```json
{
  "legacy_id": 21,
  "vessel_name": "SITC RUIDE",
  "call_sign": "RUDE",
  "master_name": "ALOY",
  "flag": "SINGAPORE",
  "gross_tonnage": "160000",
  "loa": "168",
  "fore_draft": "",
  "aft_draft": "",
  "agency": "PT. LINI AGENCY ASIA",
  "pilot_name": "Andhi",
  "pilot_user_id": 7,
  "pilot_uid": null,
  "from_where": "LAUT",
  "to_where": "BATU AMPAR",
  "last_port": "SINGAPORE",
  "next_port": "SINGAPORE",
  "assist_tug_name": "TB. HEMINGWAY 2400,TB. ORIENT VICTORY 1",
  "engine_power": "2400,3500",
  "bollard_pull_power": "24,44",
  "date": "2026-04-29",
  "pilot_on_board": "2026-04-29 17:10:00",
  "pilot_finished": "2026-04-29 18:15:00",
  "vessel_start": "2026-04-29 18:11:00",
  "pilot_get_off": "2026-04-29 18:25:00",
  "status": "Selesai",
  "signature": "data:image/png;base64,...",
  "created_at": "2026-04-29 10:12:47",
  "updated_at": "2026-04-29 10:13:19",
  "search_tokens": ["sitc", "ruide", "andhi", "pt", "lini", "agency", "asia"]
}
```

Catatan:
- Pakai `docId` auto-ID untuk data baru. Untuk data hasil migrasi, script memakai `legacy_id` sebagai document ID agar mudah dilacak.
- Tambahkan `pilot_uid` jika akun pilot sudah dipetakan ke Firebase Auth UID. Ini penting untuk security rules yang membatasi pilot hanya mengubah data miliknya.
- Query list utama bisa memakai:
  - `where('status', isEqualTo: ...)`
  - `where('date', isGreaterThanOrEqualTo: start)`
  - `where('date', isLessThanOrEqualTo: end)`
  - `orderBy('date', descending: true)`
  - `orderBy('pilot_on_board', descending: true)`
- Search bebas seperti SQL `LIKE` perlu strategi berbeda. Untuk tahap awal gunakan `search_tokens` + `arrayContains`, atau gunakan Algolia/Meilisearch jika butuh full text search serius.

### `pilotage_logs/{docId}`

Sumber MySQL: `pilotage_logs`

Tabel ini masih ada di dump, tetapi API utama sekarang membaca `activity_logs`. Migrasikan sebagai arsip/kompatibilitas, atau gabungkan ke `activity_logs` jika tidak lagi dipakai.

### `assistance_logs/{docId}`

Sumber MySQL: `assistance_logs`

Pertahankan field seperti tabel lama. Jika penundaan mulai dipakai realtime, tambahkan `search_tokens`, `created_by_uid`, dan `updated_by_uid`.

### `assist_tugs/{docId}`

Sumber MySQL: `assist_tugs`

Field:

```json
{
  "legacy_id": 1,
  "assist_tug_name": "TB. Hemingway 2400",
  "engine_power": 2400,
  "created_at": "2025-11-23 07:15:02",
  "updated_at": "2025-11-23 07:36:11",
  "search_tokens": ["tb", "hemingway", "2400"]
}
```

### `password_resets`

Jangan dimigrasikan. Gunakan fitur reset password dari Firebase Authentication.

## Setup Flutter

Tambahkan dependency Firebase:

```yaml
firebase_core: ^4.7.0
cloud_firestore: ^6.3.0
firebase_auth: ^6.4.0
```

Lalu jalankan:

```powershell
cd frontend
flutter pub get
dart pub global activate flutterfire_cli
flutterfire configure
```

Inisialisasi Firebase di `main.dart` setelah `firebase_options.dart` dibuat:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const MyApp());
}
```

## Realtime dan Offline Sync di UI

Ganti pola lama:

```dart
final response = await http.get(Uri.parse('$baseUrl/get_pilotages.php'));
```

menjadi listener:

```dart
FirebaseFirestore.instance
    .collection('activity_logs')
    .orderBy('date', descending: true)
    .orderBy('pilot_on_board', descending: true)
    .snapshots(includeMetadataChanges: true)
    .listen((snapshot) {
      final rows = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
          '_has_pending_writes': doc.metadata.hasPendingWrites,
          '_from_cache': snapshot.metadata.isFromCache,
        };
      }).toList();
    });
```

Saat user offline:
- `add`, `set`, `update`, dan `delete` tetap berhasil secara lokal.
- UI akan menerima snapshot lokal.
- `doc.metadata.hasPendingWrites == true` bisa dipakai untuk menampilkan label "menunggu sync".
- Saat online lagi, Firestore mengirim perubahan ke server otomatis.

## Langkah Migrasi Data

1. Buat Firebase project dan aktifkan:
   - Firebase Authentication dengan Email/Password.
   - Cloud Firestore.
2. Buat akun Firebase Auth untuk user lama.
3. Buat mapping legacy user ID ke Firebase Auth UID:

```json
{
  "1": "firebase_uid_superadmin",
  "7": "firebase_uid_andhi",
  "9": "firebase_uid_syamsul"
}
```

4. Konversi SQL dump ke seed JSON:

```powershell
python tools/sql_to_firestore_seed.py "C:\Users\hp vapilion\Downloads\pilotage_and_assistance_app (1).sql" --out build\firestore_seed
```

5. Import seed ke Firestore:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\service-account.json"
npm install firebase-admin
node tools/import_firestore_seed.js build\firestore_seed --user-map build\legacy_user_to_uid.json
```

Validasi lokal tanpa menulis ke Firestore bisa dijalankan tanpa `firebase-admin`:

```powershell
node tools/import_firestore_seed.js build\firestore_seed --dry-run
```

6. Deploy rules dan indexes:

```powershell
firebase deploy --only firestore
```

Tahap live deploy/import belum bisa dijalankan dari workspace ini sebelum tersedia:
- Firebase project yang sudah login/terhubung ke CLI.
- `flutterfire` CLI dan Firebase CLI.
- Service account JSON untuk import server-side.
- File mapping `build\legacy_user_to_uid.json` dari ID user MySQL ke UID Firebase Auth.

## Status Implementasi Aplikasi

- `login_page.dart` sudah memakai Firebase Auth `signInWithEmailAndPassword`.
- `add_user_page.dart` sudah membuat Firebase Auth user dan profil `users/{uid}` untuk superadmin.
- `edit_profile_page.dart` sudah update profil ke Firestore.
- `navbar.dart` sudah membaca aktivitas terbaru lewat realtime listener Firestore dan tombol `Tambah User` hanya tampil untuk `superadmin`.
- `pemanduan_page.dart` sudah membaca, update, delete, filter, stats, dan pagination dari Firestore listener/query.
- `tambah_pemanduan_page.dart` sudah menulis data baru ke Firestore dan mengambil user pilot dari koleksi `users`.
- PDF pemanduan sudah dibuat lokal lewat `frontend/lib/utils/pdf_generator.dart`, termasuk tanda tangan jika tersedia.

Catatan produksi: pembuatan user oleh superadmin dari client sudah berjalan, tetapi arsitektur yang lebih kuat adalah Cloud Function/Admin backend agar pembuatan akun dan pemberian role tidak bergantung pada client.

## Risiko Teknis

- Firestore document limit adalah 1 MiB. Signature base64 biasanya masih aman, tetapi PDF atau gambar besar sebaiknya masuk Cloud Storage.
- Query gabungan `status + date range + orderBy` perlu composite index.
- Conflict offline diselesaikan dengan last-write-wins untuk dokumen yang sama. Untuk field penting, simpan `updated_by_uid`, `updated_at`, dan pertimbangkan transaction saat online.
- Jangan mengandalkan auto-increment. Gunakan document ID Firestore.
