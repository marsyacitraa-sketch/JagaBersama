import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/medical_evaluator.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/health_profile.dart';
import '../../../models/health_record.dart';

class HealthRecordDetailScreen extends ConsumerWidget {
  const HealthRecordDetailScreen({
    super.key,
    required this.record,
  });

  final HealthRecord record;

  Future<void> _deleteRecord(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: const Text(
          'Catatan pemeriksaan ini akan dihapus permanen dari riwayat keluarga.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusHigh),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);
      final me = await ref.read(currentProfileProvider.future);
      await client.from('health_records').delete().eq('id', record.id);

      if (me != null) {
        await logFamilyActivity(
          client,
          familyId: me.familyId,
          targetProfileId: record.profileId,
          actorUserId: client.auth.currentUser!.id,
          actorName: me.fullName,
          actionType: 'delete',
          entityType: 'record',
          entityId: record.id,
          summary: 'Menghapus catatan pemeriksaan kesehatan',
        );
      }

      ref.invalidate(healthRecordsProvider);
      ref.invalidate(activityLogsProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus: $e'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directory = ref.watch(familyDirectoryProvider).valueOrNull ?? const [];
    final owner = directory.cast<HealthProfile?>().firstWhere(
          (m) => m?.id == record.profileId,
          orElse: () => null,
        );
    final canEdit = owner?.canEdit ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pemeriksaan'),
        actions: [
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/record/edit', extra: record),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.statusHigh),
              onPressed: () => _deleteRecord(context, ref),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    owner?.fullName ?? 'Anggota Keluarga',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppDateFormatter.fullDate(record.recordedAt)} • ${AppDateFormatter.timeOnly(record.recordedAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (record.hasBloodPressure)
            _DetailVitalCard(
              title: 'Tekanan Darah',
              value: '${record.systolic}/${record.diastolic} mmHg',
              status: MedicalEvaluator.evaluateBloodPressure(
                record.systolic!,
                record.diastolic!,
              ),
            ),
          if (record.bloodSugar != null)
            _DetailVitalCard(
              title: 'Gula Darah (${record.sugarTypeLabel})',
              value: '${record.bloodSugar!.toStringAsFixed(0)} mg/dL',
              status: MedicalEvaluator.evaluateBloodSugar(
                record.bloodSugar!,
                record.sugarType,
              ),
            ),
          if (record.temperatureC != null)
            _DetailVitalCard(
              title: 'Suhu Tubuh',
              value: '${record.temperatureC!.toStringAsFixed(1)} °C',
              status: MedicalEvaluator.evaluateTemperature(record.temperatureC!),
            ),
          if (record.heartRate != null)
            _DetailVitalCard(
              title: 'Denyut Nadi',
              value: '${record.heartRate} bpm',
              status: MedicalEvaluator.evaluateHeartRate(record.heartRate!),
            ),
          if (record.weightKg != null || record.heightCm != null)
            _DetailVitalCard(
              title: 'Berat & Tinggi Badan',
              value:
                  '${record.weightKg?.toStringAsFixed(1) ?? '-'} kg / ${record.heightCm?.toStringAsFixed(0) ?? '-'} cm',
              status: record.bmi != null
                  ? MedicalEvaluator.evaluateBmi(record.bmi!)
                  : null,
            ),
          if (record.symptoms != null && record.symptoms!.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: const Text('Keluhan Kesehatan'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(record.symptoms!),
                ),
              ),
            ),
          if (record.notes != null && record.notes!.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: const Text('Catatan Tambahan'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(record.notes!),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jejak Pencatatan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('Diinput oleh: ${record.recordedByName}'),
                  Text(
                    'Waktu input: ${AppDateFormatter.dateTime(record.createdAt)}',
                  ),
                  if (record.updatedByName != null) ...[
                    const SizedBox(height: 6),
                    Text('Diperbarui oleh: ${record.updatedByName}'),
                    Text(
                      'Waktu ubah: ${AppDateFormatter.dateTime(record.updatedAt)}',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailVitalCard extends StatelessWidget {
  const _DetailVitalCard({
    required this.title,
    required this.value,
    this.status,
  });

  final String title;
  final String value;
  final MedicalStatus? status;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      status!.detail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (status != null) StatusBadge(status: status!),
          ],
        ),
      ),
    );
  }
}
