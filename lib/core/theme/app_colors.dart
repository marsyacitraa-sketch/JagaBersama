import 'package:flutter/material.dart';

/// Palet warna resmi JagaBersama:
/// Biru utama, putih bersih, dan hijau sebagai warna pendukung kesehatan.
class AppColors {
  AppColors._();

  // Brand Primary (Biru Medis Modern)
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryBlueLight = Color(0xFF1E88E5);
  static const Color primaryBlueSoft = Color(0xFFE8F1FC);

  // Supporting Secondary (Hijau Kesehatan)
  static const Color secondaryGreen = Color(0xFF2E7D32);
  static const Color secondaryGreenLight = Color(0xFF43A047);
  static const Color secondaryGreenSoft = Color(0xFFE8F5E9);

  // Neutral Surfaces (Putih & Abu Lembut)
  static const Color background = Color(0xFFF5F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF3F9);
  static const Color border = Color(0xFFD9E2EC);
  static const Color textPrimary = Color(0xFF102A43);
  static const Color textSecondary = Color(0xFF486581);
  static const Color textMuted = Color(0xFF829AB1);

  // Semantic Health Status
  static const Color statusNormal = Color(0xFF2E7D32);
  static const Color statusNormalBg = Color(0xFFE8F5E9);

  static const Color statusWarning = Color(0xFFD97706);
  static const Color statusWarningBg = Color(0xFFFEF3C7);

  static const Color statusHigh = Color(0xFFC62828);
  static const Color statusHighBg = Color(0xFFFFEBEE);

  static const Color statusInfo = Color(0xFF1565C0);
  static const Color statusInfoBg = Color(0xFFE3F2FD);
}
