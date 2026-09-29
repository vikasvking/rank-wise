import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import '../widgets/test_card.dart';
import 'membership_screen.dart';
import 'test_detail_screen.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.onOpenTests, required this.onOpenRanks});

  final VoidCallback onOpenTests;
  final VoidCallback onOpenRanks;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Rankwise')),
      body: Loader<J>(
        load: () => api.get('/dashboard'),
        builder: (context, data, reload) {
          final user = data.obj('user');
          final stats = data.obj('stats');
          final tests = data.list('latest_tests');
          final rank = data.obj('rank');
          final scheme = Theme.of(context).colorScheme;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text('Hello, ${user.str('name')} 👋', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Pill(user.str('tier_label')),
                    const SizedBox(width: 8),
                    if (user.str('tier') != 'warrior')
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipScreen())),
                        child: const Text('Upgrade'),
                      ),
                  ],
                ),
                if (user.str('tier') == 'free') ...[
                  const SizedBox(height: 8),
                  const NoticeBox(
                    child: Text("🌱 You're on the free trial: the 🎁 sample tests and sample questions, each once. "
                        'Join your school\'s plan (Plus) or become a Warrior to unlock everything.'),
                  ),
                ],
                const SizedBox(height: 16),
                _StreakCard(streak: data.integer('streak_days'), target: data.integer('daily_target', 25), week: data.list('week')),
                const SizedBox(height: 12),
                TileGrid(children: [
                  StatTile(label: 'Accuracy', value: '${fmtNum(stats.dbl('accuracy_pct'), decimals: 1)}%'),
                  StatTile(label: 'Question bank done', value: '${stats.integer('completion_pct')}%'),
                  StatTile(label: 'Solved', value: '${stats.integer('solved')}', color: Colors.green.shade700),
                  StatTile(label: 'Still wrong', value: '${stats.integer('wrong')}', color: scheme.error),
                ]),
                SectionTitle('Latest tests', trailing: TextButton(onPressed: onOpenTests, child: const Text('View all'))),
                if (tests.isEmpty) const EmptyView('No live or upcoming tests for your exams right now.'),
                for (final t in tests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StudentTestCard(
                      test: t,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => TestDetailScreen(testId: t.integer('id'))));
                        reload();
                      },
                    ),
                  ),
                SectionTitle('Your rank · ${examName(rank.obj('exam'))}', trailing: TextButton(onPressed: onOpenRanks, child: const Text('Details'))),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events_outlined),
                    title: Text(rank.intOrNull('rank') != null
                        ? 'Rank #${rank.integer('rank')} of ${rank.integer('students')}'
                        : 'Not ranked yet'),
                    subtitle: Text(rank.intOrNull('rank') != null
                        ? 'Among students practising ${examName(rank.obj('exam'))}'
                        : 'Answer questions in ${examName(rank.obj('exam'))} to get a rank.'),
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

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.target, required this.week});

  final int streak;
  final int target;
  final List<J> week;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔥 $streak day${streak == 1 ? '' : 's'} streak',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('$target answers a day keep the streak going.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final day in week)
                  Column(
                    children: [
                      Text(day.str('day_name'), style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: day.flag('target_met')
                            ? Colors.green.shade600
                            : (day.integer('solved') > 0 ? scheme.secondaryContainer : scheme.surfaceContainerHighest),
                        child: Text(
                          '${day.integer('solved')}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: day.flag('today') ? FontWeight.w800 : FontWeight.w500,
                            color: day.flag('target_met') ? Colors.white : scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
