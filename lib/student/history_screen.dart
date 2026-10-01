import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'result_screen.dart';
import 'test_runner_screen.dart';

/// Every test and practice the student has started, newest first (the website's "My Tests" page):
/// marks and rank once results are out, progress while writing. Each retake is its own line.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _kinds = {
    'all': 'All',
    'tests': 'Teacher tests',
    'practice': 'Topic practice',
  };

  String _kind = 'all';
  final List<J> _attempts = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _attempts.clear();
      _page = 0;
      _hasMore = false;
      _error = null;
      _loading = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final kind = _kind;
    setState(() => _loading = true);
    try {
      final data = await AppScope.read(context).api.get('/attempts', {
        'page': '${_page + 1}',
        if (kind != 'all') 'kind': kind,
      });
      if (!mounted || kind != _kind) return; // the filter changed meanwhile
      setState(() {
        _attempts.addAll(data.list('attempts'));
        _page++;
        _hasMore = data.flag('has_more');
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _pick(String kind) {
    if (kind == _kind) return;
    _kind = kind;
    _reload();
  }

  /// What a line says happened. Older servers send only `status`, so fall back to it.
  static String _state(J a) {
    final state = a.strOrNull('state');
    if (state != null) return state;
    return switch (a.str('status')) {
      'finished' => a.flag('results_released') ? 'done' : 'waiting',
      'blocked' => 'blocked',
      _ => 'in_progress',
    };
  }

  Future<void> _open(J a) async {
    final token = a.str('token');
    final Widget screen;
    switch (_state(a)) {
      case 'done':
      case 'waiting':
        screen = ResultScreen(token: token);
      case 'in_progress':
        screen = TestRunnerScreen(token: token);
      default:
        showSnack(
          context,
          'You were blocked from this test. Ask your teacher to let you continue.',
        );
        return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My tests')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _kinds.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _kind == e.key,
                    onSelected: (_) => _pick(e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null && _attempts.isEmpty)
              ErrorView(message: _error!, onRetry: _reload)
            else if (_loading && _attempts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_attempts.isEmpty)
              EmptyView(switch (_kind) {
                'tests' => 'You haven\'t started a teacher test yet.',
                'practice' => 'You haven\'t practised a topic yet.',
                _ => 'You haven\'t started a test or a practice yet.',
              })
            else ...[
              for (final a in _attempts)
                _AttemptCard(attempt: a, state: _state(a), onTap: () => _open(a)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _loadMore,
                      child: Text(_loading ? 'Loading…' : 'Show more'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({
    required this.attempt,
    required this.state,
    required this.onTap,
  });

  final J attempt;
  final String state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = attempt;
    final rw = context.rw;
    final isTest = a.str('kind') == 'test';
    final retake = a.intOrNull('retake_number');
    final when = a.time('finished_at') ?? a.time('started_at');
    final about = [
      if (isTest) examName(a.obj('exam')),
      if (retake != null) 'Retake $retake, practice' else if (a.flag('retake')) 'Retake, practice',
      '${a.time('finished_at') != null ? 'Submitted' : 'Started'} ${fmtDateTime(when)}',
    ].join(' · ');

    final (String outcome, Color? tone) = switch (state) {
      'done' => (_score(a, isTest), null),
      'waiting' => (
        a.time('release_at') != null
            ? 'Submitted, results at ${fmtDateTime(a.time('release_at'))}'
            : 'Submitted, results after the test closes',
        null,
      ),
      'blocked' => ('Blocked, ask your teacher to let you continue', rw.danger),
      _ => (
        a.intOrNull('total') != null
            ? 'In progress, ${a.integer('answered')} of ${a.integer('total')} answered'
            : 'In progress',
        rw.warning,
      ),
    };
    final action = switch (state) {
      'done' => 'View answers',
      'waiting' => 'Details',
      'blocked' => '',
      _ => 'Resume',
    };
    final rank = a.objOrNull('rank');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isTest ? Icons.assignment_outlined : Icons.menu_book_outlined,
        ),
        title: Text(isTest ? a.str('title') : '${a.str('title')} (topic practice)'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(about),
            const SizedBox(height: 2),
            Text(
              outcome,
              style: TextStyle(
                color: tone,
                fontWeight: state == 'done' ? FontWeight.w600 : null,
              ),
            ),
            if (rank != null)
              Text(
                'Rank ${rank.integer('rank')} of ${rank.integer('of')}',
                style: TextStyle(color: rw.gold, fontWeight: FontWeight.w700),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: action.isEmpty
            ? null
            : Text(
                action,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// "31.3 / 40 · 78% · Passed" for a test, "14 of 20 correct · 70%" for practice
  static String _score(J a, bool isTest) {
    if (a.dbl('marks') == null) return 'Submitted'; // an older server sends no marks
    final pct = '${fmtNum(a.dbl('percentage'), decimals: 1)}%';
    if (!isTest) return '${a.integer('correct')} of ${a.integer('total')} correct · $pct';
    final passed = a['passed'] == null ? null : (a.flag('passed') ? 'Passed' : 'Not passed');
    return [
      '${fmtNum(a.dbl('marks'))} / ${fmtNum(a.dbl('max_marks'))}',
      pct,
      if (passed != null) passed,
    ].join(' · ');
  }
}
