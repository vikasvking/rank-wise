import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/test_card.dart';
import 'test_editor_screen.dart';
import 'test_results_screen.dart';

/// The teacher's tests (admins see every test): one exam at a time, 50 at a time as you scroll.
class TeacherTestsTab extends StatefulWidget {
  const TeacherTestsTab({super.key});

  @override
  State<TeacherTestsTab> createState() => _TeacherTestsTabState();
}

class _TeacherTestsTabState extends State<TeacherTestsTab> {
  final List<J> _tests = [];
  List<J> _exams = []; // [{code, name, count}] - exams that have tests
  String? _exam; // null = every exam
  int? _nextPage = 1;
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  /// Starts the list again from page 1 (after a filter change, a pull to refresh or a saved test).
  Future<void> _reset() async {
    _tests.clear();
    _nextPage = 1;
    await _loadMore(force: true);
  }

  Future<void> _loadMore({bool force = false}) async {
    final page = _nextPage;
    if (page == null || (_loading && !force)) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AppScope.read(context).api.get('/teacher/tests', {
        'exam': _exam,
        'page': page,
      });
      if (!mounted || request != _request) return;
      setState(() {
        _tests.addAll(data.list('tests'));
        _exams = data.list('exams');
        _nextPage = data.intOrNull('next_page');
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = messageOf(e));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _pickExam(String? code) {
    if (_exam == code) return;
    _exam = code;
    _reset();
  }

  Future<void> _openEditor([int? testId]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TestEditorScreen(testId: testId)),
    );
    if (saved == true && mounted) _reset();
  }

  Future<void> _openResults(J test) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestResultsScreen(testId: test.integer('id')),
      ),
    );
    if (mounted) _reset();
  }

  @override
  Widget build(BuildContext context) {
    final total = _exams.fold<int>(0, (sum, e) => sum + e.integer('count'));
    return Scaffold(
      appBar: AppBar(
        title: const Text('My tests'),
        actions: const [ThemeToggleButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New test'),
      ),
      body: Column(
        children: [
          if (_exams.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                children: [
                  ChoiceChip(
                    label: Text('All exams ($total)'),
                    selected: _exam == null,
                    onSelected: (_) => _pickExam(null),
                  ),
                  for (final e in _exams) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('${e.str('name')} (${e.integer('count')})'),
                      selected: _exam == e.str('code'),
                      onSelected: (on) => _pickExam(on ? e.str('code') : null),
                    ),
                  ],
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reset,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                    _loadMore();
                  }
                  return false;
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: _tests.length + 1,
                  itemBuilder: (context, i) {
                    if (i == _tests.length) {
                      if (_loading) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (_tests.isEmpty && _error == null) {
                        return EmptyView(
                          _exam == null
                              ? 'No tests yet. Tap "New test" to make one, or upload an Excel sheet on the website.'
                              : 'No tests for this exam yet.',
                        );
                      }
                      return const SizedBox(height: 24);
                    }
                    final t = _tests[i];
                    return _TeacherTestCard(
                      test: t,
                      onOpen: () => _openResults(t),
                      onEdit: t.flag('locked')
                          ? null
                          : () => _openEditor(t.integer('id')),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherTestCard extends StatelessWidget {
  const _TeacherTestCard({
    required this.test,
    required this.onOpen,
    required this.onEdit,
  });

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
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      KindBadge(test),
                      WindowBadge(test),
                      ExamChip(test.obj('exam')),
                      if (test.flag('locked'))
                        const Pill('Locked', icon: Icons.lock_outline),
                      if (test.flag('live_view'))
                        Pill(
                          'Live view',
                          icon: Icons.sensors,
                          color: rw.danger,
                          background: rw.dangerBg,
                        ),
                      if (test.flag('free_sample'))
                        Pill(
                          'Free sample',
                          icon: Icons.card_giftcard,
                          color: rw.promoFg,
                          background: rw.promoBg,
                        ),
                      if (test.str('visibility') != 'public')
                        Pill(test.str('audience'), icon: Icons.group_outlined),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    test.str('title'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: rw.strong,
                    ),
                  ),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PIN $pin',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: rw.brandFg,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy, size: 16),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
              ),
          ],
        ),
      ),
    );
  }
}
