import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/json.dart';
import '../core/theme.dart';

/// A message for any error thrown by the API or the app.
String messageOf(Object error) => error is ApiException
    ? error.message
    : 'Something went wrong. Please try again.';

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
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showMessageDialog(
  BuildContext context,
  String title,
  String message,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Opens a page of the Lakshyank website in the browser (sign-up, password reset, Excel uploads...).
Future<void> openWebsite(BuildContext context, String path) async {
  final ok = await launchUrl(
    Uri.parse('$kSiteUrl$path'),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    showSnack(context, 'Could not open $kSiteUrl$path');
  }
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
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
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
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;

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
      if (error != null) {
        return ErrorView(message: messageOf(error), onRetry: () => _run());
      }
      return const LoadingView();
    }
    return widget.builder(context, _data as T, () => _run());
  }
}

/// A small rounded label: grey by default (the website's slate chips), or in [color] on a pale [background].
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.background, this.icon});

  final String label;
  final Color? color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    final c = color;
    final fg = c ?? rw.neutralFg;
    final bg =
        background ??
        (c != null
            ? Color.alphaBlend(c.withAlpha(rw.dark ? 46 : 26), rw.card)
            : rw.neutralBg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// The exam's name in the exam's own colour (indigo UPSC, orange JEE Main...), as on the website.
class ExamChip extends StatelessWidget {
  const ExamChip(this.exam, {super.key});

  final J exam;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = examChipColors(context, exam.str('code'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        examName(exam),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// 🛡️ Strict / 🔐 PIN / 🟢 Open to all
class KindBadge extends StatelessWidget {
  const KindBadge(this.test, {super.key});

  final J test;

  @override
  Widget build(BuildContext context) {
    final style = kindStyle(context, kindOfTest(test));
    return Pill(
      style.label,
      icon: style.icon,
      color: style.badgeFg,
      background: style.badgeBg,
    );
  }
}

/// A white (dark: slate-900) rounded card with a hairline border, optionally with a coloured bar on the left
/// like the website's test cards.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.stripe,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final Color? stripe;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    final bar = stripe;
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? rw.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor ?? rw.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: bar == null
            ? content
            : DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: bar, width: 4)),
                ),
                child: content,
              ),
      ),
    );
  }
}

enum StatTone { plain, success, danger }

/// A number with a caption (and an optional line under it), like the website's stat cards.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.sub,
    this.tone = StatTone.plain,
  });

  final String label;
  final String value;
  final Color? color;
  final String? sub;
  final StatTone tone;

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    final (bg, border, labelColor) = switch (tone) {
      StatTone.success => (rw.successBg, rw.success.withAlpha(50), rw.success),
      StatTone.danger => (rw.dangerBg, rw.danger.withAlpha(50), rw.danger),
      StatTone.plain => (rw.card, rw.border, rw.muted),
    };
    final extra = sub;
    return SurfaceCard(
      color: bg,
      borderColor: border,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: labelColor,
              fontWeight: tone == StatTone.plain
                  ? FontWeight.w400
                  : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: color ?? rw.strong,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 2),
            Text(extra, style: TextStyle(fontSize: 12, color: rw.faint)),
          ],
        ],
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
        cells.add(
          Expanded(
            child: i + j < children.length ? children[i + j] : const SizedBox(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 10));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cells,
          ),
        ),
      );
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
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.rw.strong,
                letterSpacing: -0.2,
              ),
            ),
          ),
          ?trailing,
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
    final rw = context.rw;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 40, color: rw.faint),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: rw.muted),
          ),
        ],
      ),
    );
  }
}

/// A box highlighting something the user should read (upgrade options, strict mode rules...),
/// in the website's alert colours.
class NoticeBox extends StatelessWidget {
  const NoticeBox({
    super.key,
    required this.child,
    this.tone = NoticeTone.info,
  });

  final Widget child;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    final (bg, fg) = switch (tone) {
      NoticeTone.info => (rw.infoBg, rw.info),
      NoticeTone.warning => (rw.warningBg, rw.warning),
      NoticeTone.danger => (rw.dangerBg, rw.danger),
      NoticeTone.success => (rw.successBg, rw.success),
      NoticeTone.promo => (rw.promoBg, rw.promoFg),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withAlpha(50)),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg, fontSize: 14, height: 1.35),
        child: child,
      ),
    );
  }
}

enum NoticeTone { info, warning, danger, success, promo }

/// Shows the exam name, e.g. "UPSC Prelims".
String examName(J exam) => exam.str('name', exam.str('code'));

// ---------- app chrome ----------

/// The sun / moon button in the top bar, like the website's theme toggle.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Light mode' : 'Dark mode',
      icon: Icon(
        dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: context.rw.muted,
      ),
      onPressed: () => ThemeScope.read(context).toggle(brightness),
    );
  }
}

/// Light / Dark / System, for the Me tab.
class ThemeModePicker extends StatelessWidget {
  const ThemeModePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Dark'),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined),
          label: Text('System'),
        ),
      ],
      selected: {controller.mode},
      onSelectionChanged: (modes) => controller.setMode(modes.first),
    );
  }
}

/// The website's logo: the Lakshya mark in a brand-coloured tile, the name, and लक्ष्यांक beside it.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final rw = context.rw;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rw.button,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const LakshyaMark(size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Lakshyank'),
        const SizedBox(width: 6),
        Text('लक्ष्यांक', style: TextStyle(fontSize: 12, color: rw.muted)),
      ],
    );
  }
}

/// The bottom tab bar with the website's hairline above it.
class BrandNavBar extends StatelessWidget {
  const BrandNavBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.rw.border)),
      ),
      child: child,
    );
  }
}

/// The Lakshya mark: an arrow lodged in the bullseye, the same shape as the website logo and the app icon
/// (the ring-and-arrow version that stays clear at small sizes). Drawn in [color] on a 64-unit grid.
class LakshyaMark extends StatelessWidget {
  const LakshyaMark({super.key, required this.size, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LakshyaMarkPainter(color));
}

class _LakshyaMarkPainter extends CustomPainter {
  _LakshyaMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const centre = Offset(29, 35);
    canvas.drawCircle(centre, 24, pen); // outer ring
    canvas.drawCircle(centre, 11, pen); // inner ring
    canvas.drawLine(centre, const Offset(57, 7), pen); // arrow shaft, tip in the bullseye
    canvas.drawPath(Path()..moveTo(52, 2.5)..lineTo(51, 12)..lineTo(61.5, 11), pen); // feathers
  }

  @override
  bool shouldRepaint(_LakshyaMarkPainter old) => old.color != color;
}
