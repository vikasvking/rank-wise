import 'package:flutter/material.dart';

import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';

/// Shown when the account still needs a step that is done on the website:
/// profile details, a parent's consent (under 18), or admin approval (new teachers).
class AccountIssueScreen extends StatefulWidget {
  const AccountIssueScreen({super.key});

  @override
  State<AccountIssueScreen> createState() => _AccountIssueScreenState();
}

class _AccountIssueScreenState extends State<AccountIssueScreen> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      await AppScope.read(context).refreshUser();
    } catch (e) {
      if (mounted) showSnack(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final issue = session.accountIssue ?? <String, dynamic>{};
    final code = issue.str('code');
    final path = switch (code) {
      'profile_incomplete' => '/profile/edit',
      'parent_consent_needed' => '/parent_consent/new',
      _ => '/pending_approval',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('One more step')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(code == 'pending_approval' ? Icons.hourglass_top : Icons.assignment_ind_outlined,
              size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(issue.str('message'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          if (code != 'pending_approval')
            FilledButton(onPressed: () => openWebsite(context, path), child: const Text('Finish on the website')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _checking ? null : _check,
            child: Text(_checking ? 'Checking…' : "I've done it — check again"),
          ),
          const SizedBox(height: 24),
          TextButton(onPressed: session.signOut, child: const Text('Sign out')),
        ],
      ),
    );
  }
}
