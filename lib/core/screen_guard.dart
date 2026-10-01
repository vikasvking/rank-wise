import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Strict tests on Android: blocks screenshots and screen recording of the app (Android's FLAG_SECURE),
/// so questions cannot be shared as pictures during the test. The native side is in MainActivity.kt.
/// iOS has no such switch, so this does nothing there.
class ScreenGuard {
  static const _channel = MethodChannel('rankwise/screen_guard');

  static Future<void> secure(bool on) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', on);
    } catch (_) {
      // a build without the native side: the test still works, screenshots are just not blocked
    }
  }
}
