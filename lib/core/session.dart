import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'json.dart';

/// Who is signed in. Keeps the API token on the device so the app stays signed in.
class AppSession extends ChangeNotifier {
  AppSession() {
    api.onUnauthorized = _expired;
  }

  static const _tokenKey = 'rankwise_api_token';

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
    final prefs = await SharedPreferences.getInstance();
    api.token = prefs.getString(_tokenKey);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
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
