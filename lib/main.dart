import 'package:flutter/material.dart';

import 'core/session.dart';
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
  session.onSignedOut = () => navigatorKey.currentState?.popUntil((route) => route.isFirst);
  session.restore();
  runApp(RankwiseApp(session: session));
}

const Color kBrand = Color(0xFF7A1F3D); // Rankwise burgundy

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kBrand, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class RankwiseApp extends StatelessWidget {
  const RankwiseApp({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: session,
      child: MaterialApp(
        title: 'Rankwise',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const AuthGate(),
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
        return Scaffold(body: SafeArea(child: ErrorView(message: error, onRetry: session.retryStartup)));
      }
      return const LoginScreen();
    }
    if (session.accountIssue != null) return const AccountIssueScreen();
    if (session.isStudent) return const StudentHome();
    return const TeacherHome();
  }
}
