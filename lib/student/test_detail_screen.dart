import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
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

  /// Starts (or resumes) the test. [retake]: another, practice attempt at a test already submitted;
  /// only the first attempt counts for the rank, and retakes are never strict.
  Future<void> _start(J test, {bool retake = false}) async {
    final practice =
        retake || (test.objOrNull('my_attempt')?.flag('retake') ?? false);
    if (test.flag('strict') && !practice) {
      final ok = await confirmDialog(
        context,
        title: 'Strict test',
        message:
            'Stay in the app until you submit. Switching to another app, locking your phone or leaving the test '
            'counts as leaving. The first time is a warning; the second time you are blocked and only your teacher '
            'can let you continue.',
        confirmLabel: 'I understand, start',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _starting = true);
    try {
      final data = await AppScope.read(context).api.post(
        '/tests/${widget.testId}/start',
        retake ? {'retake': true} : null,
      );
      if (!mounted) return;
      final token = data.str('attempt_token');
      if (data.str('status') == 'finished') {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultScreen(token: token)),
        );
      } else {
        if (retake)
          showSnack(
            context,
            data.str(
              'message',
              'Retake started. Your rank stays from your first attempt.',
            ),
          );
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TestRunnerScreen(token: token)),
        );
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
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TestDetailScreen(testId: id)),
      );
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
            if (test.time('starts_at') != null)
              'Opens: ${fmtDateTime(test.time('starts_at'))}',
            if (test.time('ends_at') != null)
              'Closes: ${fmtDateTime(test.time('ends_at'))}. If you start late, you only get the time left until then.',
            'Pass mark: ${test.integer('pass_mark_percentage')}%.',
            test.time('ends_at') != null
                ? 'After it closes you can retake it for practice as often as you like. Only your first attempt counts for your rank.'
                : 'You can retake it for practice as often as you like. Only your first attempt counts for your rank.',
            'Marking (${examName(exam)}): ${exam.str('marking')}',
            'You can move between questions and change answers until you submit. The test is submitted when every question is answered or skipped.',
          ];

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    KindBadge(test),
                    WindowBadge(test),
                    ExamChip(exam),
                    if (test.flag('free_sample'))
                      Pill(
                        'Free sample',
                        icon: Icons.card_giftcard,
                        color: context.rw.promoFg,
                        background: context.rw.promoBg,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(test.str('title'), style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'by ${test.str('author')} · ${windowLabel(test)}',
                  style: TextStyle(color: context.rw.muted),
                ),
                if (rating != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '⭐ ${fmtNum(rating.dbl('average'), decimals: 1)} (${rating.integer('count')} ratings)',
                    style: text.bodySmall,
                  ),
                ],
                if (test.strings('subjects').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Subjects: ${test.strings('subjects').join(', ')}',
                    style: text.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rules',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.rw.strong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final r in rules)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 7,
                                  right: 10,
                                ),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: context.rw.brandFg,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Expanded(child: Text(r)),
                            ],
                          ),
                        ),
                      if (test.flag('strict')) ...[
                        const SizedBox(height: 6),
                        const NoticeBox(
                          tone: NoticeTone.danger,
                          child: Text(
                            'Strict test: stay in the app until you submit. Leaving once is a warning; the second time you are blocked. '
                            'Marks, rank and answers are shown after the test closes.',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (upgrade != null) ...[
                  NoticeBox(
                    tone: NoticeTone.warning,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔒 ${upgrade.str('message')}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        for (final o in upgrade.strings('options'))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(o),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MembershipScreen(),
                      ),
                    ),
                    child: const Text('See upgrade options'),
                  ),
                ] else
                  _action(
                    context,
                    test,
                    attempt,
                    data.strOrNull('blocked_message'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _action(
    BuildContext context,
    J test,
    J? attempt,
    String? blockedMessage,
  ) {
    final rw = context.rw;
    final big = FilledButton.styleFrom(minimumSize: const Size.fromHeight(50));
    final kind = kindStyle(context, kindOfTest(test));
    switch (attempt?.str('status')) {
      case 'blocked':
        return NoticeBox(
          tone: NoticeTone.danger,
          child: Text(
            blockedMessage ??
                'You were blocked from this test. Ask your teacher.',
          ),
        );
      case 'finished':
        return _finishedActions(context, test, attempt!);
      case 'in_progress':
        return FilledButton(
          style: big,
          onPressed: _starting ? null : () => _start(test),
          child: Text(
            attempt!.flag('retake') ? 'Resume retake' : 'Resume test',
          ),
        );
    }
    final coloured = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      backgroundColor: kind.button,
      disabledBackgroundColor: rw.neutralBg,
    );
    if (test.flag('needs_pin')) {
      return FilledButton.icon(
        style: coloured,
        onPressed: _pin,
        icon: const Icon(Icons.lock_outline),
        label: const Text('Enter PIN to start'),
      );
    }
    switch (test.str('window')) {
      case 'upcoming':
        return FilledButton(
          style: big,
          onPressed: null,
          child: Text('Opens ${fmtDateTime(test.time('starts_at'))}'),
        );
      case 'closed':
        return FilledButton(
          style: big,
          onPressed: null,
          child: const Text('Test closed'),
        );
    }
    return FilledButton(
      style: coloured,
      onPressed: _starting ? null : () => _start(test),
      child: Text(_starting ? 'Starting…' : 'Start test'),
    );
  }

  /// A submitted test: Retake (when allowed) and the result.
  Widget _finishedActions(BuildContext context, J test, J attempt) {
    final rw = context.rw;
    final big = FilledButton.styleFrom(minimumSize: const Size.fromHeight(50));
    final canRetake = attempt.flag('can_retake');
    final times = attempt.integer('attempt_count', 1);
    final result = OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(token: attempt.str('token')),
        ),
      ),
      child: Text(
        attempt.flag('results_released')
            ? (attempt.flag('retake') ? 'View last result' : 'View my result')
            : 'Submitted — result after the test closes',
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canRetake) ...[
          FilledButton.icon(
            style: big,
            onPressed: _starting ? null : () => _start(test, retake: true),
            icon: const Icon(Icons.refresh),
            label: Text(_starting ? 'Starting…' : 'Retake test'),
          ),
          const SizedBox(height: 10),
        ],
        result,
        const SizedBox(height: 10),
        Text(
          canRetake
              ? 'Retake as many times as you like${times > 1 ? ' (taken $times times so far)' : ''}. Retakes are practice: your rank stays from your first attempt.'
              : (test.time('ends_at') != null
                    ? 'You can retake this test for practice after it closes at ${fmtDateTime(test.time('ends_at'))}.'
                    : ''),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: rw.muted),
        ),
      ],
    );
  }
}
