import 'package:flutter/cupertino.dart';

class AppColors {
  AppColors._();

  static const Color moneyGreen = Color(0xFF00D57A);
  static const Color moneyGreenDark = Color(0xFF00A85F);
  static const Color moneyGreenTint = Color(0x2600D57A); // ~15% opacity
  static const Color background = Color(0xFF0A0E0D);
  static const Color surface = Color(0xFF141A18);
  static const Color surfaceRaised = Color(0xFF1B2321);
  static const Color textPrimary = CupertinoColors.white;
  static const Color textSecondary = Color(0xFF9AA6A2);
  static const Color textTertiary = Color(0xFF6B7570);
  static const Color statusPositive = moneyGreen;
  static const Color statusWarning = Color(0xFFFF9F0A);
  static const Color statusNegative = Color(0xFFFF453A);
  static const List<Color> heroGradient = [moneyGreen, Color(0xFF00B86B)];
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heroValue = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.textTertiary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}