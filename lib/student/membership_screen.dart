import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';

/// Free, Plus or Warrior: what the student has, and how to get more.
class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: Loader<J>(
        load: () => api.get('/membership'),
        builder: (context, data, reload) {
          final tier = data.str('tier');
          final text = Theme.of(context).textTheme;
          final scheme = Theme.of(context).colorScheme;
          final samplesT = data.obj('sample_tests');
          final samplesQ = data.obj('sample_questions');
          final schools = data.list('schools');
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('You are ${data.str('tier_label')}', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (data.time('tier_until') != null) Text('Until ${fmtDate(data.time('tier_until'))}'),
                const SizedBox(height: 8),
                if (tier == 'free')
                  Text('Sample tests taken: ${samplesT.integer('taken')} of ${samplesT.integer('total')} · '
                      'Sample questions answered: ${samplesQ.integer('answered')} of ${samplesQ.integer('total')}'),
                if (tier == 'plus')
                  Text('Exams included for you: ${data.strings('allowed_exams').join(', ')}. Become a Warrior to use every exam.'),
                if (schools.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Through: ${schools.map((s) => '${s.str('name')} (${s.str('plan')})').join(', ')}'),
                ],
                const SizedBox(height: 16),
                for (final plan in data.list('plans'))
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: plan.str('key') == tier ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(plan.str('name'), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                              const Spacer(),
                              if (plan.str('key') == tier) const Pill('Your plan'),
                            ],
                          ),
                          Text(plan.str('price'), style: text.titleSmall?.copyWith(color: scheme.primary)),
                          const SizedBox(height: 8),
                          for (final p in plan.strings('points')) Text('✓  $p'),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                NoticeBox(child: Text(data.str('how_to_upgrade'))),
              ],
            ),
          );
        },
      ),
    );
  }
}
