import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../student/history_screen.dart';
import '../student/membership_screen.dart';
import '../widgets/common.dart';
import 'notification_settings.dart';
import 'profile_edit_screen.dart';

/// "Me" tab for students and teachers.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final user = session.user ?? <String, dynamic>{};
    final student = session.isStudent;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: const [ThemeToggleButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await session.refreshUser();
          } catch (e) {
            if (context.mounted) showSnack(context, messageOf(e));
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: context.rw.brandSoft,
                  foregroundColor: context.rw.brandFg,
                  child: Text(
                    _initial(user.str('name')),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.str('name'),
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(user.str('email_address'), style: text.bodySmall),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          Pill(switch (user.str('role')) {
                            'admin' => 'Admin',
                            'teacher' => 'Teacher',
                            _ => 'Student',
                          }),
                          if (student) Pill(user.str('tier_label')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.rw.strong,
                    ),
                  ),
                  Text(
                    'Light, dark, or follow your phone',
                    style: TextStyle(fontSize: 12, color: context.rw.faint),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: double.infinity,
                    child: ThemeModePicker(),
                  ),
                ],
              ),
            ),
            if (student) ...[
              const SizedBox(height: 12),
              const NotificationSettingsCard(),
            ],
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit profile'),
                    subtitle: Text(
                      student
                          ? 'Name and the exams you are preparing for'
                          : 'Name and the subjects you teach',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileEditScreen(),
                      ),
                    ),
                  ),
                  if (student) ...[
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('My tests and practice'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('Membership'),
                      subtitle: Text(user.str('tier_label')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MembershipScreen(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('Open the website'),
                    subtitle: Text(
                      student
                          ? 'Password, email, schools and parent consent'
                          : 'Excel uploads, batches, schools, password and admin pages',
                    ),
                    onTap: () => openWebsite(context, '/profile'),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.logout,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Sign out',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Sign out?',
                        message: 'You can sign in again any time.',
                        confirmLabel: 'Sign out',
                      );
                      if (ok) await session.signOut();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connected to $kSiteUrl',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _initial(String name) =>
    name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
