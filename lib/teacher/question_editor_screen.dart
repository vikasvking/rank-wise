import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'audience_editor.dart';

/// Add a question, or edit one of your own. Pops with `true` after saving.
class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({super.key, this.question});

  /// The question from the list (null = new question).
  final J? question;

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  J? _options;
  String? _loadError;
  bool _saving = false;

  final _year = TextEditingController();
  final _topic = TextEditingController();
  final _content = TextEditingController();
  final _explanation = TextEditingController();
  final Map<String, TextEditingController> _choices = {
    for (final l in const ['A', 'B', 'C', 'D']) l: TextEditingController(),
  };
  String? _exam;
  String _correct = 'A';
  AudienceValue _audience = AudienceValue();

  int? get _id => widget.question?.intOrNull('id');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _year,
      _topic,
      _content,
      _explanation,
      ..._choices.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.read(context).api;
    try {
      final options = await api.get('/teacher/form_options');
      final id = _id;
      final J? question = id == null
          ? null
          : (await api.get('/teacher/questions/$id')).obj('question');
      if (!mounted) return;
      setState(() {
        _options = options;
        _loadError = null;
        if (question == null) {
          final exams = options.list('exams');
          _exam = exams.isEmpty ? null : exams.first.str('code');
        } else {
          _exam = question.strOrNull('exam');
          _year.text = question.str('year');
          _topic.text = question.str('topic');
          _content.text = question.str('content');
          _explanation.text = question.str('explanation');
          final opts = question.obj('options');
          _choices.forEach((letter, c) => c.text = opts.str(letter));
          _correct = question.str('correct_answer', 'A');
          _audience = AudienceValue.fromJson(question.objOrNull('audience'));
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  String? _problem() {
    if (_topic.text.trim().isEmpty) {
      return 'Add a topic (subject), e.g. Physics.';
    }
    if (_content.text.trim().isEmpty) return 'Write the question.';
    if (_choices.values.where((c) => c.text.trim().isNotEmpty).length < 2) {
      return 'Add at least two options.';
    }
    if (_choices[_correct]!.text.trim().isEmpty) {
      return 'The correct answer ($_correct) has no text.';
    }
    return _audience.problem(forTest: false);
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
      'question': {
        'exam_type': _exam,
        'year': _year.text.trim(),
        'topic': _topic.text.trim(),
        'content': _content.text.trim(),
        'option_a': _choices['A']!.text.trim(),
        'option_b': _choices['B']!.text.trim(),
        'option_c': _choices['C']!.text.trim(),
        'option_d': _choices['D']!.text.trim(),
        'correct_answer': _correct,
        'explanation': _explanation.text.trim(),
        'visibility': _audience.visibility,
        'institution_id': _audience.institutionId,
      },
      'audience': _audience.toParams(),
    };
    try {
      final id = _id;
      final data = id == null
          ? await api.post('/teacher/questions', body)
          : await api.patch('/teacher/questions/$id', body);
      if (!mounted) return;
      final warning = data.strOrNull('warning');
      showSnack(
        context,
        [data.str('message', 'Saved.'), ?warning].join(' '),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        await showMessageDialog(context, 'Could not save', e.message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      appBar: AppBar(
        title: Text(_id == null ? 'Add question' : 'Edit question'),
        actions: [
          if (options != null)
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
    final exams = options.list('exams');
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        if (_id != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: NoticeBox(
              child: Text(
                'Changing the correct answer re-marks every saved answer to this question, including in tests.',
              ),
            ),
          ),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Exam'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: exams.any((e) => e.str('code') == _exam) ? _exam : null,
              items: [
                for (final e in exams)
                  DropdownMenuItem(
                    value: e.str('code'),
                    child: Text(e.str('name')),
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
              flex: 2,
              child: TextField(
                controller: _topic,
                decoration: const InputDecoration(labelText: 'Topic / subject'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Year'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _content,
          minLines: 2,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'Question'),
        ),
        const SizedBox(height: 16),
        Text(
          'Options (tap the letter of the correct one)',
          style: text.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final letter in const ['A', 'B', 'C', 'D'])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(letter),
                  selected: _correct == letter,
                  onSelected: (_) => setState(() => _correct = letter),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _choices[letter],
                    decoration: InputDecoration(
                      labelText:
                          'Option $letter${_correct == letter ? ' (correct)' : ''}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: _explanation,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Explanation (optional)',
          ),
        ),
        const SizedBox(height: 20),
        AudienceEditor(
          options: options,
          value: _audience,
          forTest: false,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(_saving ? 'Saving…' : 'Save question'),
        ),
      ],
    );
  }
}
