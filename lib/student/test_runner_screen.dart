import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/json.dart';
import '../core/screen_guard.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

/// Taking a test or a topic practice.
///
/// Strict tests: the app sends a heartbeat every few seconds while it is open, and tells the server how long
/// it was in the background when it comes back (the server decides: ignore, warn, or block). Another app
/// holding the screen for a while (split screen, a chat bubble) counts as leaving too, and screenshots
/// are blocked on Android.
///
/// Teacher tests stay open until the student submits (or time runs out), so answers can be checked and
/// questions marked for review; topic practice still submits itself after the last question.
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
  final Set<int> _marked = {}; // question ids marked for review
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
  DateTime? _leftAt; // the app went to the background
  DateTime? _inactiveAt; // another app or window took focus (split screen, chat bubble, call screen...)
  int _leaveCount = 0;

  /// Another app holding the focus for this long counts as leaving a strict test; shorter is ignored
  /// (pulling down the notification shade, a quick system dialog).
  static const _otherAppAfter = Duration(seconds: 15);
  final Stopwatch _watch = Stopwatch();

  String get _base => '/attempts/${widget.token}';
  bool get _strict => _attempt.flag('strict');
  bool get _isTest => _attempt.str('kind') == 'test'; // a teacher test, not topic practice
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
    ScreenGuard.secure(false);
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
      final marked = data.ints('marked');
      setState(() {
        _attempt = attempt;
        _questions = questions;
        _answers
          ..clear()
          ..addAll({
            for (final e in answers.entries)
              int.tryParse(e.key) ?? -1: e.value.toString(),
          });
        _marked
          ..clear()
          ..addAll(marked);
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
      if (_strict) ScreenGuard.secure(true);
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
  int? _nextOpen() =>
      _nextWhere((id) => !_answers.containsKey(id));

  /// Next question marked for review after the current one, wrapping round.
  int? _nextMarked() => _nextWhere(_marked.contains);

  int? _nextWhere(bool Function(int id) test) {
    final n = _questions.length;
    for (var step = 1; step < n; step++) {
      final i = (_index + step) % n;
      if (test(_questions[i].integer('id'))) return i;
    }
    return null;
  }

  /// After saving: the next unanswered question; once all are answered, the next one marked for review.
  void _moveOn() {
    final open = _nextOpen();
    if (open != null) {
      setState(() => _show(open));
      return;
    }
    final marked = _nextMarked();
    showSnack(
      context,
      marked != null
          ? 'All questions answered. Here is the next one you marked for review.'
          : _marked.isEmpty
          ? 'All questions answered. Check any answer from the grid, then submit.'
          : 'All questions answered. ${_marked.length} still marked for review.',
    );
    setState(() => _show(marked ?? _index));
  }

  // ---------- answering ----------

  /// Saves an answer (or a skip). On teacher tests "Save & next" also clears a review mark ([mark] false),
  /// and "Mark for review & next" keeps one ([mark] true); a skip leaves the mark as it is.
  Future<void> _save(String choice, {bool? mark}) async {
    final q = _question;
    if (q == null || _saving) return;
    setState(() => _saving = true);
    try {
      final data = await AppScope.read(context).api.post('$_base/answer', {
        'question_id': q.integer('id'),
        'choice': choice,
        'duration_seconds': _watch.elapsed.inSeconds,
        if (_isTest && mark != null) 'marked': mark,
      });
      if (!mounted) return;
      _answers[q.integer('id')] = choice;
      if (data['marked'] is List) {
        _marked
          ..clear()
          ..addAll(data.ints('marked'));
      }
      if (data.flag('finished')) {
        showSnack(context, data.str('message', 'Test submitted.'));
        return _goToResult();
      }
      _moveOn();
    } on ApiException catch (e) {
      if (!mounted) return;
      _handleError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "Mark for review & next": saves the chosen option too, if there is one.
  Future<void> _markAndNext() async {
    final selected = _selected;
    if (selected != null) return _save(selected, mark: true);
    final q = _question;
    if (q == null || _saving) return;
    setState(() => _saving = true);
    try {
      final data = await AppScope.read(context).api.post('$_base/mark', {
        'question_id': q.integer('id'),
        'marked': true,
      });
      if (!mounted) return;
      _marked
        ..clear()
        ..addAll(data.ints('marked'));
      final next = _nextOpen() ?? _nextMarked();
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
    final marked = _questions
        .where((q) => _marked.contains(q.integer('id')))
        .length;
    final left = [
      if (open > 0) '$open question${open == 1 ? '' : 's'} not answered',
      if (marked > 0) '$marked marked for review',
    ];
    final ok = await confirmDialog(
      context,
      title: 'Submit test?',
      message: left.isEmpty
          ? 'You have answered every question. You cannot change answers after submitting.'
          : 'You still have ${left.join(' and ')}. You cannot change answers after submitting.',
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

  /// In the background, or another app has had the focus for a while: no heartbeats then, so the
  /// server sees the silence even if the student never comes back.
  bool get _away {
    final inactive = _inactiveAt;
    return _leftAt != null ||
        (inactive != null &&
            DateTime.now().difference(inactive) >= _otherAppAfter);
  }

  Future<void> _sendHeartbeat() async {
    if (_done || _away) return;
    try {
      final data = await AppScope.read(context).api.post('$_base/heartbeat');
      if (mounted) _applyStrictState(data);
    } catch (_) {
      // a missed heartbeat is fine; the server only blocks after a long silence
    }
  }

  // Going to another app: resumed -> inactive -> hidden -> paused. Split screen, a chat bubble or a call
  // screen taking the focus: resumed -> inactive only (the test stays visible but is not in use).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_strict || _done || _loading) return;
    final now = DateTime.now();
    switch (state) {
      case AppLifecycleState.inactive:
        _inactiveAt ??= now;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _leftAt ??= _inactiveAt ?? now;
      case AppLifecycleState.resumed:
        final left = _leftAt;
        final inactive = _inactiveAt;
        _leftAt = null;
        _inactiveAt = null;
        if (left != null) {
          _reportLeave(now.difference(left).inSeconds);
        } else if (inactive != null &&
            now.difference(inactive) >= _otherAppAfter) {
          _reportLeave(
            now.difference(inactive).inSeconds,
            kind: 'other_app_on_screen',
          );
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _reportLeave(int seconds, {String kind = 'background'}) async {
    try {
      final data = await AppScope.read(
        context,
      ).api.post('$_base/report_leave', {'seconds': seconds, 'kind': kind});
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
                Text(
                  _isTest
                      ? 'Filled = answered · outlined = skipped · empty = not yet · dot = marked for review'
                      : 'Filled = answered · outlined = skipped · empty = not yet',
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
                              final id = _questions[i].integer('id');
                              final a = _answers[id];
                              final answered = a != null && a != 'SKIPPED';
                              return Badge(
                                isLabelVisible: _marked.contains(id),
                                smallSize: 10,
                                backgroundColor: Colors.deepPurple,
                                child: SizedBox(
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
    final marked = _marked.contains(q.integer('id'));
    // On strict tests the server sends the options already shuffled for this student, under A-D
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
              if (marked)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '🚩 Marked for review',
                    style: text.labelMedium?.copyWith(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                            : () => _save(_selected!, mark: false),
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
                Row(
                  children: [
                    if (_isTest)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _saving ? null : _markAndNext,
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text('Mark for review'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.deepPurple,
                          ),
                        ),
                      ),
                    Expanded(
                      child: TextButton(
                        onPressed: _saving ? null : _submit,
                        child: Text(
                          'Submit · $answeredCount of ${_questions.length}',
                        ),
                      ),
                    ),
                  ],
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
