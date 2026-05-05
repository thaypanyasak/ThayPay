import 'package:flutter/material.dart';
import 'package:mix/mix.dart';

class AppTokens {
  // Colors
  static const bg = ColorToken('app.bg');
  static const surface = ColorToken('app.surface');
  static const surface2 = ColorToken('app.surface2');
  static const text = ColorToken('app.text');
  static const muted = ColorToken('app.muted');
  static const accent = ColorToken('app.accent');

  // Radii
  static const cameraRadius = RadiusToken('app.radius.camera');
  static const round = RadiusToken('app.radius.round');
}

MixThemeData buildAppMixTheme() {
  return MixThemeData.withMaterial(
    colors: {
      // Deep Black
      AppTokens.bg: const Color(0xFF000000),
      // Dark greys
      AppTokens.surface: const Color(0xFF111111),
      AppTokens.surface2: const Color(0xFF1A1A1A),
      // Text
      AppTokens.text: const Color(0xFFFFFFFF),
      AppTokens.muted: const Color(0xFFBDBDBD),
      // Vibrant Pink/Purple accent
      AppTokens.accent: const Color(0xFFB64CFF),
    },
    radii: {
      AppTokens.cameraRadius: const Radius.circular(40),
      AppTokens.round: const Radius.circular(999),
    },
  );
}

ThemeData buildAppTheme() {
  const accent = Color(0xFFB64CFF);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF000000),
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: Color(0xFF111111),
      onSurface: Color(0xFFFFFFFF),
    ),
  );
}
