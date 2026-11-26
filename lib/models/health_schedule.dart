class HealthSchedule {
  const HealthSchedule({
    required this.id,
    required this.familyId,
    required this.profileId,
    required this.createdByUserId,
    required this.createdByName,
    required this.title,
    required this.scheduleType,
    required this.scheduledAt,
    required this.status,
    required this.reminderMinutesBefore,
    required this.createdAt,
    required this.updatedAt,
    this.locationOrDoctor,
    this.notes,
  });

  final String id;
  final String familyId;
  final String profileId;
  final String createdByUserId;
  final String createdByName;
  final String title;
  final String scheduleType; // checkup | consultation | lab | medication | other
  final DateTime scheduledAt;
  final String? locationOrDoctor;
  final String? notes;
  final String status; // scheduled | completed | cancelled
  final int reminderMinutesBefore;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get typeLabel {
    switch (scheduleType) {
      case 'checkup':
        return 'Kontrol Rutin';
      case 'consultation':
        return 'Konsultasi Dokter';
      case 'lab':
        return 'Pemeriksaan Lab';
      case 'medication':
        return 'Jadwal Obat';
      default:
        return 'Lainnya';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Terjadwal';
    }
  }

  factory HealthSchedule.fromJson(Map<String, dynamic> json) {
    return HealthSchedule(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      profileId: json['profile_id'] as String,
      createdByUserId: json['created_by_user_id'] as String,
      createdByName: (json['created_by_name'] as String?) ?? 'Pengguna',
      title: json['title'] as String,
      scheduleType: (json['schedule_type'] as String?) ?? 'checkup',
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      locationOrDoctor: json['location_or_doctor'] as String?,
      notes: json['notes'] as String?,
      status: (json['status'] as String?) ?? 'scheduled',
      reminderMinutesBefore:
          (json['reminder_minutes_before'] as num?)?.toInt() ?? 60,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
