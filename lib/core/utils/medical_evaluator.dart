import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum HealthLevel { normal, warning, high, low, info }

class MedicalStatus {
  const MedicalStatus({
    required this.level,
    required this.label,
    required this.detail,
  });

  final HealthLevel level;
  final String label;
  final String detail;

  Color get foregroundColor {
    switch (level) {
      case HealthLevel.normal:
        return AppColors.statusNormal;
      case HealthLevel.warning:
        return AppColors.statusWarning;
      case HealthLevel.high:
        return AppColors.statusHigh;
      case HealthLevel.low:
        return AppColors.statusWarning;
      case HealthLevel.info:
        return AppColors.statusInfo;
    }
  }

  Color get backgroundColor {
    switch (level) {
      case HealthLevel.normal:
        return AppColors.statusNormalBg;
      case HealthLevel.warning:
        return AppColors.statusWarningBg;
      case HealthLevel.high:
        return AppColors.statusHighBg;
      case HealthLevel.low:
        return AppColors.statusWarningBg;
      case HealthLevel.info:
        return AppColors.statusInfoBg;
    }
  }
}

/// Kalkulator indikator status kesehatan otomatis berdasarkan ambang batas klinis umum.
class MedicalEvaluator {
  MedicalEvaluator._();

  static MedicalStatus evaluateBloodPressure(int systolic, int diastolic) {
    if (systolic >= 140 || diastolic >= 90) {
      return const MedicalStatus(
        level: HealthLevel.high,
        label: 'Tinggi',
        detail: 'Tekanan darah di atas batas normal (≥ 140/90 mmHg)',
      );
    }
    if ((systolic >= 120 && systolic <= 139) ||
        (diastolic >= 80 && diastolic <= 89)) {
      return const MedicalStatus(
        level: HealthLevel.warning,
        label: 'Waspada',
        detail: 'Pra-hipertensi, disarankan pantau berkala',
      );
    }
    if (systolic < 90 || diastolic < 60) {
      return const MedicalStatus(
        level: HealthLevel.low,
        label: 'Rendah',
        detail: 'Tekanan darah cenderung rendah (< 90/60 mmHg)',
      );
    }
    return const MedicalStatus(
      level: HealthLevel.normal,
      label: 'Normal',
      detail: 'Tekanan darah dalam rentang sehat',
    );
  }

  static MedicalStatus evaluateBloodSugar(double value, String? sugarType) {
    final type = sugarType ?? 'random';
    if (type == 'fasting') {
      if (value >= 126) {
        return const MedicalStatus(
          level: HealthLevel.high,
          label: 'Tinggi',
          detail: 'Gula darah puasa ≥ 126 mg/dL',
        );
      }
      if (value >= 100) {
        return const MedicalStatus(
          level: HealthLevel.warning,
          label: 'Waspada',
          detail: 'Gula darah puasa pra-diabetes (100–125 mg/dL)',
        );
      }
      if (value < 70) {
        return const MedicalStatus(
          level: HealthLevel.low,
          label: 'Rendah',
          detail: 'Gula darah puasa rendah (< 70 mg/dL)',
        );
      }
      return const MedicalStatus(
        level: HealthLevel.normal,
        label: 'Normal',
        detail: 'Gula darah puasa normal (70–99 mg/dL)',
      );
    }

    // Sewaktu atau 2 jam setelah makan
    final highThreshold = type == 'post_meal' ? 200.0 : 200.0;
    final warningThreshold = type == 'post_meal' ? 140.0 : 140.0;
    if (value >= highThreshold) {
      return const MedicalStatus(
        level: HealthLevel.high,
        label: 'Tinggi',
        detail: 'Gula darah ≥ 200 mg/dL',
      );
    }
    if (value >= warningThreshold) {
      return const MedicalStatus(
        level: HealthLevel.warning,
        label: 'Waspada',
        detail: 'Gula darah perlu dipantau (140–199 mg/dL)',
      );
    }
    if (value < 70) {
      return const MedicalStatus(
        level: HealthLevel.low,
        label: 'Rendah',
        detail: 'Gula darah rendah (< 70 mg/dL)',
      );
    }
    return const MedicalStatus(
      level: HealthLevel.normal,
      label: 'Normal',
      detail: 'Gula darah dalam batas normal',
    );
  }

  static MedicalStatus evaluateTemperature(double tempC) {
    if (tempC >= 38.0) {
      return const MedicalStatus(
        level: HealthLevel.high,
        label: 'Demam',
        detail: 'Suhu tubuh ≥ 38.0 °C',
      );
    }
    if (tempC >= 37.5) {
      return const MedicalStatus(
        level: HealthLevel.warning,
        label: 'Hangat',
        detail: 'Suhu sedikit meningkat (37.5–37.9 °C)',
      );
    }
    if (tempC < 35.5) {
      return const MedicalStatus(
        level: HealthLevel.low,
        label: 'Rendah',
        detail: 'Suhu tubuh di bawah 35.5 °C',
      );
    }
    return const MedicalStatus(
      level: HealthLevel.normal,
      label: 'Normal',
      detail: 'Suhu tubuh normal (35.5–37.4 °C)',
    );
  }

  static MedicalStatus evaluateHeartRate(int bpm) {
    if (bpm > 100) {
      return const MedicalStatus(
        level: HealthLevel.high,
        label: 'Tinggi',
        detail: 'Denyut nadi cepat (> 100 bpm)',
      );
    }
    if (bpm < 60) {
      return const MedicalStatus(
        level: HealthLevel.low,
        label: 'Rendah',
        detail: 'Denyut nadi lambat (< 60 bpm)',
      );
    }
    return const MedicalStatus(
      level: HealthLevel.normal,
      label: 'Normal',
      detail: 'Denyut nadi istirahat normal (60–100 bpm)',
    );
  }

  static double? calculateBmi(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || heightCm <= 0) return null;
    final hMeter = heightCm / 100.0;
    return weightKg / (hMeter * hMeter);
  }

  static MedicalStatus evaluateBmi(double bmi) {
    if (bmi >= 27.0) {
      return MedicalStatus(
        level: HealthLevel.high,
        label: 'Obesitas',
        detail: 'IMT ${bmi.toStringAsFixed(1)} (≥ 27.0)',
      );
    }
    if (bmi >= 25.0) {
      return MedicalStatus(
        level: HealthLevel.warning,
        label: 'Berlebih',
        detail: 'IMT ${bmi.toStringAsFixed(1)} (25.0–26.9)',
      );
    }
    if (bmi < 18.5) {
      return MedicalStatus(
        level: HealthLevel.low,
        label: 'Kurus',
        detail: 'IMT ${bmi.toStringAsFixed(1)} (< 18.5)',
      );
    }
    return MedicalStatus(
      level: HealthLevel.normal,
      label: 'Ideal',
      detail: 'IMT ${bmi.toStringAsFixed(1)} (18.5–24.9)',
    );
  }
}
