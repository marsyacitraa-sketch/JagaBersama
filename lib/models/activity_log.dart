class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.familyId,
    required this.actorUserId,
    required this.actorName,
    required this.actionType,
    required this.entityType,
    required this.summary,
    required this.createdAt,
    this.targetProfileId,
    this.entityId,
  });

  final String id;
  final String familyId;
  final String? targetProfileId;
  final String actorUserId;
  final String actorName;
  final String actionType;
  final String entityType;
  final String? entityId;
  final String summary;
  final DateTime createdAt;

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      targetProfileId: json['target_profile_id'] as String?,
      actorUserId: json['actor_user_id'] as String,
      actorName: (json['actor_name'] as String?) ?? 'Pengguna',
      actionType: json['action_type'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String?,
      summary: json['summary'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
