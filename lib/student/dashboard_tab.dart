import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/test_card.dart';
import 'membership_screen.dart';
import 'test_detail_screen.dart';

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.onOpenTests,
    required this.onOpenRanks,
    required this.onOpenPractice,
  });

  final VoidCallback onOpenTests;
  final VoidCallback onOpenRanks;
  final VoidCallback onOpenPractice;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle(),
        actions: const [ThemeToggleButton(), SizedBox(width: 4)],
      ),
      body: Loader<J>(
        load: () => api.get('/dashboard'),
        builder: (context, data, reload) {
          final rw = context.rw;
          final user = data.obj('user');
          final stats = data.obj('stats');
          final tests = data.list('latest_tests');
          final rank = data.obj('rank');
          final streak = data.integer('streak_days');
          final target = data.integer('daily_target', 25);
          final week = data.list('week');
          final today = week.isEmpty ? 0 : week.last.integer('solved');
          final left = (target - today).clamp(0, target);
          final now = DateTime.now();
          final greeting = now.hour >= 5 && now.hour < 12
              ? 'Good morning'
              : (now.hour >= 12 && now.hour < 17
                    ? 'Good afternoon'
                    : 'Good evening');
          final firstName = user.str('name').trim().split(RegExp(r'\s+')).first;
          final ranked = rank.intOrNull('rank') != null;
          final exam = examName(rank.obj('exam'));

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                Text(
                  '${_weekdays[now.weekday - 1]}, ${now.day} ${_monthNames[now.month - 1]}',
                  style: TextStyle(fontSize: 13, color: rw.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  firstName.isEmpty ? greeting : '$greeting, $firstName',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: rw.strong,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (streak > 0) "You're on a $streak-day streak.",
                    left == 0
                        ? "Today's target of $target questions is done 🎉"
                        : '$left more question${left == 1 ? '' : 's'} to reach today\'s target.',
                  ].join(' '),
                  style: TextStyle(color: rw.muted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: onOpenPractice,
                      child: const Text('Continue practice'),
                    ),
                    Pill(
                      user.str('tier_label'),
                      icon: Icons.workspace_premium_outlined,
                    ),
                    if (user.str('tier') != 'warrior')
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MembershipScreen(),
                          ),
                        ),
                        child: const Text('Upgrade'),
                      ),
                  ],
                ),
                if (user.str('tier') == 'free') ...[
                  const SizedBox(height: 14),
                  const NoticeBox(
                    tone: NoticeTone.promo,
                    child: Text(
                      "🌱 You're on the free trial: the sample tests and sample questions, each once. "
                      "Join your school's plan (Plus) or become a Warrior to unlock everything.",
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TileGrid(
                  children: [
                    StatTile(
                      label: 'Questions solved',
                      value: '${stats.integer('solved')}',
                      sub:
                          '${stats.integer('completion_pct')}% of the question bank',
                    ),
                    StatTile(
                      label: 'Accuracy',
                      value:
                          '${fmtNum(stats.dbl('accuracy_pct'), decimals: 1)}%',
                      sub: '${stats.integer('wrong')} still wrong',
                    ),
                    StatTile(
                      label: 'Streak',
                      value: '$streak day${streak == 1 ? '' : 's'}',
                      sub: '$target+ questions a day',
                    ),
                    GestureDetector(
                      onTap: onOpenRanks,
                      child: StatTile(
                        label: 'Rank · $exam',
                        value: ranked ? '#${rank.integer('rank')}' : '—',
                        sub: ranked
                            ? 'of ${rank.integer('students')} $exam students'
                            : 'Answer a $exam question to get ranked',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _WeekCard(target: target, week: week),
                SectionTitle(
                  'Available tests',
                  trailing: TextButton(
                    onPressed: onOpenTests,
                    child: const Text('View all'),
                  ),
                ),
                if (tests.isEmpty)
                  const EmptyView(
                    'No live or upcoming tests for your exams right now.',
                    icon: Icons.event_available_outlined,
                  ),
                for (final t in tests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: StudentTestCard(
                      test: t,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TestDetailScreen(testId: t.integer('id')),
                          ),
                        );
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

/// The last seven days: answers per day, green once the day's target is met.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.target, required this.week});

  final int target;
  final List<J> week;

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This week',
            style: TextStyle(fontWeight: FontWeight.w600, color: rw.strong),
          ),
          Text(
            '$target answers a day keep the streak going.',
            style: TextStyle(fontSize: 12, color: rw.faint),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in week)
                Column(
                  children: [
                    Text(
                      day.str('day_name'),
                      style: TextStyle(
                        fontSize: 11,
                        color: day.flag('today') ? rw.brandFg : rw.faint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: day.flag('target_met')
                            ? rw.success
                            : (day.integer('solved') > 0
                                  ? rw.brandSoft
                                  : rw.neutralBg),
                        border: day.flag('today')
                            ? Border.all(color: rw.brandFg, width: 1.5)
                            : null,
                      ),
                      child: Text(
                        '${day.integer('solved')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: day.flag('today')
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: day.flag('target_met')
                              ? (rw.dark ? Colors.black : Colors.white)
                              : (day.integer('solved') > 0
                                    ? rw.brandFg
                                    : rw.muted),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
