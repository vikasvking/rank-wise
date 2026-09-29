import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/json.dart';

/// A message for any error thrown by the API or the app.
String messageOf(Object error) => error is ApiException ? error.message : 'Something went wrong. Please try again.';

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'OK',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showMessageDialog(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}

/// Opens a page of the Rankwise website in the browser (sign-up, password reset, Excel uploads...).
Future<void> openWebsite(BuildContext context, String path) async {
  final ok = await launchUrl(Uri.parse('$kSiteUrl$path'), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showSnack(context, 'Could not open $kSiteUrl$path');
}

class LoadingView extends StatefulWidget {
  const LoadingView({super.key});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  bool _slow = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_slow) ...[
              const SizedBox(height: 16),
              Text(
                'Waking up the server… this can take up to a minute.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loads data once, shows a spinner / error with retry, and hands a `reload` to the builder
/// (use it for pull-to-refresh and after changes).
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? _data;
  bool _hasData = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _run(initial: true);
  }

  Future<void> _run({bool initial = false}) async {
    if (!initial) setState(() => _error = null);
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _hasData = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_hasData) {
        showSnack(context, messageOf(e));
      } else {
        setState(() => _error = e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasData) {
      final error = _error;
      if (error != null) return ErrorView(message: messageOf(error), onRetry: () => _run());
      return const LoadingView();
    }
    return widget.builder(context, _data as T, () => _run());
  }
}

/// A small rounded label.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color == null ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

/// A number with a caption, for stat rows.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.labelMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 4),
            Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Lays out tiles two (or more) per row.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.columns = 2});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (j > 0) cells.add(const SizedBox(width: 10));
        cells.add(Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()));
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)));
    }
    return Column(children: rows);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.message, {super.key, this.icon = Icons.inbox_outlined});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}

/// A box highlighting something the user should read (upgrade options, strict mode rules...).
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.child, this.tone = NoticeTone.info});

  final Widget child;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      NoticeTone.info => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      NoticeTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      NoticeTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: DefaultTextStyle.merge(style: TextStyle(color: fg), child: child),
    );
  }
}

enum NoticeTone { info, warning, danger }

/// Shows the exam name, e.g. "UPSC Prelims".
String examName(J exam) => exam.str('name', exam.str('code'));
