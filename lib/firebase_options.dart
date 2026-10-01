// Firebase settings for the Rankwise app (project rankwise-9e100), copied from
// android/app/google-services.json and ios/Runner/GoogleService-Info.plist.
// Passing them in code means iOS no longer depends on the .plist being added to the Xcode project.
// If you run `flutterfire configure` again it regenerates this file; keep the class name.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// Settings for the phone the app runs on, or null where push is not set up (web, desktop).
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return null;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDlrYtV2wBOg1n4A2nAcI5NhhgHdMVNq5w',
    appId: '1:762425861205:android:46fc8660f7265693f260dc',
    messagingSenderId: '762425861205',
    projectId: 'rankwise-9e100',
    storageBucket: 'rankwise-9e100.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAUoK_9O_uC4aofYvxJnstIWyBdnH-gYA4',
    appId: '1:762425861205:ios:9c7b143b0c180834f260dc',
    messagingSenderId: '762425861205',
    projectId: 'rankwise-9e100',
    storageBucket: 'rankwise-9e100.firebasestorage.app',
    iosBundleId: 'com.example.upscQuestionsApp',
  );
}
