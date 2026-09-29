import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'json.dart';
import 'palette.dart';

/// Tailwind's `dark:bg-<colour>-950/40` on a slate-900 card, as a solid colour.
Color _tint(Color c950) => Color.alphaBlend(c950.withAlpha(102), Tw.slate900);

/// The website's colours that Material's ColorScheme has no slot for. Read them with `context.rw`.
@immutable
class Rw extends ThemeExtension<Rw> {
  const Rw({
    required this.dark,
    required this.brand,
    required this.page,
    required this.card,
    required this.border,
    required this.strong,
    required this.body,
    required this.muted,
    required this.faint,
    required this.brandFg,
    required this.brandSoft,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerBg,
    required this.warning,
    required this.warningBg,
    required this.info,
    required this.infoBg,
    required this.neutralBg,
    required this.neutralFg,
    required this.gold,
    required this.goldBg,
    required this.goldBorder,
    required this.promoBg,
    required this.promoFg,
  });

  factory Rw.of(Brightness brightness, Ramp brand) {
    if (brightness == Brightness.dark) {
      return Rw(
        dark: true,
        brand: brand,
        page: Tw.slate950,
        card: Tw.slate900,
        border: Tw.slate800,
        strong: Tw.white,
        body: Tw.slate300,
        muted: Tw.slate400,
        faint: Tw.slate500,
        brandFg: brand.s300,
        brandSoft: _tint(brand.s950),
        success: Tw.emerald400,
        successBg: _tint(Tw.emerald950),
        danger: Tw.red400,
        dangerBg: _tint(Tw.red950),
        warning: Tw.amber300,
        warningBg: _tint(Tw.amber950),
        info: Tw.sky300,
        infoBg: _tint(Tw.sky950),
        neutralBg: Tw.slate800,
        neutralFg: Tw.slate300,
        gold: Tw.amber400,
        goldBg: _tint(Tw.amber950),
        goldBorder: Color.alphaBlend(Tw.amber900.withAlpha(128), Tw.slate900),
        promoBg: _tint(Tw.pink950),
        promoFg: Tw.pink200,
      );
    }
    return Rw(
      dark: false,
      brand: brand,
      page: Tw.slate50,
      card: Tw.white,
      border: Tw.slate200,
      strong: Tw.slate900,
      body: Tw.slate700,
      muted: Tw.slate500,
      faint: Tw.slate400,
      brandFg: brand.s700,
      brandSoft: brand.s50,
      success: Tw.emerald700,
      successBg: Tw.emerald50,
      danger: Tw.red700,
      dangerBg: Tw.red50,
      warning: Tw.amber800,
      warningBg: Tw.amber50,
      info: Tw.sky700,
      infoBg: Tw.sky50,
      neutralBg: Tw.slate100,
      neutralFg: Tw.slate600,
      gold: Tw.amber700,
      goldBg: Tw.amber50,
      goldBorder: Tw.amber200,
      promoBg: Tw.pink50,
      promoFg: Tw.pink900,
    );
  }

  final bool dark;
  final Ramp brand;

  /// Screen background (slate-50 / slate-950), cards (white / slate-900) and their hairline border.
  final Color page, card, border;

  /// Text: headings, body, secondary, hints.
  final Color strong, body, muted, faint;

  /// Brand-coloured text and icons, and the pale brand background behind them.
  final Color brandFg, brandSoft;

  /// Right / wrong / attention / information, each with its pale background.
  final Color success, successBg, danger, dangerBg, warning, warningBg, info, infoBg;

  /// Grey chips ("Closed", "Available any time").
  final Color neutralBg, neutralFg;

  /// The amber "Your rank" box on the result page.
  final Color gold, goldBg, goldBorder;

  /// The pink free-trial banner.
  final Color promoBg, promoFg;

  /// Filled buttons are brand-700 in both themes, as on the website.
  Color get button => brand.s700;

  @override
  Rw copyWith() => this;

  @override
  Rw lerp(ThemeExtension<Rw>? other, double t) => (other is Rw && t >= 0.5) ? other : this;
}

extension RwContext on BuildContext {
  Rw get rw => Theme.of(this).extension<Rw>()!;
}

// ---------- test kinds: 🛡️ Strict / 🔐 PIN / 🟢 Open to all (TestStylesHelper on the website) ----------

enum TestKind { strict, pin, open }

TestKind kindOfTest(J test) {
  if (test.flag('strict')) return TestKind.strict;
  if (test.str('access') == 'pin') return TestKind.pin;
  return TestKind.open;
}

class KindStyle {
  const KindStyle({required this.label, required this.icon, required this.stripe, required this.badgeBg, required this.badgeFg, required this.button});

  final String label;
  final IconData icon;

  /// The coloured bar on the left of a test card, its badge colours, and its main button.
  final Color stripe, badgeBg, badgeFg, button;
}

KindStyle kindStyle(BuildContext context, TestKind kind) {
  final dark = context.rw.dark;
  return switch (kind) {
    TestKind.strict => KindStyle(
        label: 'Strict',
        icon: Icons.shield_outlined,
        stripe: Tw.red600,
        badgeBg: dark ? _tint(Tw.red950) : Tw.red50,
        badgeFg: dark ? Tw.red300 : Tw.red700,
        button: Tw.red700,
      ),
    TestKind.pin => KindStyle(
        label: 'PIN',
        icon: Icons.lock_outline,
        stripe: Tw.sky600,
        badgeBg: dark ? _tint(Tw.sky950) : Tw.sky50,
        badgeFg: dark ? Tw.sky300 : Tw.sky700,
        button: Tw.sky700,
      ),
    TestKind.open => KindStyle(
        label: 'Open to all',
        icon: Icons.public,
        stripe: Tw.emerald600,
        badgeBg: dark ? _tint(Tw.emerald950) : Tw.emerald50,
        badgeFg: dark ? Tw.emerald300 : Tw.emerald700,
        button: Tw.emerald700,
      ),
  };
}

/// (background, text) for an exam's chip, e.g. indigo for UPSC Prelims.
(Color, Color) examChipColors(BuildContext context, String code) {
  final rw = context.rw;
  final c = kExamChipColors[code];
  if (c == null) return (rw.neutralBg, rw.neutralFg);
  return rw.dark ? (_tint(c.$4), c.$3) : (c.$1, c.$2);
}

// ---------- the Material theme ----------

ThemeData buildTheme(Brightness brightness, Ramp brand) {
  final rw = Rw.of(brightness, brand);
  final dark = rw.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? brand.s400 : brand.s700,
    onPrimary: dark ? Tw.slate950 : Tw.white,
    primaryContainer: rw.brandSoft,
    onPrimaryContainer: dark ? brand.s200 : brand.s800,
    secondary: dark ? Tw.slate400 : Tw.slate600,
    onSecondary: dark ? Tw.slate950 : Tw.white,
    secondaryContainer: rw.neutralBg,
    onSecondaryContainer: dark ? Tw.slate200 : Tw.slate700,
    tertiary: dark ? Tw.amber400 : Tw.amber700,
    onTertiary: dark ? Tw.slate950 : Tw.white,
    tertiaryContainer: rw.warningBg,
    onTertiaryContainer: rw.warning,
    error: dark ? Tw.red400 : Tw.red700,
    onError: dark ? Tw.slate950 : Tw.white,
    errorContainer: rw.dangerBg,
    onErrorContainer: dark ? Tw.red300 : Tw.red800,
    surface: rw.card,
    onSurface: rw.strong,
    onSurfaceVariant: rw.muted,
    outline: rw.muted,
    outlineVariant: rw.border,
    surfaceContainerLowest: rw.card,
    surfaceContainerLow: rw.card,
    surfaceContainer: dark ? Tw.slate900 : Tw.slate50,
    surfaceContainerHigh: dark ? Tw.slate800 : Tw.slate100,
    surfaceContainerHighest: dark ? Tw.slate800 : Tw.slate100,
    surfaceTint: Colors.transparent,
    inverseSurface: dark ? Tw.slate100 : Tw.slate900,
    onInverseSurface: dark ? Tw.slate900 : Tw.slate50,
    inversePrimary: dark ? brand.s700 : brand.s300,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  var text = base.textTheme.apply(bodyColor: rw.body, displayColor: rw.strong);
  text = text.copyWith(
    headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
    titleLarge: text.titleLarge?.copyWith(color: rw.strong, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleMedium: text.titleMedium?.copyWith(color: rw.strong),
    titleSmall: text.titleSmall?.copyWith(color: rw.strong),
    bodySmall: text.bodySmall?.copyWith(color: rw.muted),
    labelSmall: text.labelSmall?.copyWith(color: rw.muted),
  );
  const semibold = TextStyle(fontWeight: FontWeight.w600);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: dark ? Tw.slate700 : Tw.slate300),
  );

  return base.copyWith(
    scaffoldBackgroundColor: rw.page,
    textTheme: text,
    extensions: [rw],
    dividerTheme: DividerThemeData(color: rw.border, space: 1, thickness: 1),
    appBarTheme: AppBarThemeData(
      backgroundColor: rw.card,
      foregroundColor: rw.strong,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: rw.border)),
      titleTextStyle: text.titleLarge?.copyWith(fontSize: 19),
    ),
    cardTheme: CardThemeData(
      color: rw.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: rw.border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: rw.button,
        foregroundColor: Tw.white,
        disabledBackgroundColor: rw.neutralBg,
        disabledForegroundColor: rw.faint,
        shape: rounded,
        textStyle: semibold,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? Tw.slate200 : Tw.slate700,
        side: BorderSide(color: dark ? Tw.slate700 : Tw.slate300),
        shape: rounded,
        textStyle: semibold,
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: rw.brandFg, textStyle: semibold)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: rw.button, foregroundColor: Tw.white),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: rw.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 66,
      indicatorColor: rw.brandSoft,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? rw.brandFg : rw.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? rw.brandFg : rw.muted);
      }),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: rw.card,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: dark ? brand.s400 : brand.s600, width: 1.6)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: rw.card,
      selectedColor: rw.brandSoft,
      checkmarkColor: rw.brandFg,
      side: BorderSide(color: rw.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: rw.body, fontWeight: FontWeight.w500),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: rw.brandSoft,
        selectedForegroundColor: rw.brandFg,
        foregroundColor: rw.body,
        side: BorderSide(color: rw.border),
      ),
    ),
    listTileTheme: ListTileThemeData(iconColor: rw.muted),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: rw.brandFg),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? Tw.slate100 : Tw.slate900,
      contentTextStyle: TextStyle(color: dark ? Tw.slate900 : Tw.white),
      shape: rounded,
    ),
  );
}

// ---------- Light / Dark / System, remembered on the phone ----------

/// The app's light/dark setting. System (the default) follows the phone, like the website.
class ThemeController extends ChangeNotifier {
  static const _key = 'rankwise_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = switch (prefs.getString(_key)) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, mode.name);
    }
  }

  /// The sun / moon button: switch to the opposite of what is on screen now.
  Future<void> toggle(Brightness onScreen) => setMode(onScreen == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}

/// Makes the [ThemeController] available to every screen.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({super.key, required ThemeController controller, required super.child}) : super(notifier: controller);

  /// Rebuilds the caller when the setting changes.
  static ThemeController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.notifier!;

  /// Reads the controller without rebuilding (for button handlers).
  static ThemeController read(BuildContext context) => context.getInheritedWidgetOfExactType<ThemeScope>()!.notifier!;
}
