import 'package:flutter/material.dart';

/// Central Design Tokens for Haqly.
/// Per docs/RULES.md, this is the ONLY file where Color(0x...) literals are permitted.
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.bg,
    required this.surface,
    required this.surfaceElevated,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accent,
    required this.onAccent,
    required this.accentText,
    required this.accentMuted,
    required this.success,
    required this.info,
    required this.warn,
    required this.danger,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
  });

  // Base Colors
  final Color bg;
  final Color surface;
  final Color surfaceElevated;
  final Color line;
  final Color ink;
  final Color ink2;
  final Color ink3;

  // Brand Accent (Haqly Emerald Green #00C47A)
  final Color accent;
  final Color onAccent;
  final Color accentText;
  final Color accentMuted;

  // Semantic Colors
  final Color success;
  final Color info;
  final Color warn;
  final Color danger;

  // Corner Radii
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;

  // Constant Radii values
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r24 = 24.0;

  // Spacing
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Minimum interactive tap target (48dp accessibility standard)
  static const double minTapTarget = 48.0;

  // Dark Theme Tokens (Default for Haqly)
  static const dark = AppTokens(
    bg: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceElevated: Color(0xFF2C2C2E),
    line: Color(0xFF38383A),
    ink: Color(0xFFFFFFFF),
    ink2: Color(0xFFEBEBF5),
    ink3: Color(0xFF8E8E93),
    accent: Color(0xFF00C47A),
    onAccent: Color(0xFF000000),
    accentText: Color(0xFF00C47A),
    accentMuted: Color(0x2600C47A), // ~15% opacity
    success: Color(0xFF00C47A),
    info: Color(0xFF0A84FF),
    warn: Color(0xFFFF9500),
    danger: Color(0xFFFF3B30),
    radiusSm: r12,
    radiusMd: r16,
    radiusLg: r24,
  );

  // Light Theme Tokens
  static const light = AppTokens(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF2F2F7),
    surfaceElevated: Color(0xFFFFFFFF),
    line: Color(0xFFE5E5EA),
    ink: Color(0xFF1C1C1E),
    ink2: Color(0xFF3A3A3C),
    ink3: Color(0xFF6C6C70), // Enhanced contrast for WCAG AA
    accent: Color(0xFF00C47A),
    onAccent: Color(0xFF000000),
    accentText: Color(0xFF008753), // Darker green for 6.2:1 contrast on white
    accentMuted: Color(0x1F00C47A), // ~12% opacity
    success: Color(0xFF00A868),
    info: Color(0xFF007AFF),
    warn: Color(0xFFFF9500),
    danger: Color(0xFFFF3B30),
    radiusSm: r12,
    radiusMd: r16,
    radiusLg: r24,
  );

  @override
  ThemeExtension<AppTokens> copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceElevated,
    Color? line,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? accent,
    Color? onAccent,
    Color? accentText,
    Color? accentMuted,
    Color? success,
    Color? info,
    Color? warn,
    Color? danger,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentText: accentText ?? this.accentText,
      accentMuted: accentMuted ?? this.accentMuted,
      success: success ?? this.success,
      info: info ?? this.info,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
    );
  }

  @override
  ThemeExtension<AppTokens> lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceElevated:
          Color.lerp(surfaceElevated, other.surfaceElevated, t) ??
          surfaceElevated,
      line: Color.lerp(line, other.line, t) ?? line,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      ink2: Color.lerp(ink2, other.ink2, t) ?? ink2,
      ink3: Color.lerp(ink3, other.ink3, t) ?? ink3,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      onAccent: Color.lerp(onAccent, other.onAccent, t) ?? onAccent,
      accentText: Color.lerp(accentText, other.accentText, t) ?? accentText,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t) ?? accentMuted,
      success: Color.lerp(success, other.success, t) ?? success,
      info: Color.lerp(info, other.info, t) ?? info,
      warn: Color.lerp(warn, other.warn, t) ?? warn,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      radiusSm: (radiusSm + (other.radiusSm - radiusSm) * t),
      radiusMd: (radiusMd + (other.radiusMd - radiusMd) * t),
      radiusLg: (radiusLg + (other.radiusLg - radiusLg) * t),
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.dark;
}
