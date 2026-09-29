import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/test_card.dart';
import 'test_editor_screen.dart';
import 'test_results_screen.dart';

/// The teacher's tests (admins see every test).
class TeacherTestsTab extends StatefulWidget {
  const TeacherTestsTab({super.key});

  @override
  State<TeacherTestsTab> createState() => _TeacherTestsTabState();
}

class _TeacherTestsTabState extends State<TeacherTestsTab> {
  int _version = 0;

  Future<void> _openEditor([int? testId]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => TestEditorScreen(testId: testId)));
    if (saved == true && mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('My tests'), actions: const [ThemeToggleButton()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New test'),
      ),
      body: Loader<J>(
        key: ValueKey(_version),
        load: () => api.get('/teacher/tests'),
        builder: (context, data, reload) {
          final tests = data.list('tests');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (tests.isEmpty) const EmptyView('No tests yet. Tap "New test" to make one, or upload an Excel sheet on the website.'),
                for (final t in tests) _TeacherTestCard(
                  test: t,
                  onOpen: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => TestResultsScreen(testId: t.integer('id'))));
                    reload();
                  },
                  onEdit: t.flag('locked') ? null : () => _openEditor(t.integer('id')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TeacherTestCard extends StatelessWidget {
  const _TeacherTestCard({required this.test, required this.onOpen, required this.onEdit});

  final J test;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pin = test.strOrNull('pin_code');
    final rw = context.rw;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        stripe: kindStyle(context, kindOfTest(test)).stripe,
        onTap: onOpen,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      KindBadge(test),
                      WindowBadge(test),
                      ExamChip(test.obj('exam')),
                      if (test.flag('locked')) const Pill('Locked', icon: Icons.lock_outline),
                      if (test.flag('live_view')) Pill('Live view', icon: Icons.sensors, color: rw.danger, background: rw.dangerBg),
                      if (test.flag('free_sample')) Pill('Free sample', icon: Icons.card_giftcard, color: rw.promoFg, background: rw.promoBg),
                      if (test.str('visibility') != 'public') Pill(test.str('audience'), icon: Icons.group_outlined),
                    ]),
                    const SizedBox(height: 8),
                    Text(test.str('title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: rw.strong)),
                    const SizedBox(height: 2),
                    Text(
                      '${test.integer('question_count')} questions · ${test.integer('duration_minutes')} min · '
                      '${test.integer('attempt_count')} students',
                      style: text.bodySmall,
                    ),
                    Text(windowLabel(test), style: text.bodySmall),
                    if (pin != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: pin));
                            showSnack(context, 'PIN $pin copied');
                          },
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('PIN $pin', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 16, color: rw.brandFg)),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy, size: 16),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
              if (onEdit != null) IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
          ],
        ),
      ),
    );
  }
}
