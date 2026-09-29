import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/json.dart';
import '../core/theme.dart';
import 'common.dart';

/// Status line for a test's time window.
String windowLabel(J test) {
  final starts = test.time('starts_at');
  final ends = test.time('ends_at');
  switch (test.str('window')) {
    case 'upcoming':
      return 'Opens ${fmtDateTime(starts)}';
    case 'closed':
      return 'Closed ${fmtDateTime(ends)}';
    default:
      return ends != null ? 'Live · closes ${fmtDateTime(ends)}' : 'Live';
  }
}

/// The time badge from the website: amber while a window is open or coming up, grey otherwise.
class WindowBadge extends StatelessWidget {
  const WindowBadge(this.test, {super.key});

  final J test;

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    final ends = test.time('ends_at');
    return switch (test.str('window')) {
      'upcoming' => Pill('Opens ${fmtDateTime(test.time('starts_at'))}', icon: Icons.schedule, color: rw.warning, background: rw.warningBg),
      'closed' => const Pill('Closed'),
      _ => ends != null
          ? Pill('Live until ${fmtDateTime(ends)}', icon: Icons.schedule, color: rw.warning, background: rw.warningBg)
          : const Pill('Available any time'),
    };
  }
}

/// A test as a student sees it in lists (see Api::V1::BaseController#test_card), styled like the website's cards.
class StudentTestCard extends StatelessWidget {
  const StudentTestCard({super.key, required this.test, required this.onTap});

  final J test;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    final style = kindStyle(context, kindOfTest(test));
    final attempt = test.objOrNull('my_attempt');
    final locked = test.flag('locked');
    final subjects = test.strings('subjects');
    final live = test.str('window') == 'live';

    final primary = FilledButton.styleFrom(
      backgroundColor: style.button,
      foregroundColor: Colors.white,
      visualDensity: VisualDensity.compact,
    );
    final secondary = FilledButton.styleFrom(
      backgroundColor: rw.neutralBg,
      foregroundColor: rw.dark ? Colors.white : const Color(0xFF334155),
      visualDensity: VisualDensity.compact,
    );

    Widget status(String label, {Color? color, IconData? icon}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: color ?? rw.faint), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color ?? rw.faint)),
          ],
        );

    final Widget action;
    if (attempt != null) {
      switch (attempt.str('status')) {
        case 'blocked':
          action = status('Blocked — ask your teacher', color: rw.danger, icon: Icons.block);
        case 'finished':
          {
            final times = attempt.integer('attempt_count', 1);
            action = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(style: secondary, onPressed: onTap, child: Text(attempt.flag('results_released') ? 'See result' : 'Submitted')),
                if (attempt.flag('can_retake'))
                  FilledButton.icon(style: primary, onPressed: onTap, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retake')),
                if (times > 1) Text('Taken $times times', style: TextStyle(fontSize: 12, color: rw.faint)),
              ],
            );
          }
        default:
          action = FilledButton(style: primary, onPressed: onTap, child: Text(attempt.flag('retake') ? 'Resume retake' : 'Resume test'));
      }
    } else if (locked) {
      action = test.str('window') == 'closed'
          ? status('Closed')
          : FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: rw.warningBg,
                foregroundColor: rw.warning,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onTap,
              icon: const Icon(Icons.lock_outline, size: 16),
              label: const Text('Upgrade to unlock'),
            );
    } else if (test.str('window') == 'closed') {
      action = status('Missed', icon: Icons.event_busy);
    } else if (test.str('access') == 'pin') {
      action = FilledButton.icon(style: live ? primary : secondary, onPressed: onTap, icon: Icon(style.icon, size: 16), label: const Text('Enter PIN'));
    } else {
      action = FilledButton(style: live ? primary : secondary, onPressed: onTap, child: Text(live ? 'Start test' : 'View details'));
    }

    return SurfaceCard(
      stripe: style.stripe,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              KindBadge(test),
              WindowBadge(test),
              if (test.flag('free_sample')) Pill('Free sample', icon: Icons.card_giftcard, color: rw.promoFg, background: rw.promoBg),
              if (locked) Pill('Plus / Warrior', icon: Icons.lock_outline, color: rw.warning, background: rw.warningBg),
              if (test.str('audience') != 'Everyone' && test.str('audience').isNotEmpty) Pill(test.str('audience'), icon: Icons.group_outlined),
            ],
          ),
          const SizedBox(height: 10),
          Text(test.str('title'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: rw.strong)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ExamChip(test.obj('exam')),
              Text(
                [if (subjects.isNotEmpty) subjects.join(', '), '${test.integer('duration_minutes')} min'].join(' · '),
                style: TextStyle(fontSize: 13, color: rw.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('by ${test.str('author')}', style: TextStyle(fontSize: 12, color: rw.faint)),
          const SizedBox(height: 12),
          action,
        ],
      ),
    );
  }
}
