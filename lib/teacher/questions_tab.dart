import 'package:flutter/material.dart';

import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import 'question_editor_screen.dart';

/// Questions this teacher may use, with search and filters. Own questions can be edited.
class QuestionsTab extends StatefulWidget {
  const QuestionsTab({super.key});

  @override
  State<QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<QuestionsTab> {
  final _search = TextEditingController();
  final List<J> _rows = [];
  List<String> _topics = [];
  String? _topic;
  bool _mine = true;
  int? _nextPage = 1;
  bool _loading = false;
  String? _error;
  int _request = 0;

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

  void _reset() {
    _rows.clear();
    _nextPage = 1;
    _loadMore(force: true);
  }

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

  Future<void> _open([J? question]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditorScreen(question: question),
      ),
    );
    if (saved == true && mounted) _reset();
  }

  void _view(J q) {
    final options = q.obj('options');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${q.str('exam')} · ${q.str('topic')} · by ${q.str('author')}',
                style: Theme.of(ctx).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Text(
                q.str('content'),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final letter in const ['A', 'B', 'C', 'D'])
                if (options.str(letter).isNotEmpty)
                  Text(
                    '$letter. ${options.str(letter)}${letter == q.str('correct_answer') ? '  ✓' : ''}',
                    style: TextStyle(
                      fontWeight: letter == q.str('correct_answer')
                          ? FontWeight.w700
                          : null,
                    ),
                  ),
              if (q.str('explanation').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(q.str('explanation')),
              ],
              const SizedBox(height: 8),
              Text(
                'Visible to: ${q.str('audience')}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              if (!q.flag('editable'))
                Text(
                  'Only the teacher who added it (or an admin) can edit it.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questions'),
        actions: [
          IconButton(
            tooltip: 'Upload from Excel (website)',
            icon: const Icon(Icons.upload_file),
            onPressed: () => openWebsite(context, '/questions/upload_form'),
          ),
          const ThemeToggleButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Add question'),
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _reset,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                FilterChip(
                  label: const Text('Only mine'),
                  selected: _mine,
                  onSelected: (v) {
                    _mine = v;
                    _reset();
                  },
                ),
                const SizedBox(width: 8),
                for (final t in _topics.take(30)) ...[
                  ChoiceChip(
                    label: Text(t),
                    selected: _topic == t,
                    onSelected: (on) {
                      _topic = on ? t : null;
                      _reset();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reset(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 300)
                    _loadMore();
                  return false;
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: _rows.length + 1,
                  itemBuilder: (context, i) {
                    if (i == _rows.length) {
                      if (_loading)
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      if (_rows.isEmpty)
                        return EmptyView(
                          _mine
                              ? 'You have not added questions yet.'
                              : 'No questions match.',
                        );
                      return const SizedBox(height: 24);
                    }
                    final q = _rows[i];
                    return ListTile(
                      title: Text(
                        q.str('content'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          q.str('exam'),
                          q.str('topic'),
                          'Answer ${q.str('correct_answer')}',
                          if (q.str('visibility') != 'public')
                            q.str('audience'),
                        ].join(' · '),
                      ),
                      trailing: q.flag('editable')
                          ? const Icon(Icons.edit_outlined)
                          : null,
                      onTap: () {
                        if (q.flag('editable')) {
                          _open(q);
                        } else {
                          _view(q);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
