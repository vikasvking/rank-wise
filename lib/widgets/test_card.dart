import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/json.dart';
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

/// A test as a student sees it in lists (see Api::V1::BaseController#test_card).
class StudentTestCard extends StatelessWidget {
  const StudentTestCard({super.key, required this.test, required this.onTap});

  final J test;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final attempt = test.objOrNull('my_attempt');
    final locked = test.flag('locked');
    final subjects = test.strings('subjects');

    String action;
    IconData icon;
    if (attempt != null) {
      switch (attempt.str('status')) {
        case 'blocked':
          action = 'Blocked — ask your teacher';
          icon = Icons.block;
        case 'finished':
          action = attempt.flag('results_released') ? 'See result' : 'Submitted';
          icon = Icons.task_alt;
        default:
          action = 'Resume test';
          icon = Icons.play_arrow;
      }
    } else if (locked) {
      action = test.str('window') == 'closed' ? 'Closed' : 'Upgrade to unlock';
      icon = Icons.lock_outline;
    } else if (test.str('window') == 'closed') {
      action = 'Missed';
      icon = Icons.event_busy;
    } else if (test.str('access') == 'pin') {
      action = 'Enter PIN';
      icon = Icons.pin_outlined;
    } else {
      action = test.str('window') == 'live' ? 'Start test' : 'View details';
      icon = Icons.play_arrow;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill(examName(test.obj('exam'))),
                  if (test.flag('strict')) const Pill('Strict', icon: Icons.shield_outlined),
                  if (test.str('access') == 'pin' && !test.flag('strict')) const Pill('PIN', icon: Icons.pin_outlined),
                  if (test.flag('free_sample')) const Pill('🎁 Free sample'),
                  if (locked) Pill('Plus / Warrior', icon: Icons.lock_outline, color: scheme.tertiary),
                  if (test.str('audience') != 'Everyone' && test.str('audience').isNotEmpty) Pill(test.str('audience')),
                ],
              ),
              const SizedBox(height: 8),
              Text(test.str('title'), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                [
                  if (subjects.isNotEmpty) subjects.join(', '),
                  '${test.integer('duration_minutes')} min',
                  'by ${test.str('author')}',
                ].join(' · '),
                style: text.bodySmall,
              ),
              const SizedBox(height: 2),
              Text(windowLabel(test), style: text.bodySmall?.copyWith(color: scheme.outline)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(icon, size: 18, color: locked ? scheme.tertiary : scheme.primary),
                  const SizedBox(width: 6),
                  Text(action, style: TextStyle(fontWeight: FontWeight.w600, color: locked ? scheme.tertiary : scheme.primary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
