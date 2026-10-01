import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../widgets/common.dart';
import '../widgets/test_card.dart';
import 'history_screen.dart';
import 'test_detail_screen.dart';

/// Every test the student can see, like the website's "All Tests" page.
class TestsTab extends StatefulWidget {
  const TestsTab({super.key});

  @override
  State<TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<TestsTab> {
  String?
  _exam; // null = the server's default ("mine" when the student picked exams)
  int _version = 0; // bump to reload

  Future<void> _enterPin() async {
    final testId = await askForPin(context);
    if (testId == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TestDetailScreen(testId: testId)),
    );
    if (mounted) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.read(context).api;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tests'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
            icon: const Icon(Icons.history),
            tooltip: 'My tests',
          ),
          TextButton.icon(
            onPressed: _enterPin,
            icon: const Icon(Icons.pin_outlined),
            label: const Text('Enter PIN'),
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: Loader<J>(
        key: ValueKey('tests-$_exam-$_version'),
        load: () => api.get('/tests', {'exam': _exam}),
        builder: (context, data, reload) {
          final tests = data.list('tests');
          final current = data.str('exam');
          final options = <MapEntry<String, String>>[
            const MapEntry('mine', 'My exams'),
            const MapEntry('all', 'All exams'),
            for (final e in data.list('exam_options'))
              MapEntry(e.str('code'), e.str('name')),
          ];
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final o in options)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(o.value),
                            selected: current == o.key,
                            onSelected: (_) => setState(() => _exam = o.key),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (tests.isEmpty)
                  const EmptyView(
                    'No tests here yet. Try "All exams", or enter a PIN from your teacher.',
                  ),
                for (final t in tests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StudentTestCard(
                      test: t,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TestDetailScreen(testId: t.integer('id')),
                          ),
                        );
                        reload();
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Asks for a teacher's PIN and checks it. Returns the test id, or null.
Future<int?> askForPin(BuildContext context) {
  return showDialog<int>(context: context, builder: (_) => const _PinDialog());
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (pin.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await AppScope.read(
        context,
      ).api.post('/tests/verify_pin', {'pin_code': pin});
      if (mounted) Navigator.pop(context, data.integer('test_id'));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter test PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your teacher shares a 6-character PIN for PIN-protected tests.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: 'PIN', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Checking…' : 'Continue'),
        ),
      ],
    );
  }
}
