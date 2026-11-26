import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/accessibility_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/medical_evaluator.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/health_profile.dart';
import '../../../models/health_record.dart';
import '../../../models/health_schedule.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  final void Function(int tabIndex) onNavigateTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfileAsync = ref.watch(currentProfileProvider);
    final familyAsync = ref.watch(familyGroupProvider);
    final directoryAsync = ref.watch(familyDirectoryProvider);
    final recordsAsync = ref.watch(healthRecordsProvider);
    final schedulesAsync = ref.watch(healthSchedulesProvider);
    final selectedId = ref.watch(selectedProfileIdProvider);
    final largeText = ref.watch(largeTextModeProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('JagaBersama'),
            familyAsync.when(
              data: (family) => Text(
                family?.name ?? 'Kesehatan Keluarga',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(
                Icons.text_fields_rounded,
                size: 18,
                color: largeText ? Colors.white : AppColors.primaryBlue,
              ),
              label: Text(
                largeText ? 'Teks Besar: ON' : 'Teks Besar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: largeText ? Colors.white : AppColors.primaryBlue,
                ),
              ),
              backgroundColor:
                  largeText ? AppColors.primaryBlue : AppColors.primaryBlueSoft,
              side: BorderSide.none,
              onPressed: () {
                ref.read(largeTextModeProvider.notifier).toggle();
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentProfileProvider);
          ref.invalidate(familyGroupProvider);
          ref.invalidate(familyDirectoryProvider);
          ref.invalidate(healthRecordsProvider);
          ref.invalidate(healthSchedulesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Banner Sapaan Modern
            myProfileAsync.when(
              data: (me) => _GreetingHeroCard(
                userName: me?.fullName ?? 'Keluarga',
                roleLabel: me?.roleLabel ?? 'Anggota',
                onQuickRecord: () => context.push('/record/add'),
              ),
              loading: () => const SizedBox(height: 110),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 18),

            // Selector Anggota Keluarga
            directoryAsync.when(
              data: (members) {
                final viewable = members.where((m) => m.canView).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Ringkasan Anggota',
                      actionLabel: 'Lihat Grafik',
                      onAction: () => onNavigateTab(1),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Text('Semua'),
                              selected: selectedId == null,
                              onSelected: (_) => ref
                                  .read(selectedProfileIdProvider.notifier)
                                  .state = null,
                            ),
                          ),
                          ...viewable.map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(m.fullName),
                                selected: selectedId == m.id,
                                onSelected: (_) => ref
                                    .read(selectedProfileIdProvider.notifier)
                                    .state = m.id,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Kartu Ringkasan Pemeriksaan Terakhir
            recordsAsync.when(
              data: (records) {
                final members = directoryAsync.valueOrNull ?? const [];
                final filtered = selectedId == null
                    ? records
                    : records.where((r) => r.profileId == selectedId).toList();

                if (filtered.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.monitor_heart_outlined,
                            size: 42,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Belum Ada Catatan Kesehatan',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tekan tombol + di bawah untuk mulai mencatat tekanan darah, gula darah, suhu, atau berat badan.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return _LatestVitalsSection(
                  records: filtered,
                  members: members,
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Gagal memuat data kesehatan: $e'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Jadwal Terdekat
            SectionHeader(
              title: 'Jadwal Kontrol Terdekat',
              actionLabel: 'Semua Jadwal',
              onAction: () => onNavigateTab(2),
            ),
            const SizedBox(height: 10),
            schedulesAsync.when(
              data: (schedules) {
                final members = directoryAsync.valueOrNull ?? const [];
                final upcoming = schedules
                    .where(
                      (s) =>
                          s.status == 'scheduled' &&
                          (selectedId == null || s.profileId == selectedId),
                    )
                    .take(2)
                    .toList();

                if (upcoming.isEmpty) {
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.secondaryGreenSoft,
                        child: Icon(
                          Icons.event_available_rounded,
                          color: AppColors.secondaryGreen,
                        ),
                      ),
                      title: const Text('Belum ada jadwal mendatang'),
                      subtitle: const Text(
                        'Tambahkan jadwal kontrol dokter atau pengingat obat keluarga.',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppColors.primaryBlue,
                        onPressed: () => context.push('/schedule/add'),
                      ),
                    ),
                  );
                }

                return Column(
                  children: upcoming
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _UpcomingScheduleCard(
                            schedule: s,
                            memberName: _findName(members, s.profileId),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Akses Cepat 2x2
            const SectionHeader(title: 'Akses Cepat'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _QuickActionTile(
                  icon: Icons.add_chart_rounded,
                  title: 'Catat Pemeriksaan',
                  color: AppColors.secondaryGreen,
                  bgColor: AppColors.secondaryGreenSoft,
                  onTap: () => context.push('/record/add'),
                ),
                _QuickActionTile(
                  icon: Icons.show_chart_rounded,
                  title: 'Grafik & Riwayat',
                  color: AppColors.primaryBlue,
                  bgColor: AppColors.primaryBlueSoft,
                  onTap: () => onNavigateTab(1),
                ),
                _QuickActionTile(
                  icon: Icons.upload_file_rounded,
                  title: 'Unggah Dokumen',
                  color: AppColors.primaryBlue,
                  bgColor: AppColors.primaryBlueSoft,
                  onTap: () => context.push('/document/add'),
                ),
                _QuickActionTile(
                  icon: Icons.calendar_month_rounded,
                  title: 'Tambah Jadwal',
                  color: AppColors.secondaryGreen,
                  bgColor: AppColors.secondaryGreenSoft,
                  onTap: () => context.push('/schedule/add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _findName(List<HealthProfile> members, String id) {
    for (final m in members) {
      if (m.id == id) return m.fullName;
    }
    return 'Anggota';
  }
}

class _GreetingHeroCard extends StatelessWidget {
  const _GreetingHeroCard({
    required this.userName,
    required this.roleLabel,
    required this.onQuickRecord,
  });

  final String userName;
  final String roleLabel;
  final VoidCallback onQuickRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryBlueLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $userName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.favorite_rounded,
                color: Colors.white70,
                size: 38,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onQuickRecord,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.add_circle_rounded),
            label: const Text(
              'Catat Kondisi Hari Ini',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestVitalsSection extends StatelessWidget {
  const _LatestVitalsSection({
    required this.records,
    required this.members,
  });

  final List<HealthRecord> records;
  final List<HealthProfile> members;

  @override
  Widget build(BuildContext context) {
    final latest = records.first;
    final ownerName = HomeDashboardScreen._findName(members, latest.profileId);

    HealthRecord? latestBp;
    HealthRecord? latestSugar;
    HealthRecord? latestTemp;
    HealthRecord? latestWeight;

    for (final r in records) {
      latestBp ??= r.hasBloodPressure ? r : null;
      latestSugar ??= r.bloodSugar != null ? r : null;
      latestTemp ??= r.temperatureC != null ? r : null;
      latestWeight ??= r.weightKg != null ? r : null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Pemeriksaan Terbaru • $ownerName',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                InkWell(
                  onTap: () => context.push('/record/${latest.id}', extra: latest),
                  child: const Text(
                    'Detail',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Dicatat oleh ${latest.recordedByName} • ${AppDateFormatter.relativeOrDate(latest.recordedAt)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (latestBp != null)
                  _MetricTile(
                    icon: Icons.bloodtype_rounded,
                    label: 'Tekanan Darah',
                    value: '${latestBp.systolic}/${latestBp.diastolic} mmHg',
                    status: MedicalEvaluator.evaluateBloodPressure(
                      latestBp.systolic!,
                      latestBp.diastolic!,
                    ),
                  ),
                if (latestSugar != null)
                  _MetricTile(
                    icon: Icons.water_drop_rounded,
                    label: 'Gula (${latestSugar.sugarTypeLabel})',
                    value: '${latestSugar.bloodSugar!.toStringAsFixed(0)} mg/dL',
                    status: MedicalEvaluator.evaluateBloodSugar(
                      latestSugar.bloodSugar!,
                      latestSugar.sugarType,
                    ),
                  ),
                if (latestTemp != null)
                  _MetricTile(
                    icon: Icons.thermostat_rounded,
                    label: 'Suhu Tubuh',
                    value: '${latestTemp.temperatureC!.toStringAsFixed(1)} °C',
                    status: MedicalEvaluator.evaluateTemperature(
                      latestTemp.temperatureC!,
                    ),
                  ),
                if (latestWeight != null)
                  _MetricTile(
                    icon: Icons.monitor_weight_rounded,
                    label: latestWeight.bmi != null
                        ? 'Berat & IMT'
                        : 'Berat Badan',
                    value: '${latestWeight.weightKg!.toStringAsFixed(1)} kg',
                    status: latestWeight.bmi != null
                        ? MedicalEvaluator.evaluateBmi(latestWeight.bmi!)
                        : null,
                  ),
              ],
            ),
            if (latest.symptoms != null && latest.symptoms!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Keluhan: ${latest.symptoms}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.status,
  });

  final IconData icon;
  final String label;
  final String value;
  final MedicalStatus? status;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 82) / 2;
    return Container(
      width: width > 130 ? width : double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 6),
            StatusBadge(status: status!, compact: true),
          ],
        ],
      ),
    );
  }
}

class _UpcomingScheduleCard extends StatelessWidget {
  const _UpcomingScheduleCard({
    required this.schedule,
    required this.memberName,
  });

  final HealthSchedule schedule;
  final String memberName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryBlueSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.event_note_rounded,
            color: AppColors.primaryBlue,
          ),
        ),
        title: Text(
          schedule.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$memberName • ${AppDateFormatter.dateTime(schedule.scheduledAt)}'
            '${schedule.locationOrDoctor != null ? '\n${schedule.locationOrDoctor}' : ''}',
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
