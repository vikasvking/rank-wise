import 'package:flutter/material.dart';

import 'core/json.dart';
import 'core/palette.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/account_issue_screen.dart';
import 'screens/login_screen.dart';
import 'student/student_home.dart';
import 'teacher/teacher_home.dart';
import 'widgets/common.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = AppSession();
  // After signing out (or the token expiring), close every open screen
  session.onSignedOut = () =>
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
  session.restore();
  final theme = ThemeController()..load();
  runApp(RankwiseApp(session: session, theme: theme));
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
