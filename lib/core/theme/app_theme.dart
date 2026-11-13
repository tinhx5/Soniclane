import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sonic_tokens.dart';

class AppTheme {
  static TextStyle _displayStyle(
    bool useGoogleFonts, {
    required double fontSize,
    required FontWeight fontWeight,
    Color color = SonicTokens.textPrimary,
    double letterSpacing = 0.0,
  }) {
    if (useGoogleFonts) {
      return GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle _bodyStyle(
    bool useGoogleFonts, {
    required double fontSize,
    required FontWeight fontWeight,
    Color color = SonicTokens.onSurface,
  }) {
    if (useGoogleFonts) {
      return GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static ThemeData darkCockpitTheme({bool useGoogleFonts = true}) {
    final baseText = ThemeData.dark().textTheme;
    final jakartaBody = useGoogleFonts
        ? GoogleFonts.plusJakartaSansTextTheme(baseText)
        : baseText;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SonicTokens.surfaceBase,
      canvasColor: SonicTokens.surfaceBase,
      colorScheme: const ColorScheme.dark(
        primary: SonicTokens.primaryRed,
        primaryContainer: SonicTokens.primaryContainer,
        onPrimary: SonicTokens.textPrimary,
        secondary: SonicTokens.secondaryContainer,
        secondaryContainer: SonicTokens.secondaryBlue,
        onSecondary: SonicTokens.surfaceBase,
        tertiary: SonicTokens.tertiaryTeal,
        tertiaryContainer: SonicTokens.tertiaryBlue,
        surface: SonicTokens.surface,
        surfaceContainerLowest: SonicTokens.surfaceLowest,
        surfaceContainerLow: SonicTokens.surfaceLow,
        surfaceContainer: SonicTokens.surfaceContainer,
        surfaceContainerHigh: SonicTokens.surfaceHigh,
        surfaceContainerHighest: SonicTokens.surfaceHighest,
        onSurface: SonicTokens.onSurface,
        onSurfaceVariant: SonicTokens.textSecondary,
        error: SonicTokens.errorRed,
        outline: SonicTokens.textTertiary,
        outlineVariant: SonicTokens.divider,
      ),
      textTheme: jakartaBody.copyWith(
        headlineLarge: _displayStyle(
          useGoogleFonts,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.02 * 32,
        ),
        headlineMedium: _displayStyle(
          useGoogleFonts,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.01 * 24,
        ),
        headlineSmall: _displayStyle(
          useGoogleFonts,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: _bodyStyle(
          useGoogleFonts,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: SonicTokens.textPrimary,
        ),
        titleMedium: _bodyStyle(
          useGoogleFonts,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: SonicTokens.textPrimary,
        ),
        bodyLarge: _bodyStyle(
          useGoogleFonts,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: _bodyStyle(
          useGoogleFonts,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: _bodyStyle(
          useGoogleFonts,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: SonicTokens.textSecondary,
        ),
        labelLarge: _displayStyle(
          useGoogleFonts,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
        labelMedium: _displayStyle(
          useGoogleFonts,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: SonicTokens.textSecondary,
          letterSpacing: 0.7,
        ),
        labelSmall: _displayStyle(
          useGoogleFonts,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: SonicTokens.textSecondary,
          letterSpacing: 0.9,
        ),
      ),
      cardTheme: CardTheme(
        color: SonicTokens.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SonicTokens.radiusXl),
          side: const BorderSide(color: SonicTokens.glassBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SonicTokens.surfaceHigh,
        hintStyle: _bodyStyle(
          useGoogleFonts,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: SonicTokens.textTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SonicTokens.spaceMd,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
          borderSide: const BorderSide(color: SonicTokens.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
          borderSide: const BorderSide(color: SonicTokens.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
          borderSide:
              const BorderSide(color: SonicTokens.secondaryBlue, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(SonicTokens.textPrimary),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return SonicTokens.secondaryContainer;
          }
          return SonicTokens.surfaceHighest;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: SonicTokens.secondaryContainer,
        inactiveTrackColor: SonicTokens.surfaceHighest,
        thumbColor: SonicTokens.textPrimary,
        overlayColor: SonicTokens.secondaryContainer.withOpacity(0.25),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      dividerTheme: const DividerThemeData(
        color: SonicTokens.divider,
        thickness: 1,
      ),
    );
  }
}
