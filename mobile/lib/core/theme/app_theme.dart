import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

const _font = 'Jakarta';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final lab = dark ? LabColors.dark : LabColors.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: Palette.iris,
    onPrimary: Colors.white,
    secondary: Palette.aqua,
    onSecondary: Palette.ink950,
    tertiary: Palette.gold,
    onTertiary: Palette.ink950,
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
        displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.2, color: lab.text),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.8, color: lab.text),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.5, color: lab.text),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.3, color: lab.text),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: lab.text),
        labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: .2),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: lab.text, height: 1.4),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: lab.textMuted, height: 1.35),
      );

  final overlay = (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
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
      fillColor: dark ? const Color(0x0DFFFFFF) : const Color(0xFFF2F3F9),
      hintStyle: TextStyle(color: lab.textMuted, fontWeight: FontWeight.w500),
      labelStyle: TextStyle(color: lab.textMuted, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: Palette.violet, fontWeight: FontWeight.w600),
      prefixIconColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.focused) ? Palette.violet : lab.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: lab.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: lab.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Palette.iris, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Palette.rose),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Palette.rose, width: 1.6),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: lab.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: lab.textMuted.withValues(alpha: .4),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lab.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? Palette.ink700 : Palette.ink800,
      contentTextStyle: const TextStyle(fontFamily: _font, color: Colors.white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: lab.border, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Palette.iris),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Palette.iris,
      selectionColor: Palette.iris.withValues(alpha: .3),
      selectionHandleColor: Palette.iris,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()}),
    splashFactory: InkSparkle.splashFactory,
  );
}
