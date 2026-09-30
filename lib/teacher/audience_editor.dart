import 'package:flutter/material.dart';

import '../core/json.dart';

/// "Visible to" for a test or question (same choices as the website):
/// everyone, one of my schools/coachings, or selected batches / students.
class AudienceValue {
  AudienceValue({
    this.visibility = 'public',
    this.institutionId,
    Set<int>? batchIds,
    this.emails = '',
    List<int>? userIds,
    List<int>? institutionIds,
  }) : batchIds = batchIds ?? <int>{},
       userIds = userIds ?? <int>[],
       institutionIds = institutionIds ?? <int>[];

  factory AudienceValue.fromJson(J? json) {
    if (json == null) return AudienceValue();
    return AudienceValue(
      visibility: json.str('visibility', 'public'),
      institutionId: json.intOrNull('institution_id'),
      batchIds: json.ints('batch_ids').toSet(),
      userIds: json.ints('user_ids'),
      institutionIds: json.ints('institution_ids'),
    );
  }

  String visibility;
  int? institutionId;
  Set<int> batchIds;
  String emails;
  // Students and institutions picked on the website are kept as they are
  List<int> userIds;
  List<int> institutionIds;

  /// The `audience` parameters the API expects (only used for "selected").
  J toParams() => {
    'batch_ids': batchIds.toList(),
    'user_ids': userIds,
    'institution_ids': institutionIds,
    'emails': emails,
  };

  /// A problem to show before saving, or null.
  String? problem({required bool forTest}) {
    if (visibility == 'institution' && institutionId == null)
      return 'Pick which school or coaching can see it.';
    if (visibility == 'selected' &&
        batchIds.isEmpty &&
        userIds.isEmpty &&
        institutionIds.isEmpty &&
        emails.trim().isEmpty) {
      return 'Pick at least one batch, or add students by email.';
    }
    return null;
  }
}

class AudienceEditor extends StatefulWidget {
  const AudienceEditor({
    super.key,
    required this.options,
    required this.value,
    required this.forTest,
    required this.onChanged,
  });

  /// /teacher/form_options
  final J options;
  final AudienceValue value;
  final bool forTest;
  final VoidCallback onChanged;

  @override
  State<AudienceEditor> createState() => _AudienceEditorState();
}

class _AudienceEditorState extends State<AudienceEditor> {
  late final TextEditingController _emails = TextEditingController(
    text: widget.value.emails,
  );

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  void _change(VoidCallback fn) {
    setState(fn);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value;
    final institutions = widget.options.list('institutions');
    final batches = widget.options.list('batches');
    final text = Theme.of(context).textTheme;

    Widget institutionPicker({required bool optional}) {
      if (institutions.isEmpty) {
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            "You're not a teacher at any school or coaching yet. Join or add one on the website.",
          ),
        );
      }
      final ids = institutions.map((i) => i.integer('id')).toSet();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: optional
                ? 'For which school or coaching (optional)'
                : 'Which school or coaching',
            helperText: widget.forTest
                ? 'A school test counts toward that school\'s monthly tests.'
                : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              isExpanded: true,
              isDense: true,
              value: ids.contains(v.institutionId) ? v.institutionId : null,
              items: [
                if (optional)
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Not for a school'),
                  ),
                for (final i in institutions)
                  DropdownMenuItem<int?>(
                    value: i.integer('id'),
                    child: Text(
                      i.flag('subscribed') && widget.forTest
                          ? '${i.str('name')} · ${i.integer('tests_this_month')}/${i.intOrNull('tests_limit') ?? '∞'} tests this month'
                          : i.str('name'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => _change(() => v.institutionId = id),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Visible to', style: text.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'public',
              label: Text('Everyone'),
              icon: Icon(Icons.public),
            ),
            ButtonSegment(
              value: 'institution',
              label: Text('My school'),
              icon: Icon(Icons.school_outlined),
            ),
            ButtonSegment(
              value: 'selected',
              label: Text('Selected'),
              icon: Icon(Icons.group_outlined),
            ),
          ],
          selected: {v.visibility},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _change(() => v.visibility = s.first),
        ),
        if (v.visibility == 'institution') ...[
          institutionPicker(optional: false),
          const SizedBox(height: 6),
          Text(
            'Only its approved students (and its teachers) see this.',
            style: text.bodySmall,
          ),
        ],
        if (v.visibility == 'selected') ...[
          if (widget.forTest) institutionPicker(optional: true),
          const SizedBox(height: 12),
          Text('Batches', style: text.labelLarge),
          const SizedBox(height: 6),
          if (batches.isEmpty)
            Text(
              'No batches yet. Make batches of students on the website.',
              style: text.bodySmall,
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final b in batches)
                FilterChip(
                  label: Text('${b.str('name')} (${b.integer('students')})'),
                  selected: v.batchIds.contains(b.integer('id')),
                  onSelected: (on) => _change(
                    () => on
                        ? v.batchIds.add(b.integer('id'))
                        : v.batchIds.remove(b.integer('id')),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emails,
            minLines: 1,
            maxLines: 4,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Add students by email',
              helperText: 'Separate with commas or new lines',
            ),
            onChanged: (s) {
              v.emails = s;
              widget.onChanged();
            },
          ),
          if (v.userIds.isNotEmpty || v.institutionIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Also kept: ${v.userIds.length} student(s) and ${v.institutionIds.length} school(s) picked on the website.',
                style: text.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}
