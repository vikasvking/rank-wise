import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upsc_questions_app/core/palette.dart';
import 'package:upsc_questions_app/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('brand colour follows the role, as on the website', () {
    expect(Ramp.forRole('student'), same(Ramp.rose));
    expect(Ramp.forRole(null), same(Ramp.rose)); // signed out
    expect(Ramp.forRole('teacher'), same(Ramp.indigo));
    expect(Ramp.forRole('admin'), same(Ramp.emerald));
  });

  test('light and dark themes use the website palette', () {
    final light = buildTheme(Brightness.light, Ramp.rose);
    final dark = buildTheme(Brightness.dark, Ramp.rose);

    expect(light.scaffoldBackgroundColor, Tw.slate50);
    expect(dark.scaffoldBackgroundColor, Tw.slate950);
    expect(light.extension<Rw>()!.card, Tw.white);
    expect(dark.extension<Rw>()!.card, Tw.slate900);
    // filled buttons are brand-700 in both themes
    expect(light.filledButtonTheme.style!.backgroundColor!.resolve(<WidgetState>{}), Ramp.rose.s700);
    expect(dark.filledButtonTheme.style!.backgroundColor!.resolve(<WidgetState>{}), Ramp.rose.s700);
  });

  test('the light / dark choice is remembered; System is the default', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ThemeController();
    await first.load();
    expect(first.mode, ThemeMode.system);

    await first.toggle(Brightness.light);
    expect(first.mode, ThemeMode.dark);

    final again = ThemeController();
    await again.load();
    expect(again.mode, ThemeMode.dark);

    await again.setMode(ThemeMode.system);
    final third = ThemeController();
    await third.load();
    expect(third.mode, ThemeMode.system);
  });
}
