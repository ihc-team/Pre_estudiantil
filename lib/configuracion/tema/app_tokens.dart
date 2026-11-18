import 'package:flutter/material.dart';

// Tokens oficiales del Sistema de Diseño de UniBudget (Clase 23)
//
// La nomenclatura semantica coincide exactamente con las variables de Figma
// - Colores -> color/*
// - Tipografia -> typography/*
// - Espaciado -> spacing/*
// - Radios -> radius/*
abstract class AppColors {
  static const Color primary = Color(0xFF0B6B5F);

  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color primaryContainer = Color(0xFFCFE3DE);

  static const Color onPrimaryContainer = Color(0xFF0B6B5F);

  static const Color background = Color(0xFFF7F9F9);

  static const Color surface = Color(0xFFFFFFFF);

  static const Color transparent = Colors.transparent;

  static const Color textPrimary = Color(0xFF0F1B3D);

  static const Color textSecondary = Color(0xFF6B7494);

  static const Color border = Color(0xFFE1E6E5);

  static const Color borderStrong = Color(0xFFCFE3DE);

  static const Color statusNormal = Color(0xFF0B6B5F);

  static const Color statusNormalContainer = Color(0xFFE3EFEA);

  static const Color statusWarning = Color(0xFF8A5A00);

  static const Color statusWarningContainer = Color(0xFFFFF3D6);

  static const Color statusExceeded = Color(0xFFD32F2F);

  static const Color statusExceededContainer = Color(0xFFFDE8E8);

  static const Color error = statusExceeded;
  static const Color onError = Colors.white;
  static const Color errorContainer = statusExceededContainer;
  static const Color onErrorContainer = statusExceeded;
}

abstract class AppTypography {
  /// Figma: `typography/display/hero` (54px, bold, h: 56px, ls: -1) - Logo de marca
  static const TextStyle displayHero = TextStyle(
    fontSize: 54,
    height: 56 / 54,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLargeSemiBold = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// Figma: `typography/label/tracking` (12px, semibold, ls: 4) - Eslogan en mayúsculas
  static const TextStyle labelTracking = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 4,
    color: AppColors.textSecondary,
  );
}

abstract class AppSpacing {
  static const double xs = 4.0;

  static const double sm = 8.0;

  static const double md = 12.0;

  static const double lg = 16.0;

  static const double xl = 20.0;

  static const double xxl = 24.0;

  static const double xxxl = 32.0;

  static const double hero = 48.0;

  // Paddings de conveniencia
  static const EdgeInsets paddingScreen = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets paddingCard = EdgeInsets.all(lg);
  static const EdgeInsets paddingModal = EdgeInsets.all(xxl);
}

// Escala oficial de radios de curvatura
abstract class AppRadius {
  static const double sm = 8.0;

  static const double card = 16.0;

  static const double modal = 24.0;

  static const double pill = 999.0;

  // BorderRadius de conveniencia
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderCard = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius borderModal = BorderRadius.all(
    Radius.circular(modal),
  );
  static const BorderRadius borderPill = BorderRadius.all(
    Radius.circular(pill),
  );
}

abstract class AppSizes {
  static const double touchTargetMin = 48.0;

  static const double buttonHeight = 54.0;
}
