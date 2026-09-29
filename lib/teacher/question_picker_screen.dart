import 'package:flutter/material.dart';

import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';

/// Pick questions for a test from every question this teacher may use.
/// Returns the picked questions (as JSON) with Navigator.pop.
class QuestionPickerScreen extends StatefulWidget {
  const QuestionPickerScreen({super.key, this.exam, required this.alreadyPicked});

  final String? exam;
  final Set<int> alreadyPicked;

  @override
  State<QuestionPickerScreen> createState() => _QuestionPickerScreenState();
}

class _QuestionPickerScreenState extends State<QuestionPickerScreen> {
  final _search = TextEditingController();
  final List<J> _rows = [];
  final Map<int, J> _picked = {};
  List<String> _topics = [];
  String? _topic;
  late String? _exam = widget.exam;
  bool _mine = false;
  int? _nextPage = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Starts the list again from page 1 (after a filter or search change).
  void _reset() {
    _rows.clear();
    _nextPage = 1;
    _loadMore(force: true);
  }

  int _request = 0; // ignores answers to older searches

  Future<void> _loadMore({bool force = false}) async {
    final page = _nextPage;
    if (page == null || (_loading && !force)) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AppScope.read(context).api.get('/teacher/questions', {
        'exam': _exam,
        'topic': _topic,
        'q': _search.text.trim(),
        'mine': _mine ? '1' : null,
        'page': page,
      });
      if (!mounted || request != _request) return;
      setState(() {
        _rows.addAll(data.list('questions'));
        _topics = data.strings('topics');
        _nextPage = data.intOrNull('next_page');
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = messageOf(e));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_picked.isEmpty ? 'Add questions' : '${_picked.length} picked'),
        actions: [
          TextButton(
            onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.values.toList()),
            child: const Text('Add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reset(),
              decoration: InputDecoration(
                hintText: 'Search question text',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _reset),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                FilterChip(label: const Text('Only mine'), selected: _mine, onSelected: (v) {
                  _mine = v;
                  _reset();
                }),
                const SizedBox(width: 8),
                if (_exam != null) ...[
                  InputChip(label: Text('Exam: ${_exam!}'), onDeleted: () {
                    _exam = null;
                    _reset();
                  }),
                  const SizedBox(width: 8),
                ],
                for (final t in _topics.take(30)) ...[
                  ChoiceChip(label: Text(t), selected: _topic == t, onSelected: (on) {
                    _topic = on ? t : null;
                    _reset();
                  }),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _loadMore();
                return false;
              },
              child: ListView.builder(
                itemCount: _rows.length + 1,
                itemBuilder: (context, i) {
                  if (i == _rows.length) {
                    if (_loading) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                    if (_rows.isEmpty) return const EmptyView('No questions match.');
                    return const SizedBox(height: 24);
                  }
                  final q = _rows[i];
                  final id = q.integer('id');
                  final already = widget.alreadyPicked.contains(id);
                  return CheckboxListTile(
                    value: already || _picked.containsKey(id),
                    onChanged: already
                        ? null
                        : (on) => setState(() => on == true ? _picked[id] = q : _picked.remove(id)),
                    title: Text(q.str('content'), maxLines: 3, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [q.str('exam'), q.str('topic'), if (q.strOrNull('year') != null) q.str('year'), 'Answer ${q.str('correct_answer')}',
                              if (already) 'already in test']
                          .join(' · '),
                      style: text.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
