import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/health_profile.dart';

class AddScheduleScreen extends ConsumerStatefulWidget {
  const AddScheduleScreen({super.key});

  @override
  ConsumerState<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends ConsumerState<AddScheduleScreen> {
  String? _selectedProfileId;
  String _scheduleType = 'checkup';
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  int _reminderMinutes = 60;
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (pickedTime == null) return;

    setState(() {
      _scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_selectedProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih anggota keluarga')),
      );
      return;
    }
    if (_titleController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi judul jadwal pemeriksaan')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final me = await ref.read(currentProfileProvider.future);
      final members = await ref.read(familyDirectoryProvider.future);
      if (me == null) throw Exception('Profil tidak ditemukan');

      final target = members.firstWhere(
        (m) => m.id == _selectedProfileId,
        orElse: () => me,
      );

      final inserted = await client
          .from('health_schedules')
          .insert({
            'family_id': me.familyId,
            'profile_id': _selectedProfileId,
            'created_by_user_id': client.auth.currentUser!.id,
            'created_by_name': me.fullName,
            'title': _titleController.text.trim(),
            'schedule_type': _scheduleType,
            'scheduled_at': _scheduledAt.toUtc().toIso8601String(),
            'location_or_doctor': _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            'reminder_minutes_before': _reminderMinutes,
          })
          .select('id')
          .single();

      await LocalNotificationService.instance.scheduleReminder(
        scheduleId: inserted['id'] as String,
        memberName: target.fullName,
        title: _titleController.text.trim(),
        scheduledAt: _scheduledAt,
        reminderMinutesBefore: _reminderMinutes,
        location: _locationController.text.trim(),
      );

      await logFamilyActivity(
        client,
        familyId: me.familyId,
        targetProfileId: _selectedProfileId,
        actorUserId: client.auth.currentUser!.id,
        actorName: me.fullName,
        actionType: 'create',
        entityType: 'schedule',
        entityId: inserted['id'] as String,
        summary:
            'Menambah jadwal "${_titleController.text.trim()}" untuk ${target.fullName}',
      );

      ref.invalidate(healthSchedulesProvider);
      ref.invalidate(activityLogsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal & pengingat berhasil disimpan!'),
          backgroundColor: AppColors.secondaryGreen,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan jadwal: $e'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = (ref.watch(familyDirectoryProvider).valueOrNull ??
            const <HealthProfile>[])
        .where((m) => m.canEdit)
        .toList();
    final me = ref.watch(currentProfileProvider).valueOrNull;

    if (_selectedProfileId == null && members.isNotEmpty) {
      _selectedProfileId = members
              .cast<HealthProfile?>()
              .firstWhere((m) => m?.id == me?.id, orElse: () => null)
              ?.id ??
          members.first.id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Jadwal Kesehatan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Untuk Siapa',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: members
                          .map(
                            (m) => ChoiceChip(
                              label: Text(m.fullName),
                              selected: _selectedProfileId == m.id,
                              onSelected: (_) =>
                                  setState(() => _selectedProfileId = m.id),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Jenis Jadwal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _typeChip('checkup', 'Kontrol Rutin'),
                        _typeChip('consultation', 'Konsultasi Dokter'),
                        _typeChip('lab', 'Cek Lab'),
                        _typeChip('medication', 'Minum Obat'),
                        _typeChip('other', 'Lainnya'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Jadwal',
                        hintText: 'Contoh: Kontrol Poli Penyakit Dalam',
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDateTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppDateFormatter.dateTime(_scheduledAt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Text(
                              'Pilih',
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Lokasi / Nama Dokter (Opsional)',
                        hintText: 'Contoh: RSUD / dr. Hendra Sp.PD',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Pengingat Alarm Lokal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _reminderChip(0, 'Tepat Waktu'),
                        _reminderChip(60, '1 Jam Sebelum'),
                        _reminderChip(1440, 'H-1 (1 Hari)'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        hintText: 'Contoh: Puasa sejak jam 22.00 malam',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.notifications_active_rounded),
              label: const Text('Simpan Jadwal & Pengingat'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _scheduleType == value,
      onSelected: (_) => setState(() => _scheduleType = value),
    );
  }

  Widget _reminderChip(int minutes, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _reminderMinutes == minutes,
      onSelected: (_) => setState(() => _reminderMinutes = minutes),
    );
  }
}
