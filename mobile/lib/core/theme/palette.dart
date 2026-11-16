import 'package:flutter/material.dart';

/// Palette LabTrack — sobre et institutionnelle.
///
/// Un seul bleu posé comme couleur d'accent, des neutres légèrement froids,
/// des couleurs de statut atténuées. Pas de dégradés ni de halos : des aplats.
abstract final class Palette {
  // Accent (boutons, éléments actifs)
  static const accent = Color(0xFF3A5FD0);

  // Teintes secondaires, volontairement posées
  static const teal = Color(0xFF2F8C8C);
  static const ochre = Color(0xFFB7832B);

  // Statuts
  static const emerald = Color(0xFF2E9467);
  static const amber = Color(0xFFC48A1C);
  static const rose = Color(0xFFD0505F);
  static const slate = Color(0xFF8A93A3);

  // Neutres sombres utilisés ponctuellement (caméra, messages)
  static const ink950 = Color(0xFF080A0E);
  static const ink800 = Color(0xFF1B2029);
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
    required this.accent,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color textMuted;

  /// Accent lisible en texte/icône sur le fond du thème (plus clair en mode sombre).
  final Color accent;
  final Color shadow;

  static const dark = LabColors(
    background: Color(0xFF0F1217),
    surface: Color(0xFF171B22),
    surfaceHigh: Color(0xFF1F242D),
    border: Color(0xFF2C333E),
    text: Color(0xFFEAECF0),
    textMuted: Color(0xFF9097A4),
    accent: Color(0xFF86A2EE),
    shadow: Color(0x66000000),
  );

  static const light = LabColors(
    background: Color(0xFFF1F2F5),
    surface: Colors.white,
    surfaceHigh: Color(0xFFF0F2F6),
    border: Color(0xFFD5DAE2),
    text: Color(0xFF14171F),
    textMuted: Color(0xFF586070),
    accent: Color(0xFF2F52C0),
    shadow: Color(0x1F101828),
  );

  @override
  LabColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? shadow,
  }) => LabColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceHigh: surfaceHigh ?? this.surfaceHigh,
    border: border ?? this.border,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    accent: accent ?? this.accent,
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
      accent: Color.lerp(accent, other.accent, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension LabThemeContext on BuildContext {
  LabColors get lab => Theme.of(this).extension<LabColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Couleur d'accent lisible sur le fond du thème courant.
  Color get accent => lab.accent;

  /// Version d'une couleur de statut lisible sur le fond du thème (assombrie en mode clair).
  Color lisible(Color c) => isDark ? c : Color.lerp(c, Colors.black, .38)!;
}
