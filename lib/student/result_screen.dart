import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';

/// Marks, rank and the answer review for one finished test or practice.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Loader<J>(
        load: () => api.get('/attempts/$token/result'),
        builder: (context, data, reload) {
          final attempt = data.obj('attempt');
          if (!data.flag('released')) {
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.lock_clock, size: 56),
                  const SizedBox(height: 16),
                  Text('Test submitted', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    '${data.str('message')}\nResults open ${fmtDateTime(data.time('release_at'))}.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final s = data.obj('summary');
          final rank = data.objOrNull('rank');
          final review = data.list('review');
          final passed = s['passed'];
          final scheme = Theme.of(context).colorScheme;
          final text = Theme.of(context).textTheme;

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(attempt.str('title'), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${examName(attempt.obj('exam'))} marking: ${attempt.obj('exam').str('marking')}', style: text.bodySmall),
                const SizedBox(height: 16),
                if (rank != null) ...[
                  Card(
                    color: scheme.tertiaryContainer,
                    child: ListTile(
                      leading: Text(
                        switch (rank.integer('rank')) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '🏅' },
                        style: const TextStyle(fontSize: 30),
                      ),
                      title: Text('Rank #${rank.integer('rank')} of ${rank.integer('of')}',
                          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Equal marks → less time ranks higher. Your rank can change as more students submit.'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TileGrid(children: [
                  StatTile(label: 'Marks', value: '${fmtNum(s.dbl('marks'))} / ${fmtNum(s.dbl('max_marks'))}'),
                  StatTile(
                    label: passed == null ? 'Score' : (passed == true ? 'Passed' : 'Not passed'),
                    value: '${fmtNum(s.dbl('percentage'), decimals: 1)}%',
                    color: passed == null ? null : (passed == true ? Colors.green.shade700 : scheme.error),
                  ),
                  StatTile(label: 'Correct', value: '${s.integer('correct')}', color: Colors.green.shade700),
                  StatTile(label: 'Wrong', value: '${s.integer('wrong')}', color: scheme.error),
                  StatTile(label: 'Skipped / not answered', value: '${s.integer('skipped')} / ${s.integer('unattempted')}'),
                  StatTile(label: 'Time taken', value: fmtDuration(s.intOrNull('time_taken'))),
                ]),
                const SectionTitle('Answer review'),
                for (final q in review) _ReviewCard(question: q),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.question});

  final J question;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mine = question.strOrNull('my_choice');
    final correctAnswer = question.str('correct_answer');
    final options = question.obj('options');
    final right = question.flag('correct');
    final status = mine == null
        ? ('Not answered', scheme.outline)
        : mine == 'SKIPPED'
            ? ('Skipped', scheme.outline)
            : right
                ? ('Correct', Colors.green.shade700)
                : ('Wrong', scheme.error);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Q${question.integer('number')}', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(status.$1, style: TextStyle(color: status.$2, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(question.str('content'), style: text.bodyLarge),
            const SizedBox(height: 8),
            for (final letter in const ['A', 'B', 'C', 'D'])
              if (options.str(letter).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$letter. ${options.str(letter)}'
                    '${letter == correctAnswer ? '  ✓' : ''}${letter == mine && letter != correctAnswer ? '  ✗ your answer' : ''}',
                    style: TextStyle(
                      color: letter == correctAnswer
                          ? Colors.green.shade700
                          : (letter == mine ? scheme.error : null),
                      fontWeight: letter == correctAnswer || letter == mine ? FontWeight.w700 : null,
                    ),
                  ),
                ),
            if (question.str('explanation').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Explanation', style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(question.str('explanation'), style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
