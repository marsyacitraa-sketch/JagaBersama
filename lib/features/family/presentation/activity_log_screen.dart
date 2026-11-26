import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_widgets.dart';

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  IconData _iconForEntity(String entityType) {
    switch (entityType) {
      case 'record':
        return Icons.monitor_heart_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'schedule':
        return Icons.event_note_rounded;
      case 'profile':
        return Icons.manage_accounts_rounded;
      default:
        return Icons.family_restroom_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activityLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Aktivitas Keluarga')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(activityLogsProvider),
        child: logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return const EmptyStateView(
                icon: Icons.history_toggle_off_rounded,
                title: 'Belum Ada Aktivitas',
                subtitle:
                    'Setiap pencatatan, perubahan data, dokumen, atau jadwal akan tercatat di sini.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = logs[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryBlueSoft,
                      child: Icon(
                        _iconForEntity(log.entityType),
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      log.summary,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${log.actorName} • ${AppDateFormatter.relativeOrDate(log.createdAt)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat log: $e')),
        ),
      ),
    );
  }
}
