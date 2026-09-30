import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'audience_editor.dart';
import 'question_picker_screen.dart';

/// Create a test, or edit one that has not locked yet. Pops with `true` after saving.
class TestEditorScreen extends StatefulWidget {
  const TestEditorScreen({super.key, this.testId});

  final int? testId;

  @override
  State<TestEditorScreen> createState() => _TestEditorScreenState();
}

class _TestEditorScreenState extends State<TestEditorScreen> {
  J? _options;
  String? _loadError;
  bool _locked = false;
  bool _saving = false;

  final _title = TextEditingController();
  final _duration = TextEditingController(text: '45');
  final _passMark = TextEditingController(text: '40');
  String? _exam;
  String _access = 'pin';
  bool _strict = false;
  DateTime? _startsAt;
  DateTime? _endsAt;
  AudienceValue _audience = AudienceValue();
  List<J> _questions = [];

  bool get _editing => widget.testId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _passMark.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.read(context).api;
    try {
      final options = await api.get('/teacher/form_options');
      final J? test = _editing
          ? (await api.get('/teacher/tests/${widget.testId}')).obj('test')
          : null;
      if (!mounted) return;
      setState(() {
        _options = options;
        _loadError = null;
        final defaults = options.obj('defaults');
        if (test == null) {
          _duration.text = '${defaults.integer('duration_minutes', 45)}';
          _passMark.text = '${defaults.integer('pass_mark_percentage', 40)}';
          _access = defaults.str('access_type', 'pin');
          final exams = options.list('exams');
          _exam = exams.isEmpty ? null : exams.first.str('code');
        } else {
          _title.text = test.str('title');
          _duration.text = '${test.integer('duration_minutes')}';
          _passMark.text = '${test.integer('pass_mark_percentage')}';
          _exam = test.obj('exam').str('code');
          _access = test.str('access', 'pin');
          _strict = test.flag('strict');
          _startsAt = test.time('starts_at');
          _endsAt = test.time('ends_at');
          _audience = AudienceValue.fromJson(test.objOrNull('audience'));
          _questions = test.list('questions');
          _locked = test.flag('locked');
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 2, 12, 31);
    var base = current ?? now.add(const Duration(hours: 1));
    if (base.isBefore(first) || base.isAfter(last)) base = now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String? _problem() {
    if (_title.text.trim().isEmpty) return 'Give the test a title.';
    if (_exam == null) return 'Pick an exam.';
    if ((int.tryParse(_duration.text) ?? 0) <= 0) {
      return 'Duration must be at least 1 minute.';
    }
    final pass = int.tryParse(_passMark.text);
    if (pass == null || pass < 0 || pass > 100) {
      return 'Pass mark must be between 0 and 100.';
    }
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      return 'The closing time must be after the opening time.';
    }
    if (_strict && _access != 'pin') return 'Strict mode needs PIN access.';
    if (_strict && _endsAt == null) {
      return 'Strict mode needs a closing time (results are shown after it).';
    }
    if (_questions.isEmpty) return 'Add at least one question.';
    return _audience.problem(forTest: true);
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      showSnack(context, problem);
      return;
    }
    setState(() => _saving = true);
    final api = AppScope.read(context).api;
    final body = <String, dynamic>{
      'test': {
        'title': _title.text.trim(),
        'exam_type': _exam,
        'duration_minutes': int.parse(_duration.text),
        'pass_mark_percentage': int.parse(_passMark.text),
        'access_type': _access,
        'strict_mode': _strict,
        'starts_at': _startsAt?.toUtc().toIso8601String(),
        'ends_at': _endsAt?.toUtc().toIso8601String(),
        'visibility': _audience.visibility,
        'institution_id': _audience.institutionId,
        'question_ids': _questions.map((q) => q.integer('id')).toList(),
      },
      'audience': _audience.toParams(),
    };
    try {
      final data = _editing
          ? await api.patch('/teacher/tests/${widget.testId}', body)
          : await api.post('/teacher/tests', body);
      if (!mounted) return;
      final warning = data.strOrNull('warning');
      await showMessageDialog(
        context,
        _editing ? 'Saved' : 'Test created',
        [data.str('message'), ?warning].join('\n\n'),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        await showMessageDialog(context, 'Could not save', e.message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addQuestions() async {
    final picked = await Navigator.push<List<J>>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionPickerScreen(
          exam: _exam,
          alreadyPicked: _questions.map((q) => q.integer('id')).toSet(),
        ),
      ),
    );
    if (picked != null && picked.isNotEmpty && mounted) {
      setState(() => _questions = [..._questions, ...picked]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit test' : 'New test'),
        actions: [
          if (options != null && !_locked)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
        ],
      ),
      body: options == null
          ? (_loadError != null
                ? ErrorView(message: _loadError!, onRetry: _load)
                : const LoadingView())
          : _form(context, options),
    );
  }

  Widget _form(BuildContext context, J options) {
    final text = Theme.of(context).textTheme;
    final exams = options.list('exams');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        if (_locked)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: NoticeBox(
              tone: NoticeTone.danger,
              child: Text(
                '🔒 This test is locked: tests with a time window or strict mode lock 10 minutes before they open, '
                'once a student has started, and after they close. Ask an admin to change it.',
              ),
            ),
          ),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Exam (sets the marking scheme)',
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: exams.any((e) => e.str('code') == _exam) ? _exam : null,
              items: [
                for (final e in exams)
                  DropdownMenuItem(
                    value: e.str('code'),
                    child: Text(
                      '${e.str('name')} · ${e.str('marking')}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _exam = v),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _passMark,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pass mark (%)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Access', style: text.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'open',
              label: Text('Open'),
              icon: Icon(Icons.lock_open),
            ),
            ButtonSegment(
              value: 'pin',
              label: Text('PIN'),
              icon: Icon(Icons.pin_outlined),
            ),
          ],
          selected: {_access},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            _access = s.first;
            if (_access != 'pin') _strict = false;
          }),
        ),
        const SizedBox(height: 4),
        Text(
          _access == 'pin'
              ? 'Students need the PIN (shown after saving) to start.'
              : 'Anyone who can see the test can start it.',
          style: text.bodySmall,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('🛡️ Strict mode'),
          subtitle: const Text(
            'Leaving the test warns once, then blocks. Marks show after the closing time. Needs PIN and a closing time.',
          ),
          value: _strict,
          onChanged: _access == 'pin'
              ? (v) => setState(() => _strict = v)
              : null,
        ),
        const SizedBox(height: 4),
        Text('Time window (optional)', style: text.titleSmall),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_available),
          title: Text(
            _startsAt == null
                ? 'Opens: any time'
                : 'Opens: ${fmtDateTime(_startsAt)}',
          ),
          trailing: _startsAt == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _startsAt = null),
                ),
          onTap: () async {
            final t = await _pickDateTime(_startsAt);
            if (t != null) setState(() => _startsAt = t);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_busy),
          title: Text(
            _endsAt == null
                ? 'Closes: never'
                : 'Closes: ${fmtDateTime(_endsAt)}',
          ),
          trailing: _endsAt == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _endsAt = null),
                ),
          onTap: () async {
            final t = await _pickDateTime(_endsAt);
            if (t != null) setState(() => _endsAt = t);
          },
        ),
        Text(
          'Tests with a time window or strict mode lock 10 minutes before they open.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 20),
        AudienceEditor(
          options: options,
          value: _audience,
          forTest: true,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 20),
        SectionTitle(
          'Questions (${_questions.length})',
          trailing: TextButton.icon(
            onPressed: _addQuestions,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ),
        if (_questions.isEmpty)
          const EmptyView(
            'No questions yet. Tap Add to pick from the question bank.',
            icon: Icons.quiz_outlined,
          ),
        for (var i = 0; i < _questions.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: CircleAvatar(
                radius: 14,
                child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
              ),
              title: Text(
                _questions[i].str('content'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_questions[i].str('topic')} · Answer ${_questions[i].str('correct_answer')}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Remove',
                onPressed: () =>
                    setState(() => _questions = [..._questions]..removeAt(i)),
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (!_locked)
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(
              _saving ? 'Saving…' : (_editing ? 'Save changes' : 'Create test'),
            ),
          ),
      ],
    );
  }
}
