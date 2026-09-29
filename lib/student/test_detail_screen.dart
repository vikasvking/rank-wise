import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import '../widgets/test_card.dart';
import 'membership_screen.dart';
import 'result_screen.dart';
import 'test_runner_screen.dart';
import 'tests_tab.dart';

/// Rules page for one teacher test, with Start / Resume / Result, a PIN prompt, or the upgrade options.
class TestDetailScreen extends StatefulWidget {
  const TestDetailScreen({super.key, required this.testId});

  final int testId;

  @override
  State<TestDetailScreen> createState() => _TestDetailScreenState();
}

class _TestDetailScreenState extends State<TestDetailScreen> {
  int _version = 0;
  bool _starting = false;

  void _reload() => setState(() => _version++);

  Future<void> _start(J test) async {
    if (test.flag('strict')) {
      final ok = await confirmDialog(
        context,
        title: 'Strict test',
        message: 'Stay in the app until you submit. Switching to another app, locking your phone or leaving the test '
            'counts as leaving. The first time is a warning; the second time you are blocked and only your teacher '
            'can let you continue.',
        confirmLabel: 'I understand, start',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _starting = true);
    try {
      final data = await AppScope.read(context).api.post('/tests/${widget.testId}/start');
      if (!mounted) return;
      final token = data.str('attempt_token');
      if (data.str('status') == 'finished') {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(token: token)));
      } else {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => TestRunnerScreen(token: token)));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'pin_required') {
        await _pin();
        return;
      }
      await showMessageDialog(context, 'Cannot start', e.message);
    } finally {
      if (mounted) {
        setState(() => _starting = false);
        _reload();
      }
    }
  }

  Future<void> _pin() async {
    final id = await askForPin(context);
    if (!mounted || id == null) return;
    if (id != widget.testId) {
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TestDetailScreen(testId: id)));
      return;
    }
    showSnack(context, 'PIN accepted');
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Test')),
      body: Loader<J>(
        key: ValueKey(_version),
        load: () => api.get('/tests/${widget.testId}'),
        builder: (context, data, reload) {
          final test = data.obj('test');
          final upgrade = data.objOrNull('upgrade');
          final attempt = test.objOrNull('my_attempt');
          final text = Theme.of(context).textTheme;
          final rating = test.objOrNull('rating');
          final exam = test.obj('exam');

          final rules = <String>[
            '${test.integer('question_count')} questions',
            'Time limit: ${test.integer('duration_minutes')} minutes from when you press Start. The test submits itself when time runs out.',
            if (test.time('starts_at') != null) 'Opens: ${fmtDateTime(test.time('starts_at'))}',
            if (test.time('ends_at') != null) 'Closes: ${fmtDateTime(test.time('ends_at'))}. If you start late, you only get the time left until then.',
            'Pass mark: ${test.integer('pass_mark_percentage')}%. You can take this test once.',
            'Marking (${examName(exam)}): ${exam.str('marking')}',
            'You can move between questions and change answers until you submit. The test is submitted when every question is answered or skipped.',
          ];

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Pill(examName(exam)),
                  if (test.flag('strict')) const Pill('Strict', icon: Icons.shield_outlined),
                  if (test.str('access') == 'pin') const Pill('PIN', icon: Icons.pin_outlined),
                  if (test.flag('free_sample')) const Pill('🎁 Free sample'),
                ]),
                const SizedBox(height: 10),
                Text(test.str('title'), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('by ${test.str('author')} · ${windowLabel(test)}', style: text.bodyMedium),
                if (rating != null) ...[
                  const SizedBox(height: 4),
                  Text('⭐ ${fmtNum(rating.dbl('average'), decimals: 1)} (${rating.integer('count')} ratings)', style: text.bodySmall),
                ],
                if (test.strings('subjects').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Subjects: ${test.strings('subjects').join(', ')}', style: text.bodySmall),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rules', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        for (final r in rules)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('•  '),
                              Expanded(child: Text(r)),
                            ]),
                          ),
                        if (test.flag('strict'))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '🛡️ Strict test: stay in the app until you submit. Leaving once is a warning; the second time you are blocked. '
                              'Marks, rank and answers are shown after the test closes.',
                              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (upgrade != null) ...[
                  NoticeBox(
                    tone: NoticeTone.warning,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🔒 ${upgrade.str('message')}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        for (final o in upgrade.strings('options'))
                          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(o)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen())),
                    child: const Text('See upgrade options'),
                  ),
                ] else
                  _action(context, test, attempt, data.strOrNull('blocked_message')),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _action(BuildContext context, J test, J? attempt, String? blockedMessage) {
    final big = FilledButton.styleFrom(minimumSize: const Size.fromHeight(48));
    switch (attempt?.str('status')) {
      case 'blocked':
        return NoticeBox(tone: NoticeTone.danger, child: Text(blockedMessage ?? 'You were blocked from this test. Ask your teacher.'));
      case 'finished':
        return FilledButton(
          style: big,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(token: attempt!.str('token')))),
          child: Text(attempt!.flag('results_released') ? 'View my result' : 'Submitted — result after the test closes'),
        );
      case 'in_progress':
        return FilledButton(style: big, onPressed: _starting ? null : () => _start(test), child: const Text('Resume test'));
    }
    if (test.flag('needs_pin')) {
      return FilledButton.icon(style: big, onPressed: _pin, icon: const Icon(Icons.pin_outlined), label: const Text('Enter PIN to start'));
    }
    switch (test.str('window')) {
      case 'upcoming':
        return FilledButton(style: big, onPressed: null, child: Text('Opens ${fmtDateTime(test.time('starts_at'))}'));
      case 'closed':
        return FilledButton(style: big, onPressed: null, child: const Text('Test closed'));
    }
    return FilledButton(
      style: big,
      onPressed: _starting ? null : () => _start(test),
      child: Text(_starting ? 'Starting…' : 'Start test'),
    );
  }
}
