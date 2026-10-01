import 'package:flutter/material.dart';

import 'core/json.dart';
import 'core/palette.dart';
import 'core/push.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/account_issue_screen.dart';
import 'screens/login_screen.dart';
import 'student/result_screen.dart';
import 'student/student_home.dart';
import 'student/test_detail_screen.dart';
import 'teacher/teacher_home.dart';
import 'widgets/common.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = AppSession();
  // After signing out (or the token expiring), close every open screen
  session.onSignedOut = () =>
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
  session.restore();
  final theme = ThemeController()..load();

  // Push notifications (students): a tap opens the test or result; while the app is open they show as a bar
    final push = PushService(session)
    ..onOpen = (data) {
      _openFromNotification(session, data);
    }
    ..onForeground = (title, body, data) {
      _showInApp(session, title, body, data);
    };
  PushService.instance = push;
  push.init();

  runApp(RankwiseApp(session: session, theme: theme));
}

void _openFromNotification(AppSession session, Map<String, dynamic> data) {
  final nav = navigatorKey.currentState;
  if (nav == null || !session.isStudent) return;
  switch (data['type']) {
    case 'test':
      final id = int.tryParse('${data['test_id']}');
      if (id != null) nav.push(MaterialPageRoute(builder: (_) => TestDetailScreen(testId: id)));
    case 'result':
      final token = '${data['token'] ?? ''}';
      if (token.isNotEmpty) nav.push(MaterialPageRoute(builder: (_) => ResultScreen(token: token)));
  }
}

void _showInApp(AppSession session, String title, String body, Map<String, dynamic> data) {
  final canOpen = data['type'] == 'test' || data['type'] == 'result';
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        action: canOpen ? SnackBarAction(label: 'Open', onPressed: () => _openFromNotification(session, data)) : null,
      ),
    );
}

class RankwiseApp extends StatelessWidget {
  const RankwiseApp({super.key, required this.session, required this.theme});

  final AppSession session;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: theme,
      child: AppScope(
        session: session,
        // The brand colour follows who is signed in (students burgundy, teachers indigo, admins emerald),
        // and Light / Dark / System follows the setting under Me or the sun / moon button.
        child: ListenableBuilder(
          listenable: Listenable.merge([session, theme]),
          builder: (context, _) {
            final brand = Ramp.forRole(session.user?.str('role'));
            return MaterialApp(
              title: 'Rankwise',
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              scaffoldMessengerKey: messengerKey,
              theme: buildTheme(Brightness.light, brand),
              darkTheme: buildTheme(Brightness.dark, brand),
              themeMode: theme.mode,
              home: const AuthGate(),
            );
          },
        ),
      ),
    );
  }
}

/// Picks the first screen: sign in, finish the account on the website, or the student / teacher app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    if (session.loading) return const Scaffold(body: LoadingView());

    if (!session.signedIn) {
      final error = session.startupError;
      if (session.hasToken && error != null) {
        return Scaffold(
          body: SafeArea(
            child: ErrorView(message: error, onRetry: session.retryStartup),
          ),
        );
      }
      return const LoginScreen();
    }
    if (session.accountIssue != null) return const AccountIssueScreen();
    if (session.isStudent) return const StudentHome();
    return const TeacherHome();
  }
}
