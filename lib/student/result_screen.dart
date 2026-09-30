import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'test_runner_screen.dart';

/// Marks, rank and the answer review for one finished test or practice.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.token});

  final String token;

  /// Another (practice) go at the same teacher test; only the first attempt is ranked.
  Future<void> _retake(BuildContext context, int testId) async {
    try {
      final data = await AppScope.read(
        context,
      ).api.post('/tests/$testId/start', {'retake': true});
      if (!context.mounted) return;
      showSnack(
        context,
        data.str(
          'message',
          'Retake started. Your rank stays from your first attempt.',
        ),
      );
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TestRunnerScreen(token: data.str('attempt_token')),
        ),
      );
    } catch (e) {
      if (context.mounted)
        await showMessageDialog(context, 'Cannot retake', messageOf(e));
    }
  }

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
                  Text(
                    'Test submitted',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
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
          final rw = context.rw;
          final text = Theme.of(context).textTheme;
          final retake = attempt.flag('retake');
          final testId = attempt.intOrNull('test_id');

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(attempt.str('title'), style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  '${examName(attempt.obj('exam'))} marking: ${attempt.obj('exam').str('marking')}',
                  style: text.bodySmall,
                ),
                if (data.flag('can_retake') && testId != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    onPressed: () => _retake(context, testId),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake test'),
                  ),
                ],
                const SizedBox(height: 16),
                if (retake) ...[
                  NoticeBox(
                    child: Text(
                      'Practice retake — this attempt scored ${fmtNum(s.dbl('marks'))} / ${fmtNum(s.dbl('max_marks'))} marks'
                      '${s.intOrNull('time_taken') != null ? ' in ${fmtDuration(s.intOrNull('time_taken'))}' : ''}. '
                      'It does not change your rank${rank != null ? ', which comes from your first attempt' : ''}.',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (rank != null) ...[
                  _RankBox(
                    rank: rank,
                    firstAttempt: rank.flag('from_first_attempt'),
                  ),
                  const SizedBox(height: 12),
                ],
                TileGrid(
                  children: [
                    StatTile(
                      label: 'Marks',
                      value:
                          '${fmtNum(s.dbl('marks'))} / ${fmtNum(s.dbl('max_marks'))}',
                    ),
                    StatTile(
                      label: passed == null
                          ? 'Score'
                          : (passed == true ? 'Passed' : 'Not passed'),
                      value: '${fmtNum(s.dbl('percentage'), decimals: 1)}%',
                      color: passed == null
                          ? null
                          : (passed == true ? rw.success : rw.danger),
                    ),
                    StatTile(
                      label: 'Correct',
                      value: '${s.integer('correct')}',
                      color: rw.success,
                      tone: StatTone.success,
                    ),
                    StatTile(
                      label: 'Wrong',
                      value: '${s.integer('wrong')}',
                      color: rw.danger,
                      tone: StatTone.danger,
                    ),
                    StatTile(
                      label: 'Skipped / not answered',
                      value:
                          '${s.integer('skipped')} / ${s.integer('unattempted')}',
                    ),
                    StatTile(
                      label: 'Time taken',
                      value: fmtDuration(s.intOrNull('time_taken')),
                    ),
                  ],
                ),
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

/// The website's amber "Your rank" box.
class _RankBox extends StatelessWidget {
  const _RankBox({required this.rank, required this.firstAttempt});

  final J rank;
  final bool firstAttempt;

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    final place = rank.integer('rank');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rw.goldBorder),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [rw.goldBg, rw.card],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstAttempt ? 'Your rank (first attempt)' : 'Your rank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: rw.gold,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (place >= 1 && place <= 3)
                Text(
                  '${const ['🥇', '🥈', '🥉'][place - 1]} ',
                  style: const TextStyle(fontSize: 28),
                ),
              Text(
                '#$place',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  color: rw.strong,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'of ${rank.integer('of')}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: rw.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            firstAttempt
                ? 'Only your first attempt is ranked. Equal marks → less time ranks higher.'
                : 'Equal marks → less time ranks higher. Your rank can change as more students submit.',
            style: TextStyle(fontSize: 12, color: rw.muted),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.question});

  final J question;

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    final mine = question.strOrNull('my_choice');
    final correctAnswer = question.str('correct_answer');
    final options = question.obj('options');
    final right = question.flag('correct');
    final (label, color, background) = mine == null
        ? ('Not answered', rw.neutralFg, rw.neutralBg)
        : mine == 'SKIPPED'
        ? ('Skipped', rw.neutralFg, rw.neutralBg)
        : right
        ? ('Correct', rw.success, rw.successBg)
        : ('Wrong', rw.danger, rw.dangerBg);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Q${question.integer('number')}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: rw.strong,
                  ),
                ),
                const SizedBox(width: 8),
                Pill(label, color: color, background: background),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.str('content'),
              style: TextStyle(fontSize: 15, color: rw.strong, height: 1.4),
            ),
            const SizedBox(height: 10),
            for (final letter in const ['A', 'B', 'C', 'D'])
              if (options.str(letter).isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: letter == correctAnswer
                        ? rw.successBg
                        : (letter == mine ? rw.dangerBg : null),
                    border: Border.all(
                      color: letter == correctAnswer
                          ? rw.success.withAlpha(90)
                          : (letter == mine
                                ? rw.danger.withAlpha(90)
                                : rw.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$letter.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: rw.muted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          options.str(letter),
                          style: TextStyle(
                            color: letter == correctAnswer
                                ? rw.success
                                : (letter == mine ? rw.danger : rw.body),
                            fontWeight:
                                letter == correctAnswer || letter == mine
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (letter == correctAnswer)
                        Icon(Icons.check_circle, size: 18, color: rw.success),
                      if (letter == mine && letter != correctAnswer)
                        Icon(Icons.cancel, size: 18, color: rw.danger),
                    ],
                  ),
                ),
            if (question.str('explanation').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Explanation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: rw.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                question.str('explanation'),
                style: TextStyle(fontSize: 13, color: rw.body),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
