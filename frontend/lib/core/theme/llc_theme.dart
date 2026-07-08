import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Technical Luxury" design system, per
/// `.claude/context/llc-standards/branding.md` and
/// `.claude/context/llc-flutter/refractive-glass.md`.
///
/// The LLC docs specify two materials (Glass Surface, Thermal Heat) and a
/// type pairing (Montserrat / Open Sans) but not a full app palette. The
/// rest of this token set (background depth, ink, the cool structural
/// accent) is composed around those two materials: a near-black
/// "instrument bezel" base so glass has something to refract, and a cool
/// cyan accent for static/structural state so the warm Thermal Heat
/// spectrum stays reserved for live interaction and error/loss signaling
/// (see [ThermalGlow] and `ColorScheme.error` below).
abstract final class LLCColors {
  // Bezel — the base the glass sits on.
  static const Color voidBlack = Color(0xFF0B0D10);
  static const Color panelElevated = Color(0xFF15181C);
  static const Color mist = Color(0xFFEEF1F3);
  static const Color mistElevated = Color(0xFFE1E5E8);

  // Ink.
  static const Color chromeWhite = Color(0xFFF4F6F8);
  static const Color steelGray = Color(0xFFA0A7AF);
  static const Color graphite = Color(0xFF14171B);
  static const Color graphiteSoft = Color(0xFF565C64);

  // Glass Surface (branding.md): base rgba(255,255,255,0.05), 20px blur.
  // Mirrored with a dark tint for light mode so glass still reads as a
  // lensed panel rather than a flat white card.
  static const Color glassFillDark = Color(0x0DFFFFFF); // white @ 5%
  static const Color glassBorderDark = Color(0x33FFFFFF); // white @ 20%
  static const Color glassFillLight = Color(0x0A000000); // black @ 4%
  static const Color glassBorderLight = Color(0x1F000000); // black @ 12%

  // Thermal Heat (branding.md): Core -> Corona, blend mode plus-lighter.
  static const Color thermalCore = Color(0xFFFF3B30);
  static const Color thermalCorona = Color(0xFFFF9500);

  // Structural accent — cool, quiet, used for focus/selection, never for
  // the interaction glow itself.
  static const Color instrumentCyan = Color(0xFF5FD4FF);
  static const Color instrumentCyanDeep = Color(0xFF0086A8);

  // Status, still paired with icon/label per the AA color-redundancy rule
  // (PRODUCT.md Accessibility & Inclusion) — only the *reservation* of red
  // to loss-only was superseded, not the redundancy requirement itself.
  static const Color affirmMint = Color(0xFF35D68C);
  static const Color affirmMintDeep = Color(0xFF13875A);
}

abstract final class LLCTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? LLCColors.instrumentCyan : LLCColors.instrumentCyanDeep,
      onPrimary: isDark ? LLCColors.voidBlack : LLCColors.mist,
      secondary: isDark ? LLCColors.steelGray : LLCColors.graphiteSoft,
      onSecondary: isDark ? LLCColors.voidBlack : LLCColors.mist,
      tertiary: isDark ? LLCColors.affirmMint : LLCColors.affirmMintDeep,
      onTertiary: isDark ? LLCColors.voidBlack : LLCColors.mist,
      error: LLCColors.thermalCore,
      onError: LLCColors.chromeWhite,
      surface: isDark ? LLCColors.voidBlack : LLCColors.mist,
      onSurface: isDark ? LLCColors.chromeWhite : LLCColors.graphite,
      surfaceContainerHighest:
          isDark ? LLCColors.panelElevated : LLCColors.mistElevated,
      onSurfaceVariant: isDark ? LLCColors.steelGray : LLCColors.graphiteSoft,
      outline: isDark ? LLCColors.glassBorderDark : LLCColors.glassBorderLight,
      outlineVariant:
          isDark ? LLCColors.glassFillDark : LLCColors.glassFillLight,
      shadow: Colors.black,
      inverseSurface: isDark ? LLCColors.chromeWhite : LLCColors.graphite,
      onInverseSurface: isDark ? LLCColors.voidBlack : LLCColors.mist,
    );

    final baseText = isDark
        ? GoogleFonts.openSansTextTheme(ThemeData(brightness: brightness).textTheme)
        : GoogleFonts.openSansTextTheme(ThemeData(brightness: brightness).textTheme);

    // Headline/structural clarity: Montserrat Bold/ExtraBold.
    // Body/dense technical reading: Open Sans Light/Regular.
    final textTheme = baseText.copyWith(
      displayLarge: GoogleFonts.montserrat(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.montserrat(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.02,
        color: colorScheme.onSurface,
      ),
      displaySmall: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.015,
        color: colorScheme.onSurface,
      ),
      headlineLarge: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01,
        color: colorScheme.onSurface,
      ),
      headlineMedium: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      headlineSmall: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      titleLarge: GoogleFonts.montserrat(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: GoogleFonts.montserrat(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleSmall: GoogleFonts.montserrat(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyLarge: GoogleFonts.openSans(
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.openSans(
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodySmall: GoogleFonts.openSans(
        fontWeight: FontWeight.w300,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.openSans(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.04,
        color: colorScheme.onSurface,
      ),
      labelMedium: GoogleFonts.openSans(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.04,
        color: colorScheme.onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.openSans(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.06,
        color: colorScheme.onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      // Transparent so MeshBackdrop (wired in via MaterialApp.router's
      // `builder`) shows through every screen — RefractiveGlass needs
      // non-flat content behind it to actually refract anything.
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      dividerColor: colorScheme.outline,
      // Opaque fallback (not glass) for any Card usage not yet migrated to
      // RefractiveGlass, so those screens stay legible against the
      // transparent scaffold instead of rendering with no fill at all.
      cardColor: colorScheme.surfaceContainerHighest,
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? LLCColors.glassFillDark : LLCColors.glassFillLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline, width: 0.75),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline, width: 0.75),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
    );
  }
}
