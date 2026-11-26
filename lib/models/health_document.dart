class HealthDocument {
  const HealthDocument({
    required this.id,
    required this.familyId,
    required this.profileId,
    required this.uploadedByUserId,
    required this.uploadedByName,
    required this.title,
    required this.category,
    required this.storagePath,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.documentDate,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String familyId;
  final String profileId;
  final String uploadedByUserId;
  final String uploadedByName;
  final String title;
  final String category; // lab_result | prescription | referral | other
  final String storagePath;
  final String mimeType;
  final int fileSizeBytes;
  final DateTime documentDate;
  final String? notes;
  final DateTime createdAt;

  bool get isPdf => mimeType == 'application/pdf';

  String get categoryLabel {
    switch (category) {
      case 'lab_result':
        return 'Hasil Lab';
      case 'prescription':
        return 'Resep Dokter';
      case 'referral':
        return 'Surat Rujukan';
      default:
        return 'Lainnya';
    }
  }

  String get readableSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  factory HealthDocument.fromJson(Map<String, dynamic> json) {
    return HealthDocument(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      profileId: json['profile_id'] as String,
      uploadedByUserId: json['uploaded_by_user_id'] as String,
      uploadedByName: (json['uploaded_by_name'] as String?) ?? 'Pengguna',
      title: json['title'] as String,
      category: (json['category'] as String?) ?? 'other',
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      fileSizeBytes: (json['file_size_bytes'] as num).toInt(),
      documentDate: DateTime.parse(json['document_date'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
