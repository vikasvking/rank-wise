import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/test_card.dart';

/// Results of one test: ranking, averages, blocked students; plus the live view for strict tests.
class TestResultsScreen extends StatefulWidget {
  const TestResultsScreen({super.key, required this.testId});

  final int testId;

  @override
  State<TestResultsScreen> createState() => _TestResultsScreenState();
}

class _TestResultsScreenState extends State<TestResultsScreen> {
  int _version = 0;

  Future<void> _reinstate(J student) async {
    final ok = await confirmDialog(
      context,
      title: 'Let ${student.str('name')} continue?',
      message:
          'The time spent blocked is given back, but never beyond the closing time.',
      confirmLabel: 'Reinstate',
    );
    if (!ok || !mounted) return;
    try {
      final data = await AppScope.read(context).api.post(
        '/teacher/tests/${widget.testId}/reinstate',
        {'attempt_id': student.integer('attempt_id')},
      );
      if (!mounted) return;
      showSnack(context, data.str('message'));
      setState(() => _version++);
    } catch (e) {
      if (mounted) showSnack(context, messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Loader<J>(
      key: ValueKey(_version),
      load: () => api.get('/teacher/tests/${widget.testId}/results'),
      builder: (context, data, reload) {
        final test = data.obj('test');
        final strict = test.flag('strict');
        final results = _ResultsTab(
          data: data,
          onRefresh: reload,
          onReinstate: _reinstate,
        );
        if (!strict) {
          return Scaffold(
            appBar: AppBar(title: Text(test.str('title'))),
            body: results,
          );
        }
        return DefaultTabController(
          length: 2,
          initialIndex: test.flag('live_view') ? 1 : 0,
          child: Scaffold(
            appBar: AppBar(
              title: Text(test.str('title')),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Results'),
                  Tab(text: '🔴 Live'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                results,
                _LiveTab(testId: widget.testId, onReinstate: _reinstate),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResultsTab extends StatelessWidget {
  const _ResultsTab({
    required this.data,
    required this.onRefresh,
    required this.onReinstate,
  });

  final J data;
  final Future<void> Function() onRefresh;
  final Future<void> Function(J student) onReinstate;

  @override
  Widget build(BuildContext context) {
    final test = data.obj('test');
    final results = data.list('results');
    final blocked = data.list('blocked');
    final rating = data.objOrNull('rating');
    final questions = data.list('questions'); // question-wise analysis
    final topics = data.list('topics');
    final exportPath = data.strOrNull('export_path');
    final reportPath = data.strOrNull('report_path');
    final pin = test.strOrNull('pin_code');
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${examName(test.obj('exam'))} · ${windowLabel(test)}',
            style: text.bodyMedium,
          ),
          if (pin != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: pin));
                  showSnack(
                    context,
                    'PIN $pin copied — share it with your students',
                  );
                },
                icon: const Icon(Icons.copy),
                label: Text(
                  'PIN $pin',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TileGrid(
            children: [
              StatTile(
                label: 'Submitted',
                value: '${data.integer('participants')}',
              ),
              StatTile(
                label: 'Still writing',
                value: '${data.integer('in_progress')}',
              ),
              StatTile(
                label: 'Average marks',
                value: fmtNum(data.dbl('average_marks')),
              ),
              StatTile(
                label: 'Average score',
                value: '${fmtNum(data.dbl('average_pct'), decimals: 1)}%',
              ),
            ],
          ),
          if (rating != null) ...[
            const SizedBox(height: 8),
            Text(
              '⭐ ${fmtNum(rating.dbl('average'), decimals: 1)} from ${rating.integer('count')} student ratings',
              style: text.bodySmall,
            ),
          ],
          if (exportPath != null || reportPath != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (exportPath != null)
                  OutlinedButton.icon(
                    onPressed: () => openWebsite(context, exportPath),
                    icon: const Icon(Icons.download),
                    label: const Text('Excel (CSV)'),
                  ),
                if (reportPath != null)
                  OutlinedButton.icon(
                    onPressed: () => openWebsite(context, reportPath),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Printable report / PDF'),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Opens on the website (sign in there if asked).',
                style: text.bodySmall,
              ),
            ),
          ],
          if (blocked.isNotEmpty) ...[
            const SectionTitle('🚫 Blocked students'),
            for (final b in blocked)
              Card(
                color: scheme.errorContainer,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(b.str('name')),
                  subtitle: Text(
                    '${b.str('reason')}\n${fmtDateTime(b.time('blocked_at'))}',
                  ),
                  isThreeLine: true,
                  trailing: b.flag('in_progress')
                      ? FilledButton(
                          onPressed: () => onReinstate(b),
                          child: const Text('Reinstate'),
                        )
                      : null,
                ),
              ),
          ],
          SectionTitle('Rankings (${results.length})'),
          if (results.isEmpty) const EmptyView('No submissions yet.'),
          for (final r in results)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${r.integer('rank')}')),
                title: Text(r.str('name')),
                subtitle: Text(
                  '✓ ${r.integer('correct')}  ✗ ${r.integer('wrong')}  – ${r.integer('skipped') + r.integer('unattempted')}'
                  ' · ${fmtDuration(r.intOrNull('time_taken'))}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${fmtNum(r.dbl('marks'))} / ${fmtNum(r.dbl('max_marks'))}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${fmtNum(r.dbl('percentage'), decimals: 1)}% ${r.flag('passed') ? 'pass' : 'fail'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: r.flag('passed')
                            ? context.rw.success
                            : context.rw.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (results.isNotEmpty && questions.isNotEmpty) ...[
            const SectionTitle('Question-wise analysis'),
            if (topics.length > 1) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in topics)
                    Chip(
                      label: Text(
                        '${t.str('topic')} · ${fmtNum(t.dbl('correct_pct'), decimals: 1)}%',
                      ),
                      side: BorderSide(
                        color: _scoreColor(context, t.dbl('correct_pct')),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Topics from weakest to strongest',
                  style: text.bodySmall,
                ),
              ),
            ],
            for (final q in questions) _QuestionStatCard(stat: q),
            Text(
              'Letters are the question\'s own; strict tests showed each student the options in a different order.',
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Red under 40% correct, amber under 70%, green otherwise
Color _scoreColor(BuildContext context, double? pct) {
  final p = pct ?? 0;
  if (p < 40) return context.rw.danger;
  if (p < 70) return context.rw.warning;
  return context.rw.success;
}

/// One question of the analysis: share correct, wrong and skipped, and the wrong option most students chose
class _QuestionStatCard extends StatelessWidget {
  const _QuestionStatCard({required this.stat});

  final J stat;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = stat.dbl('correct_pct') ?? 0;
    final color = _scoreColor(context, pct);
    final wrong = stat.objOrNull('common_wrong');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    '${stat.integer('number')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stat.str('content'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${fmtNum(pct, decimals: 1)}%',
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0, 1).toDouble(),
                minHeight: 6,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Answer ${stat.str('correct_answer')} · ✓ ${stat.integer('correct')} of ${stat.integer('students')}'
              ' · ✗ ${stat.integer('wrong')} · skipped ${stat.integer('skipped')} · not attempted ${stat.integer('unattempted')}',
              style: text.bodySmall,
            ),
            if (wrong != null)
              Text(
                'Most chosen wrong: ${wrong.str('letter')} (${wrong.integer('count')} students) ${wrong.str('text')}',
                style: text.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// Strict tests: who is writing, silent, blocked or done. Refreshes every 15 seconds.
class _LiveTab extends StatefulWidget {
  const _LiveTab({required this.testId, required this.onReinstate});

  final int testId;
  final Future<void> Function(J student) onReinstate;

  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
  J? _data;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await AppScope.read(
        context,
      ).api.get('/teacher/tests/${widget.testId}/live');
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    }
  }

  static (String, Color) _label(Rw rw, String status) => switch (status) {
    'writing' => ('🟢 Writing', rw.success),
    'opening' => ('🟢 Opening test', rw.success),
    'no_signal' => ('🟡 No signal', rw.warning),
    'blocked' => ('🚫 Blocked', rw.danger),
    'submitted' => ('✅ Submitted', rw.muted),
    _ => (status, rw.faint),
  };

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      final error = _error;
      return error == null
          ? const LoadingView()
          : ErrorView(message: error, onRetry: _load);
    }
    final counts = data.obj('counts');
    final rows = data.list('rows');
    final notStarted = data.list('not_started');
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!data.flag('live'))
            const NoticeBox(
              child: Text(
                'This test has closed. The live view shows the final state.',
              ),
            ),
          Text(
            'Updated ${fmtTime(data.time('refreshed_at'))} · refreshes every 15 seconds',
            style: text.bodySmall,
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 10),
          TileGrid(
            columns: 3,
            children: [
              StatTile(
                label: 'Writing',
                value:
                    '${counts.integer('writing') + counts.integer('opening')}',
                color: context.rw.success,
                tone: StatTone.success,
              ),
              StatTile(
                label: 'No signal',
                value: '${counts.integer('no_signal')}',
                color: context.rw.warning,
              ),
              StatTile(
                label: 'Blocked',
                value: '${counts.integer('blocked')}',
                color: context.rw.danger,
                tone: StatTone.danger,
              ),
              StatTile(
                label: 'Submitted',
                value: '${counts.integer('submitted')}',
              ),
              StatTile(
                label: 'Not started',
                value: '${counts.integer('not_started')}',
              ),
              StatTile(
                label: 'Questions',
                value: '${data.integer('total_questions')}',
              ),
            ],
          ),
          const SectionTitle('Students'),
          if (rows.isEmpty) const EmptyView('Nobody has started yet.'),
          for (final r in rows)
            Builder(
              builder: (context) {
                final label = _label(context.rw, r.str('status'));
                final details = <String>[
                  '${r.integer('answered')} of ${data.integer('total_questions')} answered',
                  if (r.integer('leave_count') > 0)
                    '${r.integer('leave_count')} warning(s)',
                  if (r.str('status') == 'no_signal')
                    'silent ${fmtDuration(r.intOrNull('seconds_silent'))}',
                  if (r.intOrNull('seconds_left') != null &&
                      r.str('status') != 'submitted')
                    '${fmtDuration(r.intOrNull('seconds_left'))} left',
                  if (r.str('status') == 'blocked') r.str('block_reason'),
                ];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(r.str('name')),
                    subtitle: Text(details.join(' · ')),
                    trailing: r.str('status') == 'blocked'
                        ? FilledButton(
                            onPressed: () async {
                              await widget.onReinstate(r);
                              _load();
                            },
                            child: const Text('Reinstate'),
                          )
                        : Text(
                            label.$1,
                            style: TextStyle(
                              color: label.$2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                );
              },
            ),
          if (notStarted.isNotEmpty) ...[
            const SectionTitle('Entered the PIN, not started'),
            for (final n in notStarted)
              ListTile(
                dense: true,
                title: Text(n.str('name')),
                subtitle: Text(
                  'PIN entered ${fmtTime(n.time('pin_entered_at'))}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
