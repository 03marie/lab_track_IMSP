import 'package:flutter/material.dart';

/// Palette LabTrack — « Nuit d'encre & Aurore ».
///
/// Un fond encre profond, une signature en dégradé iris → aqua,
/// et une touche d'or pour les détails précieux.
abstract final class Palette {
  // Encres (mode sombre)
  static const ink950 = Color(0xFF05070D);
  static const ink900 = Color(0xFF0A0E1A);
  static const ink850 = Color(0xFF0F1424);
  static const ink800 = Color(0xFF151B2E);
  static const ink700 = Color(0xFF1E2640);
  static const ink600 = Color(0xFF2A3354);

  // Porcelaines (mode clair)
  static const porcelain = Color(0xFFF5F6FB);
  static const mist = Color(0xFFE8EAF3);

  // Signature
  static const iris = Color(0xFF7C5CFF);
  static const violet = Color(0xFFA78BFA);
  static const aqua = Color(0xFF22D3EE);
  static const gold = Color(0xFFF2C46D);
  static const goldDeep = Color(0xFFB7791F); // or lisible sur fond clair

  // Statuts
  static const emerald = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const rose = Color(0xFFFB7185);
  static const slate = Color(0xFF94A3B8);

  static const signature = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [iris, aqua]);

  static const signatureSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6D4DFF), Color(0xFF8B5CF6), Color(0xFF22D3EE)],
    stops: [0, .45, 1],
  );
}

/// Couleurs dépendant du thème (sombre / clair), accessibles via `context.lab`.
@immutable
class LabColors extends ThemeExtension<LabColors> {
  const LabColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.glass,
    required this.glassBorder,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color glass;
  final Color glassBorder;
  final Color shadow;

  static const dark = LabColors(
    background: Palette.ink900,
    surface: Palette.ink850,
    surfaceHigh: Palette.ink800,
    border: Color(0x14FFFFFF),
    text: Color(0xFFF4F6FB),
    textMuted: Color(0xFF8A93AD),
    glass: Color(0x991A2138),
    glassBorder: Color(0x1FFFFFFF),
    shadow: Color(0x66000000),
  );

  static const light = LabColors(
    background: Palette.porcelain,
    surface: Colors.white,
    surfaceHigh: Color(0xFFF0F1F8),
    border: Color(0xFFE4E6F0),
    text: Color(0xFF0E1322),
    textMuted: Color(0xFF5E6781),
    glass: Color(0xCCFFFFFF),
    glassBorder: Color(0x14000000),
    shadow: Color(0x1A1E2640),
  );

  @override
  LabColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? glass,
    Color? glassBorder,
    Color? shadow,
  }) => LabColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    border: border ?? this.border,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    glass: glass ?? this.glass,
    glassBorder: glassBorder ?? this.glassBorder,
    shadow: shadow ?? this.shadow,
  );

  @override
  LabColors lerp(LabColors? other, double t) {
    if (other == null) return this;
    return LabColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension LabThemeContext on BuildContext {
  LabColors get lab => Theme.of(this).extension<LabColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Or adapté au thème (contraste suffisant en mode clair).
  Color get or => isDark ? Palette.gold : Palette.goldDeep;
}
