import 'package:flutter/material.dart';
import 'package:haqly_mobile/core/theme/tokens.dart';

ThemeData createLightTheme() {
  const tokens = AppTokens.light;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: tokens.bg,
    colorScheme: ColorScheme.light(
      surface: tokens.surface,
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
      secondary: tokens.accentText,
      error: tokens.danger,
      onError: tokens.ink,
      outline: tokens.line,
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        side: BorderSide(color: tokens.line, width: 1.0),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.bg,
      foregroundColor: tokens.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: tokens.bg,
      selectedItemColor: tokens.accentText,
      unselectedItemColor: tokens.ink3,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(color: tokens.line, thickness: 1),
    extensions: const <ThemeExtension<dynamic>>[tokens],
  );
}
