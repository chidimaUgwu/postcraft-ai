// lib/utils/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Primary brand = deep purple, secondary accent = vibrant orange.
  // Plus a near-black anchor for typography + a warm ink for headers.
  static const Color primary    = Color(0xFF7C3AED); // violet-600
  static const Color primaryDeep = Color(0xFF5B21B6); // violet-800
  static const Color secondary  = Color(0xFFF97316); // orange-500
  static const Color accent     = Color(0xFFFBBF24); // amber-400 (highlights)
  static const Color ink        = Color(0xFF0B0B0F); // deep black for hero headers
  static const Color background = Color(0xFFFAF7FF); // soft violet-tinted neutral
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color error      = Color(0xFFDC2626);
  static const Color textDark   = Color(0xFF111827);
  static const Color textMid    = Color(0xFF6B7280);
  static const Color textLight  = Color(0xFF9CA3AF);
  static const Color border     = Color(0xFFE5E7EB);

  static const Map<String, Color> platformColors = {
    'whatsapp':  Color(0xFF25D366),
    'instagram': Color(0xFFE1306C),
    'facebook':  Color(0xFF1877F2),
    'twitter':   Color(0xFF1DA1F2),
    'linkedin':  Color(0xFF0A66C2),
    'tiktok':    Color(0xFF010101),
  };

  static const Map<String, IconData> platformIcons = {
    'whatsapp':  Icons.chat,
    'instagram': Icons.camera_alt,
    'facebook':  Icons.facebook,
    'twitter':   Icons.alternate_email,
    'linkedin':  Icons.work,
    'tiktok':    Icons.music_note,
  };

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface, foregroundColor: textDark,
          elevation: 0, centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textDark),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primary, width: 2)),
          errorBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: error)),
        ),
        cardTheme: CardThemeData(
          color: surface, elevation: 2, shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  // Dark theme counterpart.
  static const Color darkBg      = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder  = Color(0xFF334155);

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: primary, brightness: Brightness.dark),
        scaffoldBackgroundColor: darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkSurface, foregroundColor: Colors.white,
          elevation: 0, centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        // Readable defaults for every Text widget in dark mode.
        textTheme: const TextTheme(
          displayLarge:  TextStyle(color: Colors.white),
          displayMedium: TextStyle(color: Colors.white),
          displaySmall:  TextStyle(color: Colors.white),
          headlineLarge: TextStyle(color: Colors.white),
          headlineMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Colors.white),
          titleLarge:    TextStyle(color: Colors.white),
          titleMedium:   TextStyle(color: Colors.white),
          titleSmall:    TextStyle(color: Colors.white),
          bodyLarge:     TextStyle(color: Colors.white),
          bodyMedium:    TextStyle(color: Colors.white),
          bodySmall:     TextStyle(color: Color(0xFFBFC3CC)),
          labelLarge:    TextStyle(color: Colors.white),
          labelMedium:   TextStyle(color: Colors.white),
          labelSmall:    TextStyle(color: Color(0xFFBFC3CC)),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        dividerColor: darkBorder,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: darkSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: Color(0xFF8A90A0)),
          labelStyle: const TextStyle(color: Colors.white70),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: darkBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: darkBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primary, width: 2)),
          errorBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: error)),
        ),
        cardTheme: CardThemeData(
          color: darkSurface, elevation: 2, shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  // ── Context-aware colour helpers ─────────────────────────────────────
  // Use these instead of the hardcoded `AppTheme.textDark` / `textMid` /
  // `border` constants when rendering widgets that must adapt to dark mode.
  // The static constants are kept for backwards compatibility but should
  // be phased out for text.

  /// Primary body-text colour that flips to white in dark mode.
  static Color onSurface(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSurface;

  /// Muted/secondary text (subtitles, hints). ~60% opacity of on-surface.
  static Color onSurfaceMuted(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSurface.withOpacity(0.65);

  /// Even fainter text (placeholders, disabled).
  static Color onSurfaceFaint(BuildContext ctx) =>
      Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4);

  /// Border / outline colour.
  static Color outline(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? darkBorder : border;

  /// Surface fill for chips / cards that sit on the scaffold bg.
  static Color surfaceOf(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? darkSurface : surface;
}

/// Supported currency codes + symbols used across the app.
class AppCurrencies {
  static const Map<String, Map<String, String>> byCode = {
    'NGN': {'symbol': '₦', 'label': 'Nigerian Naira (₦)'},
    'USD': {'symbol': '\$', 'label': 'US Dollar (\$)'},
    'GHS': {'symbol': 'GH₵', 'label': 'Ghanaian Cedi (GH₵)'},
    'EUR': {'symbol': '€', 'label': 'Euro (€)'},
    'GBP': {'symbol': '£', 'label': 'British Pound (£)'},
    'KES': {'symbol': 'KSh', 'label': 'Kenyan Shilling (KSh)'},
    'ZAR': {'symbol': 'R', 'label': 'South African Rand (R)'},
    'XAF': {'symbol': 'FCFA', 'label': 'Central African Franc (FCFA)'},
    'XOF': {'symbol': 'CFA', 'label': 'West African Franc (CFA)'},
  };

  static String symbolFor(String code) => byCode[code]?['symbol'] ?? '₦';
}

class AppLanguages {
  static const Map<String, String> byCode = {
    'en': 'English',
    'fr': 'Français',
    'pt': 'Português',
    'es': 'Español',
    'pidgin': 'Nigerian Pidgin',
    'sw': 'Swahili',
    'ar': 'العربية',
  };
}

class AppCountries {
  static const List<String> list = [
    'Nigeria', 'Ghana', 'Kenya', 'South Africa', 'Cameroon', 'Ivory Coast',
    'Senegal', 'Egypt', 'Morocco', 'Tanzania', 'Uganda', 'Rwanda',
    'United Kingdom', 'United States', 'Canada', 'France', 'Germany',
    'United Arab Emirates', 'Other',
  ];
}

class AppConstants {
  static const List<String> propertyTypes = [
    'single_room','self_contain','mini_flat','flat',
    'apartment','duplex','bungalow','mansion','office','shop','warehouse',
  ];
  static const List<String> pricePeriods = ['monthly','yearly','outright'];
  static const List<String> platforms    = ['whatsapp','instagram','facebook','twitter','linkedin','tiktok'];
  static const List<String> extraFeatureOptions = [
    'Gate','Fence','Borehole','Swimming pool','Generator',
    'Air conditioning','Tiled floors','CCTV','Security guard',
    'Pop ceiling','Wardrobe','Kitchen cabinet','Balcony','Gym',
    'Solar panels','Laundry room','Smart home',
  ];

  static String formatPropertyType(String t) =>
      t.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  static String formatPrice(double price) {
    if (price >= 1000000) return '₦${(price / 1000000).toStringAsFixed(1)}M';
    if (price >= 1000)    return '₦${(price / 1000).toStringAsFixed(0)}K';
    return '₦${price.toStringAsFixed(0)}';
  }
}
