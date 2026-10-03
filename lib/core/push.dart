import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'json.dart';
import 'session.dart';

/// Push notifications through Firebase Cloud Messaging (the server side is PushNotifier in the Rails app).
///
/// * Students only: after signing in, the phone asks for permission, sends its token to the server
///   (POST /devices) and subscribes to its exam topics (`push_topics` from /me). Signing out undoes both,
///   so a shared phone never shows another student's notifications.
/// * Tapping a notification opens the test or the result it is about ([onOpen]).
/// * While the app is open, a notification shows as a bar at the bottom instead ([onForeground]).
///
/// Needs the Firebase config files from `flutterfire configure`. Without them [available] is false and
/// the app works as before, just without notifications.
class PushService {
  PushService(this.session);

  /// The one service of the app (set in main), for the settings under Me.
  static PushService? instance;

  final AppSession session;

  static const _topicsKey = 'rankwise_push_topics';

  /// False when Firebase is not set up for this build (or the phone has no Google Play services).
  bool available = false;

  /// Whether the student was asked, and allowed notifications on this phone (asked after signing in).
  bool asked = false;
  bool permitted = false;

  /// Called with the message's data when a notification is tapped: {type: test, test_id: ...}, {type: result, token: ...}.
  void Function(Map<String, dynamic> data)? onOpen;

  /// Called for a notification that arrives while the app is on screen.
  void Function(String title, String body, Map<String, dynamic> data)? onForeground;

  int? _registeredFor; // user id whose token the server has
  bool _launchHandled = false;
  String? _token;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Future<void> init() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options == null) {
        debugPrint('[push] no Firebase settings for this platform, notifications are off');
        return;
      }
      await Firebase.initializeApp(options: options);
      available = true;
    } catch (e) {
      debugPrint('[push] Firebase is not set up, notifications are off: $e');
      return;
    }
    final messaging = FirebaseMessaging.instance;
    _subscriptions
      ..add(FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onForeground?.call(n.title ?? 'Lakshyank', n.body ?? '', m.data);
      }))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpen?.call(m.data)))
      ..add(messaging.onTokenRefresh.listen((token) {
        _token = token;
        _registeredFor = null;
        unawaited(sync());
      }));
    session.addListener(() => unawaited(sync()));
    session.beforeSignOut = unregister;
    await sync();
  }

  /// A notification tapped while the app was closed opens its screen once the student is signed in
  Future<void> _openLaunchNotification() async {
    if (_launchHandled) return;
    _launchHandled = true;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) onOpen?.call(message.data);
  }

  Future<void>? _running;
  bool _again = false;

  /// Registers this phone for the signed-in student and keeps its topics in step with /me.
  /// Runs whenever the session changes (one run at a time); does nothing when nothing changed.
  Future<void> sync() async {
    if (!available) return;
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    do {
      _again = false;
      final run = _sync();
      _running = run;
      await run;
    } while (_again);
    _running = null;
  }

  Future<void> _sync() async {
    final user = session.user;
    if (user == null) {
      _registeredFor = null;
      try {
        await _setTopics(const []);
      } catch (e) {
        debugPrint('[push] could not leave topics: $e');
      }
      return;
    }
    if (user.str('role') != 'student' || session.accountIssue != null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      if (_registeredFor != user.integer('id')) {
        final settings = await messaging.requestPermission();
        asked = true;
        permitted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        _token ??= await messaging.getToken();
        final token = _token;
        if (token == null) return;
        await session.api.post('/devices', {
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        });
        _registeredFor = user.integer('id');
        await _openLaunchNotification();
      }
      await _setTopics(user.strings('push_topics'));
    } catch (e) {
      debugPrint('[push] could not register this phone: $e');
    }
  }

  /// Before signing out (while the API token still works): forget this phone on the server,
  /// leave every topic, and drop the Firebase token so the next student gets a fresh one.
  Future<void> unregister() async {
    if (!available) return;
    try {
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token != null && session.api.token != null) {
        await session.api.delete('/devices', {'token': token});
      }
      await _setTopics(const []);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[push] could not unregister this phone: $e');
    } finally {
      _token = null;
      _registeredFor = null;
    }
  }

  /// Subscribes to the wanted topics and leaves the rest (remembered on the phone between launches).
  Future<void> _setTopics(List<String> wanted) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_topicsKey) ?? const <String>[]).toSet();
    final target = wanted.toSet();
    if (current.length == target.length && current.containsAll(target)) return;

    final messaging = FirebaseMessaging.instance;
    for (final topic in target.difference(current)) {
      await messaging.subscribeToTopic(topic);
    }
    for (final topic in current.difference(target)) {
      await messaging.unsubscribeFromTopic(topic);
    }
    await prefs.setStringList(_topicsKey, target.toList());
  }
}
