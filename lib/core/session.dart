import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'json.dart';

/// Who is signed in. Keeps the API token on the device so the app stays signed in: in the phone's
/// secure storage (Android Keystore, iOS Keychain), not in plain app preferences.
class AppSession extends ChangeNotifier {
  AppSession() {
    api.onUnauthorized = _expired;
  }

  static const _tokenKey = 'rankwise_api_token';
  static const _secure = FlutterSecureStorage();

  final ApiClient api = ApiClient();

  /// The signed-in user (see Api::V1::BaseController#user_json), or null.
  J? user;

  /// True until the saved token has been checked at startup.
  bool loading = true;

  /// Set when the saved token could not be checked (offline, server asleep...).
  String? startupError;

  /// A one-off message for the sign-in screen ("Your session ended...").
  String? notice;

  /// Called after signing out, to close any open screens.
  VoidCallback? onSignedOut;

  /// Runs before signing out, while the API token still works (the phone leaves push notifications).
  Future<void> Function()? beforeSignOut;

  bool get hasToken => api.token != null;
  bool get signedIn => user != null;
  bool get isStudent => user?.str('role') == 'student';
  bool get isFaculty => user?.flag('faculty') ?? false;
  J? get accountIssue => user?.objOrNull('account_issue');

  Future<void> restore() async {
    api.token = await _readToken();
    if (api.token != null) {
      try {
        user = (await api.get('/me')).obj('user');
        startupError = null;
      } on ApiException catch (e) {
        if (e.status == 401) {
          await _clear();
        } else {
          startupError = e.message;
        }
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> retryStartup() async {
    loading = true;
    startupError = null;
    notifyListeners();
    await restore();
  }

  Future<void> signIn(String email, String password) async {
    final data = await api.post('/session', {
      'email_address': email.trim(),
      'password': password,
    });
    final token = data.str('token');
    api.token = token;
    await _writeToken(token);
    user = data.obj('user');
    notice = null;
    startupError = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    user = (await api.get('/me')).obj('user');
    notifyListeners();
  }

  void setUser(J value) {
    user = value;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await beforeSignOut?.call();
    } catch (_) {
      // never blocks signing out
    }
    try {
      await api.delete('/session');
    } catch (_) {
      // signing out still works offline; the token is forgotten on this device
    }
    await _clear();
    onSignedOut?.call();
    notifyListeners();
  }

  void _expired() {
    _clear();
    notice = 'Your session ended. Please sign in again.';
    onSignedOut?.call();
    notifyListeners();
  }

  Future<void> _clear() async {
    api.token = null;
    user = null;
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {
      // nothing stored, or the storage is unreadable: either way the token is gone
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey); // left by app versions before secure storage
  }

  // ---------- where the token is kept ----------

  /// Older versions of the app kept the token in plain SharedPreferences. It is moved into secure
  /// storage the first time this version starts, so nobody has to sign in again.
  Future<String?> _readToken() async {
    try {
      final token = await _secure.read(key: _tokenKey);
      if (token != null) return token;
    } catch (_) {
      // unreadable (for example after the phone was restored from a backup): sign in again
    }
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(_tokenKey);
    if (old != null && await _writeToken(old)) await prefs.remove(_tokenKey);
    return old;
  }

  /// True when the token was saved
  Future<bool> _writeToken(String token) async {
    try {
      await _secure.write(key: _tokenKey, value: token);
      return true;
    } catch (_) {
      return false; // still signed in for now; the next start asks to sign in again
    }
  }
}

/// Makes the [AppSession] available to every screen.
class AppScope extends InheritedNotifier<AppSession> {
  const AppScope({super.key, required AppSession session, required super.child})
    : super(notifier: session);

  /// Rebuilds the caller when the session changes.
  static AppSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the session without rebuilding (for button handlers and loaders).
  static AppSession read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
