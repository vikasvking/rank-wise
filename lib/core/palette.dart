import 'dart:ui' show Color;

/// The Tailwind colours the Rankwise website uses (app/assets/tailwind/application.css and the view classes),
/// so the app matches the site shade for shade.
abstract final class Tw {
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);

  static const red50 = Color(0xFFFEF2F2);
  static const red200 = Color(0xFFFECACA);
  static const red300 = Color(0xFFFCA5A5);
  static const red400 = Color(0xFFF87171);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
  static const red800 = Color(0xFF991B1B);
  static const red950 = Color(0xFF450A0A);

  static const emerald50 = Color(0xFFECFDF5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald300 = Color(0xFF6EE7B7);
  static const emerald400 = Color(0xFF34D399);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const emerald800 = Color(0xFF065F46);
  static const emerald950 = Color(0xFF022C22);

  static const amber50 = Color(0xFFFFFBEB);
  static const amber200 = Color(0xFFFDE68A);
  static const amber300 = Color(0xFFFCD34D);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber700 = Color(0xFFB45309);
  static const amber800 = Color(0xFF92400E);
  static const amber900 = Color(0xFF78350F);
  static const amber950 = Color(0xFF451A03);

  static const sky50 = Color(0xFFF0F9FF);
  static const sky200 = Color(0xFFBAE6FD);
  static const sky300 = Color(0xFF7DD3FC);
  static const sky600 = Color(0xFF0284C7);
  static const sky700 = Color(0xFF0369A1);
  static const sky950 = Color(0xFF082F49);

  static const pink50 = Color(0xFFFDF2F8);
  static const pink200 = Color(0xFFFBCFE8);
  static const pink900 = Color(0xFF831843);
  static const pink950 = Color(0xFF500724);

  static const white = Color(0xFFFFFFFF);
}

/// One Tailwind colour from 50 (lightest) to 950 (darkest).
class Ramp {
  const Ramp(
    this.s50,
    this.s100,
    this.s200,
    this.s300,
    this.s400,
    this.s500,
    this.s600,
    this.s700,
    this.s800,
    this.s900,
    this.s950,
  );

  final Color s50, s100, s200, s300, s400, s500, s600, s700, s800, s900, s950;

  static const rose = Ramp(
    Color(0xFFFFF1F2),
    Color(0xFFFFE4E6),
    Color(0xFFFECDD3),
    Color(0xFFFDA4AF),
    Color(0xFFFB7185),
    Color(0xFFF43F5E),
    Color(0xFFE11D48),
    Color(0xFFBE123C),
    Color(0xFF9F1239),
    Color(0xFF881337),
    Color(0xFF4C0519),
  );
  static const indigo = Ramp(
    Color(0xFFEEF2FF),
    Color(0xFFE0E7FF),
    Color(0xFFC7D2FE),
    Color(0xFFA5B4FC),
    Color(0xFF818CF8),
    Color(0xFF6366F1),
    Color(0xFF4F46E5),
    Color(0xFF4338CA),
    Color(0xFF3730A3),
    Color(0xFF312E81),
    Color(0xFF1E1B4B),
  );
  static const emerald = Ramp(
    Color(0xFFECFDF5),
    Color(0xFFD1FAE5),
    Color(0xFFA7F3D0),
    Color(0xFF6EE7B7),
    Color(0xFF34D399),
    Color(0xFF10B981),
    Color(0xFF059669),
    Color(0xFF047857),
    Color(0xFF065F46),
    Color(0xFF064E3B),
    Color(0xFF022C22),
  );

  /// The website's "brand" colour: students and visitors rose (burgundy), teachers indigo, admins emerald.
  static Ramp forRole(String? role) => switch (role) {
    'teacher' => indigo,
    'admin' => emerald,
    _ => rose,
  };
}

/// Exam chips in each exam's own colour, as on the website (TestStylesHelper::EXAM_CHIP_CLASSES).
/// (light background, light text, dark text); the dark background is the 950 shade at 40%.
const Map<String, (Color, Color, Color, Color)> kExamChipColors = {
  'UPSC_PRELIMS': (
    Color(0xFFEEF2FF),
    Color(0xFF4338CA),
    Color(0xFFA5B4FC),
    Color(0xFF1E1B4B),
  ),
  'JEE_MAIN': (
    Color(0xFFFFF7ED),
    Color(0xFFC2410C),
    Color(0xFFFDBA74),
    Color(0xFF431407),
  ),
  'JEE_ADVANCED': (
    Color(0xFFFDF4FF),
    Color(0xFFA21CAF),
    Color(0xFFF0ABFC),
    Color(0xFF4A044E),
  ),
  'NEET': (
    Color(0xFFF0FDFA),
    Color(0xFF0F766E),
    Color(0xFF5EEAD4),
    Color(0xFF042F2E),
  ),
  'SSC_CHSL': (
    Color(0xFFF5F3FF),
    Color(0xFF6D28D9),
    Color(0xFFC4B5FD),
    Color(0xFF2E1065),
  ),
  'SSC_CGL': (
    Color(0xFFFAF5FF),
    Color(0xFF7E22CE),
    Color(0xFFD8B4FE),
    Color(0xFF3B0764),
  ),
  'CBSE_XII': (
    Color(0xFFECFEFF),
    Color(0xFF0E7490),
    Color(0xFF67E8F9),
    Color(0xFF083344),
  ),
  'CBSE_X': (
    Color(0xFFEFF6FF),
    Color(0xFF1D4ED8),
    Color(0xFF93C5FD),
    Color(0xFF172554),
  ),
  'IBPS': (
    Color(0xFFFEFCE8),
    Color(0xFF854D0E),
    Color(0xFFFDE047),
    Color(0xFF422006),
  ),
};
