import 'package:flutter/material.dart';

import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';

/// Name, plus exams (students) or subjects (teachers). Email, password and date of birth stay on the website.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _subjects;
  late List<String> _exams;
  String? _target;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = AppScope.read(context).user ?? <String, dynamic>{};
    _name = TextEditingController(text: user.str('name'));
    _subjects = TextEditingController(text: user.strings('subjects').join(', '));
    _exams = user.strings('exam_codes');
    _target = user.strOrNull('target_exam');
  }

  @override
  void dispose() {
    _name.dispose();
    _subjects.dispose();
    super.dispose();
  }

  Future<void> _save(bool student) async {
    if (student && _exams.isEmpty) {
      showSnack(context, 'Pick at least one exam you are preparing for.');
      return;
    }
    setState(() => _saving = true);
    final session = AppScope.read(context);
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        if (student) 'exam_codes': _exams,
        if (student && _target != null && _exams.contains(_target)) 'target_exam': _target,
        if (!student) 'subjects': _subjects.text,
      };
      final data = await session.api.patch('/me', body);
      session.setUser(data.obj('user'));
      if (!mounted) return;
      showSnack(context, 'Profile saved.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.read(context);
    final student = session.isStudent;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Loader<J>(
        load: () => session.api.get('/exams'),
        builder: (context, data, reload) {
          final exams = data.list('exams');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 20),
              if (student) ...[
                Text('Exams you are preparing for', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final e in exams)
                      FilterChip(
                        label: Text(e.str('name')),
                        selected: _exams.contains(e.str('code')),
                        onSelected: (on) => setState(() {
                          final code = e.str('code');
                          _exams = on ? [..._exams, code] : _exams.where((c) => c != code).toList();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Exam used for your rank', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in exams.where((e) => _exams.contains(e.str('code'))))
                      ChoiceChip(
                        label: Text(e.str('name')),
                        selected: _target == e.str('code'),
                        onSelected: (_) => setState(() => _target = e.str('code')),
                      ),
                  ],
                ),
              ] else
                TextField(
                  controller: _subjects,
                  decoration: const InputDecoration(labelText: 'Subjects you teach', helperText: 'Separate with commas, e.g. Physics, Chemistry'),
                ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : () => _save(student),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => openWebsite(context, '/profile/edit'),
                child: const Text('Change email, password or date of birth on the website'),
              ),
            ],
          );
        },
      ),
    );
  }
}
