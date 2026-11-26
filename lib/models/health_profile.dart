class HealthProfile {
  const HealthProfile({
    required this.id,
    required this.familyId,
    required this.fullName,
    required this.relationLabel,
    required this.role,
    required this.accessPermission,
    required this.createdAt,
    this.userId,
    this.claimCode,
    this.birthDate,
    this.gender,
    this.bloodType,
    this.allergies,
    this.chronicConditions,
    this.defaultHeightCm,
    this.canView = true,
    this.canEdit = true,
  });

  final String id;
  final String familyId;
  final String? userId;
  final String fullName;
  final String relationLabel;
  final String role; // owner | caretaker | member
  final String accessPermission; // private | view_only | view_and_edit
  final String? claimCode;
  final DateTime? birthDate;
  final String? gender;
  final String? bloodType;
  final String? allergies;
  final String? chronicConditions;
  final double? defaultHeightCm;
  final DateTime createdAt;
  final bool canView;
  final bool canEdit;

  bool get isDependent => userId == null;
  bool get isOwner => role == 'owner';
  bool get isCaretaker => role == 'caretaker';
  bool get isManager => role == 'owner' || role == 'caretaker';

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Admin Utama';
      case 'caretaker':
        return 'Pengelola';
      default:
        return isDependent ? 'Profil Dikelola' : 'Anggota';
    }
  }

  String get permissionLabel {
    switch (accessPermission) {
      case 'private':
        return 'Privat';
      case 'view_and_edit':
        return 'Lihat & Input';
      default:
        return 'Lihat Saja';
    }
  }

  int? get ageYears {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  factory HealthProfile.fromJson(Map<String, dynamic> json) {
    return HealthProfile(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String?,
      fullName: json['full_name'] as String,
      relationLabel: (json['relation_label'] as String?) ?? 'Anggota',
      role: (json['role'] as String?) ?? 'member',
      accessPermission:
          (json['access_permission'] as String?) ?? 'view_only',
      claimCode: json['claim_code'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      gender: json['gender'] as String?,
      bloodType: json['blood_type'] as String?,
      allergies: json['allergies'] as String?,
      chronicConditions: json['chronic_conditions'] as String?,
      defaultHeightCm: (json['default_height_cm'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      canView: (json['can_view'] as bool?) ?? true,
      canEdit: (json['can_edit'] as bool?) ?? true,
    );
  }
}
