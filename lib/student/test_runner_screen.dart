import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// Taking a test or a topic practice.
///
/// Strict tests: the app sends a heartbeat every few seconds while it is open, and tells the server how long
/// it was in the background when it comes back (the server decides: ignore, warn, or block).
class TestRunnerScreen extends StatefulWidget {
  const TestRunnerScreen({super.key, required this.token});

  final String token;

  @override
  State<TestRunnerScreen> createState() => _TestRunnerScreenState();
}

class _TestRunnerScreenState extends State<TestRunnerScreen>
    with WidgetsBindingObserver {
  J _attempt = <String, dynamic>{};
  List<J> _questions = <J>[];
  final Map<int, String> _answers = {}; // question id -> "A".."D" or "SKIPPED"
  int _index = 0;
  String? _selected;
  bool _loading = true;
  bool _saving = false;
  bool _done =
      false; // leaving this screen (result, blocked, or the student went back)
  String? _error;

  DateTime? _deadline;
  Timer? _tick;
  Timer? _heartbeat;
  DateTime? _leftAt;
  int _leaveCount = 0;
  final Stopwatch _watch = Stopwatch();

  String get _base => '/attempts/${widget.token}';
  bool get _strict => _attempt.flag('strict');
  J? get _question => _questions.isEmpty ? null : _questions[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _tick?.cancel();
    _heartbeat?.cancel();
    _watch.stop();
  }

  // ---------- loading ----------

  Future<void> _load() async {
    try {
      final data = await AppScope.read(context).api.get(_base);
      if (!mounted) return;
      final attempt = data.obj('attempt');
      final questions = data.list('questions');
      final answers = data.obj('answers');
      setState(() {
        _attempt = attempt;
        _questions = questions;
        _answers
          ..clear()
          ..addAll({
            for (final e in answers.entries)
              int.tryParse(e.key) ?? -1: e.value.toString(),
          });
        _leaveCount = attempt.integer('leave_count');
        final seconds = attempt.intOrNull('seconds_left');
        _deadline = seconds == null
            ? null
            : DateTime.now().add(Duration(seconds: seconds));
        final firstOpen = _questions.indexWhere(
          (q) => !_answers.containsKey(q.integer('id')),
        );
        _loading = false;
        _show(firstOpen < 0 ? 0 : firstOpen);
      });
      _startTimers();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'finished') return _goToResult();
      if (e.code == 'blocked') return _showBlocked(e.message);
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _startTimers() {
    if (_deadline != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _done) return;
        if (_secondsLeft <= 0) {
          _timeUp();
        } else {
          setState(() {});
        }
      });
    }
    if (_strict) {
      final every = _attempt.integer('heartbeat_every', 15);
      _heartbeat = Timer.periodic(
        Duration(seconds: every),
        (_) => _sendHeartbeat(),
      );
      _sendHeartbeat();
    }
  }

  int get _secondsLeft {
    final d = _deadline;
    if (d == null) return 0;
    final s = d.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  // ---------- navigation between questions ----------

  void _show(int index) {
    _index = index;
    final q = _question;
    final saved = q == null ? null : _answers[q.integer('id')];
    _selected = saved == 'SKIPPED' ? null : saved;
    _watch
      ..reset()
      ..start();
  }

  void _goTo(int index) => setState(() => _show(index));

  /// Next question without an answer after the current one, wrapping round (as on the website).
  int? _nextOpen() {
    final n = _questions.length;
    for (var step = 1; step < n; step++) {
      final i = (_index + step) % n;
      if (!_answers.containsKey(_questions[i].integer('id'))) return i;
    }
    return null;
  }

  // ---------- answering ----------

  Future<void> _save(String choice) async {
    final q = _question;
    if (q == null || _saving) return;
    setState(() => _saving = true);
    try {
      final data = await AppScope.read(context).api.post('$_base/answer', {
        'question_id': q.integer('id'),
        'choice': choice,
        'duration_seconds': _watch.elapsed.inSeconds,
      });
      if (!mounted) return;
      _answers[q.integer('id')] = choice;
      if (data.flag('finished')) {
        showSnack(context, data.str('message', 'Test submitted.'));
        return _goToResult();
      }
      final next = _nextOpen();
      setState(() => _show(next ?? _index));
    } on ApiException catch (e) {
      if (!mounted) return;
      _handleError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    final open = _questions
        .where((q) => !_answers.containsKey(q.integer('id')))
        .length;
    final ok = await confirmDialog(
      context,
      title: 'Submit test?',
      message: open == 0
          ? 'You have answered every question.'
          : '$open question${open == 1 ? '' : 's'} still unanswered. You cannot change answers after submitting.',
      confirmLabel: 'Submit',
    );
    if (!ok || !mounted) return;
    try {
      await AppScope.read(context).api.post('$_base/finish');
      if (mounted) _goToResult();
    } on ApiException catch (e) {
      if (mounted) _handleError(e);
    }
  }

  Future<void> _timeUp() async {
    if (_done) return;
    _stopTimers();
    try {
      await AppScope.read(context).api.post('$_base/finish');
    } catch (_) {
      // the server submits expired tests by itself
    }
    if (!mounted) return;
    showSnack(context, 'Time is up. Your test was submitted automatically.');
    _goToResult();
  }

  void _handleError(ApiException e) {
    switch (e.code) {
      case 'finished':
        _goToResult();
      case 'blocked':
        _showBlocked(e.message);
      default:
        showSnack(context, e.message);
    }
  }

  void _goToResult() {
    if (_done) return;
    _done = true;
    _stopTimers();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(token: widget.token)),
    );
  }

  Future<void> _showBlocked(String message) async {
    if (_done) return;
    _done = true;
    _stopTimers();
    await showMessageDialog(context, '🚫 Blocked', message);
    if (mounted) Navigator.pop(context);
  }

  // ---------- strict mode ----------

  Future<void> _sendHeartbeat() async {
    if (_done || _leftAt != null)
      return; // no heartbeats while the app is in the background
    try {
      final data = await AppScope.read(context).api.post('$_base/heartbeat');
      if (mounted) _applyStrictState(data);
    } catch (_) {
      // a missed heartbeat is fine; the server only blocks after a long silence
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_strict || _done || _loading) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null) _reportLeave(DateTime.now().difference(left).inSeconds);
    }
  }

  Future<void> _reportLeave(int seconds) async {
    try {
      final data = await AppScope.read(
        context,
      ).api.post('$_base/report_leave', {'seconds': seconds});
      if (mounted) _applyStrictState(data);
    } catch (_) {
      // offline: the next heartbeat will tell
    }
  }

  void _applyStrictState(J data) {
    switch (data.str('status')) {
      case 'blocked':
        _showBlocked(
          data.str(
            'message',
            'You were blocked from this test for leaving it. Ask your teacher to reinstate you.',
          ),
        );
      case 'finished':
        _goToResult();
      case 'ok':
        final count = data.integer('leave_count', _leaveCount);
        if (count > _leaveCount && !_done) {
          _leaveCount = count;
          setState(
            () => _attempt['warnings_left'] = data.integer('warnings_left'),
          );
          showMessageDialog(
            context,
            '⚠️ You left the test',
            'Leaving the app during a strict test is recorded. If you leave again, you will be blocked and only your teacher can let you continue.',
          );
        }
    }
  }

  // ---------- UI ----------

  Future<void> _confirmLeave() async {
    final ok = await confirmDialog(
      context,
      title: 'Leave the test?',
      message: _strict
          ? 'Your answers are saved, but this is a strict test: if this screen stays closed for more than about 90 seconds you will be blocked.'
          : 'Your answers are saved and you can resume later. ${_deadline != null ? 'The timer keeps running.' : ''}',
      confirmLabel: 'Leave',
      destructive: _strict,
    );
    if (ok && mounted) {
      _done = true;
      _stopTimers();
      Navigator.pop(context);
    }
  }

  void _openPalette() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Questions', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 4),
                const Text(
                  'Filled = answered · outlined = skipped · empty = not yet',
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _questions.length; i++)
                          Builder(
                            builder: (_) {
                              final a = _answers[_questions[i].integer('id')];
                              final answered = a != null && a != 'SKIPPED';
                              return SizedBox(
                                width: 44,
                                height: 44,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: answered
                                        ? scheme.primary
                                        : null,
                                    foregroundColor: answered
                                        ? scheme.onPrimary
                                        : null,
                                    side: BorderSide(
                                      color: i == _index
                                          ? scheme.tertiary
                                          : (a == 'SKIPPED'
                                                ? scheme.primary
                                                : scheme.outlineVariant),
                                      width: i == _index ? 3 : 1,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _goTo(i);
                                  },
                                  child: Text('${i + 1}'),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done || _loading || _error != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _attempt.str('title', 'Test'),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_deadline != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Pill(
                    fmtClock(_secondsLeft),
                    icon: Icons.timer_outlined,
                    color: _secondsLeft < 60
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ),
            if (_questions.isNotEmpty)
              IconButton(
                onPressed: _openPalette,
                icon: const Icon(Icons.grid_view),
                tooltip: 'All questions',
              ),
          ],
        ),
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const LoadingView();
    final error = _error;
    if (error != null) {
      return ErrorView(
        message: error,
        onRetry: () {
          setState(() {
            _error = null;
            _loading = true;
          });
          _load();
        },
      );
    }
    final q = _question;
    if (q == null) return const EmptyView('This test has no questions yet.');

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final answeredCount = _answers.length;
    final saved = _answers[q.integer('id')];
    final options = q.obj('options');

    return Column(
      children: [
        LinearProgressIndicator(
          value: _questions.isEmpty ? 0 : answeredCount / _questions.length,
        ),
        if (_strict)
          Container(
            width: double.infinity,
            color: scheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '🛡️ Strict test — stay in the app. Warnings left: ${_attempt.integer('warnings_left')}',
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Question ${_index + 1} of ${_questions.length}${q.str('topic').isNotEmpty ? ' · ${q.str('topic')}' : ''}',
                style: text.labelLarge?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 8),
              Text(
                q.str('content'),
                style: text.titleMedium?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              for (final letter in const ['A', 'B', 'C', 'D'])
                if (options.str(letter).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionTile(
                      letter: letter,
                      text: options.str(letter),
                      selected: _selected == letter,
                      onTap: _saving
                          ? null
                          : () => setState(() => _selected = letter),
                    ),
                  ),
              if (saved != null)
                Text(
                  saved == 'SKIPPED'
                      ? 'You skipped this question earlier.'
                      : 'Saved answer: $saved. Pick another option and save to change it.',
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton.outlined(
                      onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save('SKIPPED'),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _saving || _selected == null
                            ? null
                            : () => _save(_selected!),
                        child: Text(_saving ? 'Saving…' : 'Save & next'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: _index < _questions.length - 1
                          ? () => _goTo(_index + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next',
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(
                    'Submit test · $answeredCount of ${_questions.length} answered',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: selected
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
