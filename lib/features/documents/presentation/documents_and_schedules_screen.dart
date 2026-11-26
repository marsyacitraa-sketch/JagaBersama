import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/health_document.dart';
import '../../../models/health_profile.dart';
import '../../../models/health_schedule.dart';

class DocumentsAndSchedulesScreen extends ConsumerStatefulWidget {
  const DocumentsAndSchedulesScreen({super.key});

  @override
  ConsumerState<DocumentsAndSchedulesScreen> createState() =>
      _DocumentsAndSchedulesScreenState();
}

class _DocumentsAndSchedulesScreenState
    extends ConsumerState<DocumentsAndSchedulesScreen> {
  int _segmentIndex = 0; // 0 = Jadwal, 1 = Dokumen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumen & Jadwal'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () {
                if (_segmentIndex == 0) {
                  context.push('/schedule/add');
                } else {
                  context.push('/document/add');
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_segmentIndex == 0 ? 'Jadwal' : 'Dokumen'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.calendar_month_rounded),
                    label: Text('Jadwal Kontrol'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.folder_copy_rounded),
                    label: Text('Dokumen Kesehatan'),
                  ),
                ],
                selected: {_segmentIndex},
                onSelectionChanged: (s) =>
                    setState(() => _segmentIndex = s.first),
              ),
            ),
          ),
          Expanded(
            child: _segmentIndex == 0
                ? const _SchedulesTabBody()
                : const _DocumentsTabBody(),
          ),
        ],
      ),
    );
  }
}

class _SchedulesTabBody extends ConsumerStatefulWidget {
  const _SchedulesTabBody();

  @override
  ConsumerState<_SchedulesTabBody> createState() => _SchedulesTabBodyState();
}

class _SchedulesTabBodyState extends ConsumerState<_SchedulesTabBody> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Future<void> _updateStatus(
    HealthSchedule schedule,
    String newStatus,
  ) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final me = await ref.read(currentProfileProvider.future);

      await client
          .from('health_schedules')
          .update({'status': newStatus})
          .eq('id', schedule.id);

      if (newStatus != 'scheduled') {
        await LocalNotificationService.instance.cancelReminder(schedule.id);
      }

      if (me != null) {
        await logFamilyActivity(
          client,
          familyId: me.familyId,
          targetProfileId: schedule.profileId,
          actorUserId: client.auth.currentUser!.id,
          actorName: me.fullName,
          actionType: 'update',
          entityType: 'schedule',
          entityId: schedule.id,
          summary:
              'Mengubah status jadwal "${schedule.title}" menjadi ${newStatus == 'completed' ? 'Selesai' : 'Dibatalkan'}',
        );
      }

      ref.invalidate(healthSchedulesProvider);
      ref.invalidate(activityLogsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui jadwal: $e'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    }
  }

  Future<void> _deleteSchedule(HealthSchedule schedule) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final me = await ref.read(currentProfileProvider.future);
      await client.from('health_schedules').delete().eq('id', schedule.id);
      await LocalNotificationService.instance.cancelReminder(schedule.id);

      if (me != null) {
        await logFamilyActivity(
          client,
          familyId: me.familyId,
          targetProfileId: schedule.profileId,
          actorUserId: client.auth.currentUser!.id,
          actorName: me.fullName,
          actionType: 'delete',
          entityType: 'schedule',
          entityId: schedule.id,
          summary: 'Menghapus jadwal "${schedule.title}"',
        );
      }
      ref.invalidate(healthSchedulesProvider);
      ref.invalidate(activityLogsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(healthSchedulesProvider);
    final members = ref.watch(familyDirectoryProvider).valueOrNull ?? const [];

    return schedulesAsync.when(
      data: (schedules) {
        final filtered = _selectedDay == null
            ? schedules
            : schedules
                .where(
                  (s) => isSameDay(s.scheduledAt.toLocal(), _selectedDay),
                )
                .toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(healthSchedulesProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TableCalendar<HealthSchedule>(
                    locale: 'id_ID',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Bulan',
                      CalendarFormat.week: 'Minggu',
                    },
                    eventLoader: (day) => schedules
                        .where(
                          (s) => isSameDay(s.scheduledAt.toLocal(), day),
                        )
                        .toList(),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        if (isSameDay(_selectedDay, selected)) {
                          _selectedDay = null;
                        } else {
                          _selectedDay = selected;
                        }
                        _focusedDay = focused;
                      });
                    },
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primaryBlueSoft,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w700,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: AppColors.secondaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDay == null
                        ? 'Semua Jadwal (${filtered.length})'
                        : 'Jadwal ${AppDateFormatter.dateOnly(_selectedDay!)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_selectedDay != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedDay = null),
                      child: const Text('Tampilkan Semua'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                EmptyStateView(
                  icon: Icons.event_busy_rounded,
                  title: 'Belum Ada Jadwal',
                  subtitle:
                      'Tambahkan jadwal kontrol dokter, lab, atau pengingat obat keluarga.',
                  actionLabel: 'Tambah Jadwal',
                  onAction: () => context.push('/schedule/add'),
                )
              else
                ...filtered.map((s) {
                  final owner = members.cast<HealthProfile?>().firstWhere(
                        (m) => m?.id == s.profileId,
                        orElse: () => null,
                      );
                  final canEdit = owner?.canEdit ?? false;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _ScheduleStatusChip(status: s.status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${owner?.fullName ?? 'Anggota'} • ${s.typeLabel}',
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(AppDateFormatter.dateTime(s.scheduledAt)),
                          if (s.locationOrDoctor != null &&
                              s.locationOrDoctor!.isNotEmpty)
                            Text('Lokasi/Dokter: ${s.locationOrDoctor}'),
                          if (s.notes != null && s.notes!.isNotEmpty)
                            Text('Catatan: ${s.notes}'),
                          if (canEdit) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (s.status == 'scheduled') ...[
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 38),
                                    ),
                                    onPressed: () =>
                                        _updateStatus(s, 'completed'),
                                    icon: const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Selesai'),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                TextButton(
                                  onPressed: () => _deleteSchedule(s),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.statusHigh,
                                  ),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat jadwal: $e')),
    );
  }
}

class _ScheduleStatusChip extends StatelessWidget {
  const _ScheduleStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'completed'
        ? AppColors.statusNormal
        : status == 'cancelled'
            ? AppColors.statusHigh
            : AppColors.primaryBlue;
    final bg = status == 'completed'
        ? AppColors.statusNormalBg
        : status == 'cancelled'
            ? AppColors.statusHighBg
            : AppColors.primaryBlueSoft;
    final label = status == 'completed'
        ? 'Selesai'
        : status == 'cancelled'
            ? 'Batal'
            : 'Terjadwal';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DocumentsTabBody extends ConsumerStatefulWidget {
  const _DocumentsTabBody();

  @override
  ConsumerState<_DocumentsTabBody> createState() => _DocumentsTabBodyState();
}

class _DocumentsTabBodyState extends ConsumerState<_DocumentsTabBody> {
  String _categoryFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(healthDocumentsProvider);
    final members = ref.watch(familyDirectoryProvider).valueOrNull ?? const [];

    return docsAsync.when(
      data: (docs) {
        final filtered = _categoryFilter == 'all'
            ? docs
            : docs.where((d) => d.category == _categoryFilter).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(healthDocumentsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _catChip('all', 'Semua'),
                    _catChip('lab_result', 'Hasil Lab'),
                    _catChip('prescription', 'Resep Dokter'),
                    _catChip('referral', 'Surat Rujukan'),
                    _catChip('other', 'Lainnya'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                EmptyStateView(
                  icon: Icons.description_outlined,
                  title: 'Belum Ada Dokumen',
                  subtitle:
                      'Simpan foto resep dokter atau file PDF hasil laboratorium keluarga dengan aman.',
                  actionLabel: 'Unggah Dokumen',
                  onAction: () => context.push('/document/add'),
                )
              else
                ...filtered.map((doc) {
                  final owner = members.cast<HealthProfile?>().firstWhere(
                        (m) => m?.id == doc.profileId,
                        orElse: () => null,
                      );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: doc.isPdf
                              ? AppColors.statusHighBg
                              : AppColors.primaryBlueSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          doc.isPdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.image_rounded,
                          color: doc.isPdf
                              ? AppColors.statusHigh
                              : AppColors.primaryBlue,
                        ),
                      ),
                      title: Text(
                        doc.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${owner?.fullName ?? 'Anggota'} • ${doc.categoryLabel}\n'
                          '${AppDateFormatter.dateOnly(doc.documentDate)} • ${doc.readableSize}',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/document/${doc.id}', extra: doc),
                    ),
                  );
                }),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat dokumen: $e')),
    );
  }

  Widget _catChip(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _categoryFilter == key,
        onSelected: (_) => setState(() => _categoryFilter = key),
      ),
    );
  }
}
