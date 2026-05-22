import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pilotage_and_assistance_app/services/firestore_data_service.dart';
import 'package:pilotage_and_assistance_app/utils/user_session.dart';

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, FirestoreDataService? dataService})
    : _auth = auth ?? FirebaseAuth.instance,
      _dataService = dataService ?? FirestoreDataService();

  final FirebaseAuth _auth;
  final FirestoreDataService _dataService;

  User? get currentUser => _auth.currentUser;

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw Exception('Login gagal. Firebase tidak mengembalikan user.');
    }

    final profile = await _dataService.getUserProfile(user.uid);
    if (profile == null) {
      await _auth.signOut();
      throw Exception(
        'Profil user belum ada di Firestore. Import data users terlebih dahulu.',
      );
    }

    await _saveSession(user.uid, profile);
    return profile;
  }

  Future<bool> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      await UserSession.clear();
      return false;
    }

    final profile = await _dataService.getUserProfile(user.uid);
    if (profile == null) {
      await UserSession.clear();
      return false;
    }

    await _saveSession(user.uid, profile);
    return true;
  }

  Future<void> updateCurrentUserProfile({
    required String name,
    required String email,
    String? signatureData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User belum login.');
    }

    final data = {
      'name': name.trim(),
      'email': email.trim(),
      if (signatureData != null) 'signature_data': signatureData,
    };

    await _dataService.setUserProfile(user.uid, data);
    await user.updateDisplayName(name.trim());

    await UserSession.setUser(
      uid: user.uid,
      id: UserSession.userId ?? 0,
      name: name.trim(),
      email: email.trim(),
      role: UserSession.userRole ?? '',
    );
  }

  Future<String> createUserAsSuperadmin({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    if (!UserSession.isSuperadmin()) {
      throw Exception(
        'Akses ditolak. Hanya superadmin yang dapat menambah user.',
      );
    }

    final primaryApp = Firebase.app();
    final secondaryApp = await Firebase.initializeApp(
      name: 'userCreation-${DateTime.now().microsecondsSinceEpoch}',
      options: primaryApp.options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Firebase tidak mengembalikan user baru.');
      }

      await user.updateDisplayName(name.trim());
      await _dataService.setUserProfile(user.uid, {
        'name': name.trim(),
        'email': email.trim(),
        'role': role,
        'created_at': FieldValue.serverTimestamp(),
        'created_by_uid': UserSession.userUid,
      });

      await secondaryAuth.signOut();
      return user.uid;
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await UserSession.clear();
  }

  Future<void> _saveSession(String uid, Map<String, dynamic> profile) async {
    await UserSession.setUser(
      uid: uid,
      id: _asInt(profile['legacy_id']) ?? _asInt(profile['id']) ?? 0,
      name: (profile['name'] ?? '').toString(),
      email: (profile['email'] ?? '').toString(),
      role: (profile['role'] ?? '').toString(),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }
}
