import 'package:flutter/material.dart';

/// Design tokens derived directly from `Cockpit Dynamic` (`DESIGN.md`)
/// and the Soniclane Design System specification.
abstract final class SonicTokens {
  // --- Surface Tiers (OLED Dark-First) ---
  static const Color surfaceBase = Color(0xFF0D0F12);
  static const Color surface = Color(0xFF111317);
  static const Color surfaceLowest = Color(0xFF0C0E11);
  static const Color surfaceLow = Color(0xFF1A1C1F);
  static const Color surfaceCard = Color(0xFF1A1D24);
  static const Color surfaceContainer = Color(0xFF1E2023);
  static const Color surfaceElevated = Color(0xFF242832);
  static const Color surfaceHigh = Color(0xFF282A2D);
  static const Color surfaceHighest = Color(0xFF333538);
  static const Color surfaceBright = Color(0xFF37393D);

  // --- Primary & Accents ---
  static const Color primaryRed = Color(0xFFFF0033);
  static const Color primaryContainer = Color(0xFFFF5357);
  static const Color primaryTint = Color(0xFFFFB3AF);
  static const Color onPrimaryContainer = Color(0xFF5C000B);

  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color secondaryContainer = Color(0xFF00D2FF);
  static const Color secondaryLight = Color(0xFFA5E7FF);
  static const Color onSecondaryContainer = Color(0xFF00566A);

  static const Color tertiaryTeal = Color(0xFF008CA7);
  static const Color tertiaryBlue = Color(0xFF4D8EFF);
  static const Color tertiaryLight = Color(0xFFADC6FF);

  // --- Semantic Status Colors ---
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFFFB4AB);

  // --- Typography Colors ---
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFFE2E2E6);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textVariant = Color(0xFFE9BCB9);

  // --- Borders & Dividers ---
  static const Color glassBorder = Color(0x14FFFFFF);
  static const Color activeBorderBlue = Color(0x4D3B82F6);
  static const Color activeBorderCyan = Color(0x4D00D2FF);
  static const Color divider = Color(0xFF1F232B);

  // --- Ergonomic Automotive Dimensions ---
  static const double minTouchTarget = 56.0;
  static const double carTouchTarget = 64.0;
  static const double primaryPlaySize = 72.0;
  static const double mobilePlaySize = 80.0;
  static const double railWidth = 84.0;

  // --- Corner Radii ---
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radius2Xl = 24.0;

  // --- Spacing ---
  static const double spaceXs = 6.0;
  static const double spaceSm = 12.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  // --- Photonic Glows (Replacing murky dark shadows) ---
  static List<BoxShadow> crimsonGlow({double opacity = 0.38}) => [
        BoxShadow(
          color: primaryRed.withOpacity(opacity),
          blurRadius: 24,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> cyanGlow({double opacity = 0.28}) => [
        BoxShadow(
          color: secondaryContainer.withOpacity(opacity),
          blurRadius: 22,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> blueGlow({double opacity = 0.30}) => [
        BoxShadow(
          color: secondaryBlue.withOpacity(opacity),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ];
}
