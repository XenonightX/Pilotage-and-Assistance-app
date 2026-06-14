import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pilotage_and_assistance_app/services/offline_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login/login_page.dart';
import 'services/firebase_auth_service.dart';
import 'widgets/navbar/navbar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    await OfflineSyncService.instance.init();
  } catch (e) {
    firebaseError = e;
  }

  runApp(MyApp(firebaseError: firebaseError));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.firebaseError});

  final Object? firebaseError;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget _homePage = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    if (widget.firebaseError != null) {
      setState(() {
        _homePage = FirebaseSetupErrorPage(error: widget.firebaseError!);
      });
      return;
    }

    final hasFirebaseUser = FirebaseAuth.instance.currentUser != null;
    final isLoggedIn = hasFirebaseUser
        ? await FirebaseAuthService().restoreSession()
        : false;

    setState(() {
      _homePage = isLoggedIn ? const ResponsiveNavBarPage() : const LoginPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: _homePage);
  }
}

class FirebaseSetupErrorPage extends StatelessWidget {
  const FirebaseSetupErrorPage({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Firebase belum siap',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('$error'),
                const SizedBox(height: 16),
                const Text(
                  'Jalankan `flutterfire configure` dari folder frontend, '
                  'atau isi Firebase options lewat --dart-define seperti yang '
                  'dijelaskan di docs/firestore_migration.md.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
