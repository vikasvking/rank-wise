import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'membership_screen.dart';
import 'test_runner_screen.dart';

/// Every question in one topic. Tap an option to answer; the answer and explanation appear afterwards.
class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key, required this.topic});

  final String topic;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  static const _filters = {
    'all': 'All',
    'not_attempted': 'Not attempted',
    'wrong': 'Wrong',
    'solved': 'Solved',
  };

  String _filter = 'all';
  final Map<int, J> _updated = {}; // questions answered on this screen
  final Map<int, bool> _lastResult = {};
  final Set<int> _busy = {};
  final Map<int, DateTime> _shownAt = {};

  Future<void> _answer(J question, String choice) async {
    final id = question.integer('id');
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    final started = _shownAt[id] ?? DateTime.now();
    try {
      final data = await AppScope.read(context).api
          .post('/question_bank/answer', {
            'question_id': id,
            'choice': choice,
            'duration_seconds': DateTime.now().difference(started).inSeconds,
          });
      if (!mounted) return;
      setState(() {
        _updated[id] = data.obj('question');
        _lastResult[id] = data.flag('correct');
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'free_limit') {
        await showMessageDialog(context, 'Free trial', e.message);
      } else {
        showSnack(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _timedPractice() async {
    try {
      final data = await AppScope.read(
        context,
      ).api.post('/practice', {'topic': widget.topic});
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TestRunnerScreen(token: data.str('attempt_token')),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'upgrade_required') {
        final go = await confirmDialog(
          context,
          title: 'Plus and Warrior only',
          message: e.message,
          confirmLabel: 'See options',
        );
        if (go && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MembershipScreen()),
          );
        }
      } else {
        showSnack(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    final free = AppScope.of(context).user?.str('tier') == 'free';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic),
        actions: [
          if (!free)
            TextButton.icon(
              onPressed: _timedPractice,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Practice run'),
            ),
        ],
      ),
      body: Loader<J>(
        key: ValueKey(_filter),
        load: () {
          _updated.clear();
          _lastResult.clear();
          return api.get('/question_bank/topic', {
            'name': widget.topic,
            'filter': _filter,
          });
        },
        builder: (context, data, reload) {
          final topic = data.obj('topic');
          final counts = data.obj('filter_counts');
          final questions = data.list('questions');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  '${topic.integer('solved')} of ${topic.integer('total')} solved · ${topic.integer('attempts')} attempts'
                  '${topic.dbl('accuracy_pct') != null ? ' · ${topic.dbl('accuracy_pct')}% accuracy' : ''}',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final f in _filters.entries)
                      ChoiceChip(
                        label: Text('${f.value} (${counts.integer(f.key)})'),
                        selected: _filter == f.key,
                        onSelected: (_) => setState(() => _filter = f.key),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (questions.isEmpty)
                  const EmptyView('No questions match this filter.'),
                for (final q in questions)
                  Builder(
                    builder: (context) {
                      final id = q.integer('id');
                      _shownAt.putIfAbsent(id, DateTime.now);
                      return _PracticeCard(
                        question: _updated[id] ?? q,
                        number: q.integer('number'),
                        lastResult: _lastResult[id],
                        busy: _busy.contains(id),
                        onAnswer: (choice) => _answer(q, choice),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.question,
    required this.number,
    required this.lastResult,
    required this.busy,
    required this.onAnswer,
  });

  final J question;
  final int number;
  final bool? lastResult;
  final bool busy;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final options = question.obj('options');
    final correct = question.strOrNull(
      'correct_answer',
    ); // only after an attempt
    final last = question.strOrNull('last_choice');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: lastResult == null
            ? BorderSide(color: context.rw.border)
            : BorderSide(
                color: lastResult! ? context.rw.success : context.rw.danger,
                width: 2,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Q$number',
                  style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                if (question.flag('solved'))
                  Pill(
                    'Solved',
                    icon: Icons.check,
                    color: context.rw.success,
                    background: context.rw.successBg,
                  ),
                if (!question.flag('solved') &&
                    question.integer('attempts') > 0)
                  Text(
                    'Not solved yet',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const Spacer(),
                if (question.strOrNull('year') != null)
                  Text(question.str('year'), style: text.labelSmall),
              ],
            ),
            if (lastResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  lastResult! ? '🎉 Correct!' : '❌ Not quite.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: lastResult! ? context.rw.success : context.rw.danger,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(question.str('content'), style: text.bodyLarge),
            const SizedBox(height: 8),
            for (final letter in const ['A', 'B', 'C', 'D'])
              if (options.str(letter).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      foregroundColor: correct == letter
                          ? context.rw.success
                          : (last == letter
                                ? context.rw.danger
                                : context.rw.body),
                      backgroundColor: correct == letter
                          ? context.rw.successBg
                          : (last == letter ? context.rw.dangerBg : null),
                      side: BorderSide(
                        color: correct == letter
                            ? context.rw.success.withAlpha(110)
                            : (last == letter
                                  ? context.rw.danger.withAlpha(110)
                                  : context.rw.border),
                      ),
                    ),
                    onPressed: busy ? null : () => onAnswer(letter),
                    child: Text('$letter.  ${options.str(letter)}'),
                  ),
                ),
            if (correct != null) ...[
              const SizedBox(height: 4),
              Text(
                'Your last answer: ${last ?? '—'} · Correct answer: $correct',
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (question.str('explanation').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(question.str('explanation'), style: text.bodySmall),
              ],
            ] else
              Text(
                'Answer and explanation appear after you attempt this question.',
                style: text.bodySmall?.copyWith(color: scheme.outline),
              ),
          ],
        ),
      ),
    );
  }
}
