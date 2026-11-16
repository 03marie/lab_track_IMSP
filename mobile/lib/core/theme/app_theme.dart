import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

const _font = 'Jakarta';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final lab = dark ? LabColors.dark : LabColors.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: Palette.accent,
    onPrimary: Colors.white,
    secondary: Palette.teal,
    onSecondary: Colors.white,
    tertiary: Palette.ochre,
    onTertiary: Colors.white,
    error: Palette.rose,
    onError: Colors.white,
    surface: lab.surface,
    onSurface: lab.text,
    onSurfaceVariant: lab.textMuted,
    outline: lab.border,
    outlineVariant: lab.border,
    surfaceContainerLowest: lab.background,
    surfaceContainerLow: lab.surface,
    surfaceContainer: lab.surface,
    surfaceContainerHigh: lab.surfaceHigh,
    surfaceContainerHighest: lab.surfaceHigh,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: _font,
    scaffoldBackgroundColor: lab.background,
    extensions: [lab],
  );

  final text = base.textTheme
      .apply(bodyColor: lab.text, displayColor: lab.text)
      .copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.6, color: lab.text),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.4, color: lab.text),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.3, color: lab.text),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.2, color: lab.text),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: lab.text),
        titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: lab.text),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: lab.text, height: 1.4),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: lab.textMuted, height: 1.35),
      );

  final overlay = (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  );

  OutlineInputBorder bordure(Color c, [double largeur = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: largeur),
  );

  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: lab.text,
      centerTitle: false,
      systemOverlayStyle: overlay,
      titleTextStyle: text.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lab.surfaceHigh,
      hintStyle: TextStyle(color: lab.textMuted, fontWeight: FontWeight.w500),
      labelStyle: TextStyle(color: lab.textMuted, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(color: lab.accent, fontWeight: FontWeight.w600),
      prefixIconColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.focused) ? lab.accent : lab.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: bordure(lab.border),
      enabledBorder: bordure(lab.border),
      focusedBorder: bordure(lab.accent, 1.6),
      errorBorder: bordure(Palette.rose),
      focusedErrorBorder: bordure(Palette.rose, 1.6),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: lab.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: lab.textMuted.withValues(alpha: .5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lab.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: lab.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: lab.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink800,
      contentTextStyle: const TextStyle(fontFamily: _font, color: Colors.white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: lab.border, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: lab.accent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: lab.accent,
      selectionColor: lab.accent.withValues(alpha: .3),
      selectionHandleColor: lab.accent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()}),
  );
}
