import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'result_screen.dart';
import 'test_runner_screen.dart';

/// My recent tests and practice runs.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('My tests')),
      body: Loader<J>(
        load: () => api.get('/attempts'),
        builder: (context, data, reload) {
          final attempts = data.list('attempts');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (attempts.isEmpty) const EmptyView('No tests or practice runs yet.'),
                for (final a in attempts)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(a.str('kind') == 'test' ? Icons.assignment_outlined : Icons.menu_book_outlined),
                      title: Text(a.str('title')),
                      subtitle: Text([
                        examName(a.obj('exam')),
                        a.str('kind') == 'test' ? (a.flag('retake') ? 'Retake (practice)' : 'Test') : 'Practice',
                        fmtDateTime(a.time('started_at')),
                      ].join(' · ')),
                      trailing: Text(switch (a.str('status')) {
                        'finished' => a.flag('results_released') ? 'Result' : 'Submitted',
                        'blocked' => 'Blocked',
                        _ => 'Resume',
                      }),
                      onTap: () async {
                        final token = a.str('token');
                        final screen = a.str('status') == 'finished' ? ResultScreen(token: token) : TestRunnerScreen(token: token);
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
                        reload();
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
