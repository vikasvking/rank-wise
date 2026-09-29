import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';

/// "You vs Toppers" within one exam (students are only ranked against the same exam).
class RanksTab extends StatefulWidget {
  const RanksTab({super.key});

  @override
  State<RanksTab> createState() => _RanksTabState();
}

class _RanksTabState extends State<RanksTab> {
  String? _exam;

  String _value(J metric, String key) {
    final v = metric.dbl(key);
    if (v == null) return '—';
    return switch (metric.str('key')) {
      'accuracy' => '${fmtNum(v, decimals: 1)}%',
      'avg_seconds' => fmtDuration(v.round()),
      _ => fmtNum(v, decimals: 1),
    };
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Ranks'), actions: const [ThemeToggleButton()]),
      body: Loader<J>(
        key: ValueKey(_exam),
        load: () => api.get('/leaderboard', {'exam': _exam}),
        builder: (context, data, reload) {
          final rank = data.obj('rank');
          final exam = rank.obj('exam');
          final metrics = rank.list('metrics');
          final text = Theme.of(context).textTheme;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (data.list('exams').length > 1)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in data.list('exams'))
                        ChoiceChip(
                          label: Text(e.str('name')),
                          selected: e.str('code') == exam.str('code'),
                          onSelected: (_) => setState(() => _exam = e.str('code')),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Text(examName(exam), style: text.labelLarge),
                        const SizedBox(height: 6),
                        Text(
                          rank.intOrNull('rank') != null ? '#${rank.integer('rank')}' : 'Not ranked yet',
                          style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(rank.intOrNull('rank') != null
                            ? 'of ${rank.integer('students')} students'
                            : 'Answer ${examName(exam)} questions to get a rank'),
                      ],
                    ),
                  ),
                ),
                const SectionTitle('You vs toppers'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Table(
                      columnWidths: const {0: FlexColumnWidth(2.2), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth()},
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(children: [
                          _cell('', bold: true),
                          _cell('You', bold: true),
                          _cell('Top ${rank.integer('top_count')}', bold: true),
                          _cell('Everyone', bold: true),
                        ]),
                        for (final m in metrics)
                          TableRow(children: [
                            _cell('${m.str('label')}${m.str('better') == 'lower' ? ' ↓' : ''}'),
                            _cell(_value(m, 'me'), bold: true),
                            _cell(_value(m, 'top')),
                            _cell(_value(m, 'platform')),
                          ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rank score rewards solving questions on the first try, quickly. ↓ = lower is better. Ranks refresh regularly.',
                  style: text.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cell(String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 13)),
      );
}
