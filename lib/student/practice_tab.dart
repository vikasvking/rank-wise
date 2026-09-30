import 'package:flutter/material.dart';

import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'topic_screen.dart';

/// Question Bank: every topic with this student's progress.
class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  bool _allExams = false;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        actions: const [ThemeToggleButton()],
      ),
      body: Loader<J>(
        key: ValueKey(_allExams),
        load: () =>
            api.get('/question_bank', {'exams': _allExams ? 'all' : null}),
        builder: (context, data, reload) {
          final topics = data.list('topics');
          final focus = data.strOrNull('focus_topic');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show every exam'),
                  subtitle: Text(
                    data.flag('all_exams')
                        ? 'Showing all exams'
                        : 'Showing your exams',
                  ),
                  value: _allExams,
                  onChanged: (v) => setState(() => _allExams = v),
                ),
                if (data.flag('free_tier'))
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: NoticeBox(
                      tone: NoticeTone.promo,
                      child: Text(
                        '🌱 Free trial: browse every question, and answer the 🎁 sample questions once each. '
                        'Plus and Warrior members practise everything, with timed topic practice.',
                      ),
                    ),
                  ),
                if (focus != null) ...[
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.center_focus_strong_outlined),
                      title: Text('Focus next: $focus'),
                      subtitle: const Text(
                        'Your weakest topic, or the next one to start',
                      ),
                      onTap: () => _open(context, focus, reload),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (topics.isEmpty)
                  const EmptyView(
                    'No questions for your exams yet. Turn on "Show every exam".',
                  ),
                for (final t in topics)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        t.str('name'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: t.integer('progress_pct') / 100,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              '${t.integer('solved')} of ${t.integer('total')} solved',
                              if (t.dbl('accuracy_pct') != null)
                                '${t.dbl('accuracy_pct')}% accuracy',
                              if (t.flag('completed')) '✓ Completed',
                            ].join(' · '),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(context, t.str('name'), reload),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    String topic,
    Future<void> Function() reload,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TopicScreen(topic: topic)),
    );
    reload();
  }
}
