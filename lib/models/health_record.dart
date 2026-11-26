import '../core/utils/medical_evaluator.dart';

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.familyId,
    required this.profileId,
    required this.recordedByUserId,
    required this.recordedByName,
    required this.recordedAt,
    required this.createdAt,
    required this.updatedAt,
    this.updatedByUserId,
    this.updatedByName,
    this.systolic,
    this.diastolic,
    this.temperatureC,
    this.heartRate,
    this.weightKg,
    this.heightCm,
    this.bloodSugar,
    this.sugarType,
    this.symptoms,
    this.notes,
  });

  final String id;
  final String familyId;
  final String profileId;
  final String recordedByUserId;
  final String recordedByName;
  final String? updatedByUserId;
  final String? updatedByName;
  final DateTime recordedAt;
  final int? systolic;
  final int? diastolic;
  final double? temperatureC;
  final int? heartRate;
  final double? weightKg;
  final double? heightCm;
  final double? bloodSugar;
  final String? sugarType; // fasting | random | post_meal
  final String? symptoms;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasBloodPressure => systolic != null && diastolic != null;
  double? get bmi => MedicalEvaluator.calculateBmi(weightKg, heightCm);

  String get sugarTypeLabel {
    switch (sugarType) {
      case 'fasting':
        return 'Puasa';
      case 'post_meal':
        return '2 Jam Setelah Makan';
      default:
        return 'Sewaktu';
    }
  }

  /// Ringkasan metrik singkat untuk kartu riwayat.
  List<String> get metricSummaries {
    final items = <String>[];
    if (hasBloodPressure) items.add('Tensi $systolic/$diastolic mmHg');
    if (bloodSugar != null) {
      items.add('Gula ${bloodSugar!.toStringAsFixed(0)} mg/dL ($sugarTypeLabel)');
    }
    if (temperatureC != null) {
      items.add('Suhu ${temperatureC!.toStringAsFixed(1)} °C');
    }
    if (heartRate != null) items.add('Nadi $heartRate bpm');
    if (weightKg != null) items.add('BB ${weightKg!.toStringAsFixed(1)} kg');
    if (heightCm != null) items.add('TB ${heightCm!.toStringAsFixed(0)} cm');
    return items;
  }

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      profileId: json['profile_id'] as String,
      recordedByUserId: json['recorded_by_user_id'] as String,
      recordedByName: (json['recorded_by_name'] as String?) ?? 'Pengguna',
      updatedByUserId: json['updated_by_user_id'] as String?,
      updatedByName: json['updated_by_name'] as String?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      systolic: json['systolic'] as int?,
      diastolic: json['diastolic'] as int?,
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      heartRate: json['heart_rate'] as int?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      bloodSugar: (json['blood_sugar'] as num?)?.toDouble(),
      sugarType: json['sugar_type'] as String?,
      symptoms: json['symptoms'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
