import 'package:fl_chart/fl_chart.dart';
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

enum HealthMetricType { bloodPressure, bloodSugar, weight, temperature, heartRate }

enum ChartRange { daily, weekly, monthly }

class HealthMonitorScreen extends ConsumerStatefulWidget {
  const HealthMonitorScreen({super.key});

  @override
  ConsumerState<HealthMonitorScreen> createState() =>
      _HealthMonitorScreenState();
}

class _HealthMonitorScreenState extends ConsumerState<HealthMonitorScreen> {
  HealthMetricType _metric = HealthMetricType.bloodPressure;
  ChartRange _range = ChartRange.daily;

  @override
  Widget build(BuildContext context) {
    final directoryAsync = ref.watch(familyDirectoryProvider);
    final recordsAsync = ref.watch(healthRecordsProvider);
    final selectedId = ref.watch(selectedProfileIdProvider);

    final viewableMembers =
        (directoryAsync.valueOrNull ?? const <HealthProfile>[])
            .where((m) => m.canView)
            .toList();

    final effectiveProfileId = selectedId ??
        (viewableMembers.isNotEmpty ? viewableMembers.first.id : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemantauan & Grafik'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(healthRecordsProvider);
          ref.invalidate(familyDirectoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            if (viewableMembers.isNotEmpty) ...[
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: viewableMembers.map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(m.fullName),
                        selected: effectiveProfileId == m.id,
                        onSelected: (_) => ref
                            .read(selectedProfileIdProvider.notifier)
                            .state = m.id,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Pilih Jenis Pemeriksaan
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _metricChip(HealthMetricType.bloodPressure, 'Tekanan Darah'),
                  _metricChip(HealthMetricType.bloodSugar, 'Gula Darah'),
                  _metricChip(HealthMetricType.weight, 'Berat Badan'),
                  _metricChip(HealthMetricType.temperature, 'Suhu Tubuh'),
                  _metricChip(HealthMetricType.heartRate, 'Denyut Nadi'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Toggle Harian / Mingguan / Bulanan
            SegmentedButton<ChartRange>(
              segments: const [
                ButtonSegment(value: ChartRange.daily, label: Text('Harian')),
                ButtonSegment(value: ChartRange.weekly, label: Text('Mingguan')),
                ButtonSegment(value: ChartRange.monthly, label: Text('Bulanan')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
            const SizedBox(height: 16),

            recordsAsync.when(
              data: (allRecords) {
                final profileRecords = allRecords
                    .where((r) =>
                        effectiveProfileId == null ||
                        r.profileId == effectiveProfileId)
                    .toList();

                final now = DateTime.now();
                final cutoff = _range == ChartRange.daily
                    ? now.subtract(const Duration(days: 7))
                    : _range == ChartRange.weekly
                        ? now.subtract(const Duration(days: 28))
                        : now.subtract(const Duration(days: 180));

                final chartRecords = profileRecords
                    .where((r) =>
                        r.recordedAt.isAfter(cutoff) &&
                        _hasMetric(r, _metric))
                    .toList()
                  ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _metricTitle(_metric),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _rangeLabel(_range),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 18),
                            if (chartRecords.isEmpty)
                              const SizedBox(
                                height: 150,
                                child: Center(
                                  child: Text(
                                    'Belum ada data untuk rentang waktu ini.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 210,
                                child: _MetricLineChart(
                                  records: chartRecords,
                                  metric: _metric,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Riwayat Pemeriksaan'),
                    const SizedBox(height: 10),
                    if (profileRecords.isEmpty)
                      EmptyStateView(
                        icon: Icons.history_rounded,
                        title: 'Belum Ada Riwayat',
                        subtitle:
                            'Catatan pemeriksaan anggota ini akan tampil tersusun berdasarkan tanggal.',
                        actionLabel: 'Catat Sekarang',
                        onAction: () => context.push('/record/add'),
                      )
                    else
                      ...profileRecords.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecordHistoryCard(record: r),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Gagal memuat grafik: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(HealthMetricType type, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _metric == type,
        onSelected: (_) => setState(() => _metric = type),
      ),
    );
  }

  bool _hasMetric(HealthRecord r, HealthMetricType m) {
    switch (m) {
      case HealthMetricType.bloodPressure:
        return r.hasBloodPressure;
      case HealthMetricType.bloodSugar:
        return r.bloodSugar != null;
      case HealthMetricType.weight:
        return r.weightKg != null;
      case HealthMetricType.temperature:
        return r.temperatureC != null;
      case HealthMetricType.heartRate:
        return r.heartRate != null;
    }
  }

  String _metricTitle(HealthMetricType m) {
    switch (m) {
      case HealthMetricType.bloodPressure:
        return 'Grafik Tekanan Darah (mmHg)';
      case HealthMetricType.bloodSugar:
        return 'Grafik Gula Darah (mg/dL)';
      case HealthMetricType.weight:
        return 'Grafik Berat Badan (kg)';
      case HealthMetricType.temperature:
        return 'Grafik Suhu Tubuh (°C)';
      case HealthMetricType.heartRate:
        return 'Grafik Denyut Nadi (bpm)';
    }
  }

  String _rangeLabel(ChartRange r) {
    switch (r) {
      case ChartRange.daily:
        return 'Perkembangan 7 hari terakhir';
      case ChartRange.weekly:
        return 'Perkembangan 4 minggu terakhir';
      case ChartRange.monthly:
        return 'Perkembangan 6 bulan terakhir';
    }
  }
}

class _MetricLineChart extends StatelessWidget {
  const _MetricLineChart({
    required this.records,
    required this.metric,
  });

  final List<HealthRecord> records;
  final HealthMetricType metric;

  @override
  Widget build(BuildContext context) {
    final primarySpots = <FlSpot>[];
    final secondarySpots = <FlSpot>[];

    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      final x = i.toDouble();
      switch (metric) {
        case HealthMetricType.bloodPressure:
          primarySpots.add(FlSpot(x, r.systolic!.toDouble()));
          secondarySpots.add(FlSpot(x, r.diastolic!.toDouble()));
          break;
        case HealthMetricType.bloodSugar:
          primarySpots.add(FlSpot(x, r.bloodSugar!));
          break;
        case HealthMetricType.weight:
          primarySpots.add(FlSpot(x, r.weightKg!));
          break;
        case HealthMetricType.temperature:
          primarySpots.add(FlSpot(x, r.temperatureC!));
          break;
        case HealthMetricType.heartRate:
          primarySpots.add(FlSpot(x, r.heartRate!.toDouble()));
          break;
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: records.length > 5 ? (records.length / 4).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 || idx >= records.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    AppDateFormatter.shortDayMonth(records[idx].recordedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: primarySpots,
            isCurved: true,
            color: AppColors.primaryBlue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryBlue.withValues(alpha: 0.10),
            ),
          ),
          if (secondarySpots.isNotEmpty)
            LineChartBarData(
              spots: secondarySpots,
              isCurved: true,
              color: AppColors.secondaryGreen,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
        ],
      ),
    );
  }
}

class _RecordHistoryCard extends StatelessWidget {
  const _RecordHistoryCard({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    MedicalStatus? primaryStatus;
    if (record.hasBloodPressure) {
      primaryStatus = MedicalEvaluator.evaluateBloodPressure(
        record.systolic!,
        record.diastolic!,
      );
    } else if (record.bloodSugar != null) {
      primaryStatus = MedicalEvaluator.evaluateBloodSugar(
        record.bloodSugar!,
        record.sugarType,
      );
    } else if (record.temperatureC != null) {
      primaryStatus = MedicalEvaluator.evaluateTemperature(record.temperatureC!);
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/record/${record.id}', extra: record),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppDateFormatter.dateTime(record.recordedAt),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (primaryStatus != null)
                    StatusBadge(status: primaryStatus, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              if (record.metricSummaries.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: record.metricSummaries
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              if (record.symptoms != null && record.symptoms!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Keluhan: ${record.symptoms}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Diinput oleh ${record.recordedByName}'
                '${record.updatedByName != null ? ' • Diubah oleh ${record.updatedByName}' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
