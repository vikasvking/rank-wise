import 'package:flutter/material.dart';

import '../core/json.dart';
import '../core/push.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Students' push notification switches, under Me (saved on the server: PATCH /me/notifications).
class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  State<NotificationSettingsCard> createState() => _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard> {
  static const _switches = [
    ('new_tests', 'New tests', 'When a teacher adds a test for you'),
    ('results', 'Results', 'When a strict test closes and your rank is out'),
    ('reminders', 'Daily reminder', 'In the evening, if today\'s 25 questions are not done yet'),
  ];

  String? _saving;

  Future<void> _set(String key, bool value) async {
    final session = AppScope.read(context);
    setState(() => _saving = key);
    try {
      final data = await session.api.patch('/me/notifications', {key: value});
      session.setUser(data.obj('user')); // also updates the phone's topics (see PushService)
    } catch (e) {
      if (mounted) showSnack(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    final settings = AppScope.of(context).user?.obj('notifications') ?? <String, dynamic>{};
    final push = PushService.instance;
    final note = push == null || !push.available
        ? 'Notifications are not set up in this version of the app.'
        : (push.asked && !push.permitted ? 'Notifications are blocked for Lakshyank. Allow them in your phone\'s settings to get these.' : null);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600, color: rw.strong)),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Text(note, style: TextStyle(fontSize: 12, color: rw.warning)),
            ),
          const SizedBox(height: 4),
          for (final (key, title, subtitle) in _switches)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: rw.faint)),
              value: settings[key] != false,
              onChanged: _saving == null ? (v) => _set(key, v) : null,
            ),
        ],
      ),
    );
  }
}
