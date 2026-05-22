import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    final options = _optionsForCurrentPlatform;
    if (options.apiKey.isEmpty ||
        options.appId.isEmpty ||
        options.messagingSenderId.isEmpty ||
        options.projectId.isEmpty) {
      throw StateError(
        'Firebase belum dikonfigurasi. Jalankan `flutterfire configure` '
        'atau isi FIREBASE_API_KEY, FIREBASE_APP_ID, '
        'FIREBASE_MESSAGING_SENDER_ID, dan FIREBASE_PROJECT_ID lewat --dart-define.',
      );
    }
    return options;
  }

  static FirebaseOptions get _optionsForCurrentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDJ2xCWsCKGlVAmFztBlGWlCrt28lZ42Y0',
    appId: '1:362813937771:web:6efbf77f8ebc8f7075792e',
    messagingSenderId: '362813937771',
    projectId: 'pilotage-and-assistance-app',
    authDomain: 'pilotage-and-assistance-app.firebaseapp.com',
    storageBucket: 'pilotage-and-assistance-app.firebasestorage.app',
    measurementId: 'G-HPHKT7PLS0',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDBgzChgno8C37z49X7YdWjGEDv-3EPCd0',
    appId: '1:362813937771:android:e5d6255c0adda01d75792e',
    messagingSenderId: '362813937771',
    projectId: 'pilotage-and-assistance-app',
    storageBucket: 'pilotage-and-assistance-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCI1cDzBQ-pKHyvfstmsB83SDbyoT6Bctc',
    appId: '1:362813937771:ios:a9b558fc5615e2d875792e',
    messagingSenderId: '362813937771',
    projectId: 'pilotage-and-assistance-app',
    storageBucket: 'pilotage-and-assistance-app.firebasestorage.app',
    iosBundleId: 'com.example.pilotageAssistanceApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCI1cDzBQ-pKHyvfstmsB83SDbyoT6Bctc',
    appId: '1:362813937771:ios:a9b558fc5615e2d875792e',
    messagingSenderId: '362813937771',
    projectId: 'pilotage-and-assistance-app',
    storageBucket: 'pilotage-and-assistance-app.firebasestorage.app',
    iosBundleId: 'com.example.pilotageAssistanceApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDJ2xCWsCKGlVAmFztBlGWlCrt28lZ42Y0',
    appId: '1:362813937771:web:29080a34c79c15f375792e',
    messagingSenderId: '362813937771',
    projectId: 'pilotage-and-assistance-app',
    authDomain: 'pilotage-and-assistance-app.firebaseapp.com',
    storageBucket: 'pilotage-and-assistance-app.firebasestorage.app',
    measurementId: 'G-VWN78LXMEV',
  );

}