import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/activity_log.dart';
import '../../models/family.dart';
import '../../models/health_document.dart';
import '../../models/health_profile.dart';
import '../../models/health_record.dart';
import '../../models/health_schedule.dart';
import '../config/app_env.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  if (!AppEnv.isConfigured) {
    return const Stream.empty();
  }
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  if (!AppEnv.isConfigured) return null;
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

/// Profil milik pengguna yang sedang login (null jika belum masuk keluarga).
final currentProfileProvider = FutureProvider<HealthProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('health_profiles')
      .select()
      .eq('user_id', user.id)
      .maybeSingle();

  if (data == null) return null;
  return HealthProfile.fromJson(data);
});

/// Grup keluarga pengguna saat ini.
final familyGroupProvider = FutureProvider<FamilyGroup?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('families')
      .select()
      .eq('id', profile.familyId)
      .maybeSingle();

  if (data == null) return null;
  return FamilyGroup.fromJson(data);
});

/// Seluruh direktori anggota keluarga (menghormati privasi profil privat via RPC).
final familyDirectoryProvider =
    FutureProvider<List<HealthProfile>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return const [];

  final client = ref.watch(supabaseClientProvider);
  final rows = await client.rpc('get_family_directory') as List<dynamic>;
  return rows
      .map((e) => HealthProfile.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Filter anggota terpilih di Dashboard & Grafik (null = semua anggota yang bisa dilihat).
final selectedProfileIdProvider = StateProvider<String?>((ref) => null);

/// Seluruh catatan kesehatan yang boleh dilihat oleh pengguna saat ini.
final healthRecordsProvider =
    FutureProvider<List<HealthRecord>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return const [];

  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('health_records')
      .select()
      .order('recorded_at', ascending: false)
      .limit(300);

  return (rows as List<dynamic>)
      .map((e) => HealthRecord.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Seluruh dokumen kesehatan yang boleh dilihat oleh pengguna saat ini.
final healthDocumentsProvider =
    FutureProvider<List<HealthDocument>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return const [];

  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('health_documents')
      .select()
      .order('document_date', ascending: false)
      .limit(200);

  return (rows as List<dynamic>)
      .map((e) => HealthDocument.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Seluruh jadwal pemeriksaan/kontrol yang boleh dilihat oleh pengguna saat ini.
final healthSchedulesProvider =
    FutureProvider<List<HealthSchedule>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return const [];

  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('health_schedules')
      .select()
      .order('scheduled_at', ascending: true)
      .limit(200);

  return (rows as List<dynamic>)
      .map((e) => HealthSchedule.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Jejak aktivitas keluarga (terlihat untuk pemilik data, owner, dan caretaker).
final activityLogsProvider = FutureProvider<List<ActivityLog>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return const [];

  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('activity_logs')
      .select()
      .order('created_at', ascending: false)
      .limit(100);

  return (rows as List<dynamic>)
      .map((e) => ActivityLog.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

/// Helper mencatat audit log ke Supabase tanpa mengganggu alur utama jika gagal.
Future<void> logFamilyActivity(
  SupabaseClient client, {
  required String familyId,
  required String actorUserId,
  required String actorName,
  required String actionType,
  required String entityType,
  required String summary,
  String? targetProfileId,
  String? entityId,
}) async {
  try {
    await client.from('activity_logs').insert({
      'family_id': familyId,
      'target_profile_id': targetProfileId,
      'actor_user_id': actorUserId,
      'actor_name': actorName,
      'action_type': actionType,
      'entity_type': entityType,
      'entity_id': entityId,
      'summary': summary,
    });
  } catch (_) {
    // Abaikan kegagalan sekunder logging agar transaksi utama tidak terganggu
  }
}
