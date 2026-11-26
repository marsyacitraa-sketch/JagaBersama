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

class AddHealthRecordScreen extends ConsumerStatefulWidget {
  const AddHealthRecordScreen({
    super.key,
    this.existingRecord,
  });

  final HealthRecord? existingRecord;

  @override
  ConsumerState<AddHealthRecordScreen> createState() =>
      _AddHealthRecordScreenState();
}

class _AddHealthRecordScreenState extends ConsumerState<AddHealthRecordScreen> {
  String? _selectedProfileId;
  DateTime _recordedAt = DateTime.now();

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _sugarController = TextEditingController();
  String _sugarType = 'random';
  final _tempController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRecord;
    if (existing != null) {
      _selectedProfileId = existing.profileId;
      _recordedAt = existing.recordedAt.toLocal();
      if (existing.systolic != null) {
        _systolicController.text = existing.systolic.toString();
      }
      if (existing.diastolic != null) {
        _diastolicController.text = existing.diastolic.toString();
      }
      if (existing.bloodSugar != null) {
        _sugarController.text = existing.bloodSugar!.toStringAsFixed(0);
      }
      _sugarType = existing.sugarType ?? 'random';
      if (existing.temperatureC != null) {
        _tempController.text = existing.temperatureC!.toStringAsFixed(1);
      }
      if (existing.heartRate != null) {
        _heartRateController.text = existing.heartRate.toString();
      }
      if (existing.weightKg != null) {
        _weightController.text = existing.weightKg!.toStringAsFixed(1);
      }
      if (existing.heightCm != null) {
        _heightController.text = existing.heightCm!.toStringAsFixed(0);
      }
      _symptomsController.text = existing.symptoms ?? '';
      _notesController.text = existing.notes ?? '';
    }
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _sugarController.dispose();
    _tempController.dispose();
    _heartRateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _symptomsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefillHeightIfEmpty(HealthProfile profile) {
    if (_heightController.text.isEmpty && profile.defaultHeightCm != null) {
      _heightController.text = profile.defaultHeightCm!.toStringAsFixed(0);
    }
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (pickedTime == null) return;

    setState(() {
      _recordedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    final profileId = _selectedProfileId;
    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih anggota keluarga terlebih dahulu')),
      );
      return;
    }

    final sys = int.tryParse(_systolicController.text.trim());
    final dia = int.tryParse(_diastolicController.text.trim());
    final sugar = double.tryParse(_sugarController.text.trim().replaceAll(',', '.'));
    final temp = double.tryParse(_tempController.text.trim().replaceAll(',', '.'));
    final hr = int.tryParse(_heartRateController.text.trim());
    final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    final height = double.tryParse(_heightController.text.trim().replaceAll(',', '.'));
    final symptoms = _symptomsController.text.trim();
    final notes = _notesController.text.trim();

    if ((sys != null && dia == null) || (sys == null && dia != null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi kedua angka tekanan darah (Sistolik dan Diastolik)'),
        ),
      );
      return;
    }

    final hasAny = sys != null ||
        sugar != null ||
        temp != null ||
        hr != null ||
        weight != null ||
        height != null ||
        symptoms.isNotEmpty ||
        notes.isNotEmpty;

    if (!hasAny) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi minimal satu hasil pemeriksaan atau keluhan'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final me = await ref.read(currentProfileProvider.future);
      final directory = await ref.read(familyDirectoryProvider.future);
      if (me == null) throw Exception('Profil pengguna tidak ditemukan');

      final targetMember = directory.firstWhere(
        (m) => m.id == profileId,
        orElse: () => me,
      );

      final payload = {
        'family_id': me.familyId,
        'profile_id': profileId,
        'recorded_at': _recordedAt.toUtc().toIso8601String(),
        'systolic': sys,
        'diastolic': dia,
        'temperature_c': temp,
        'heart_rate': hr,
        'weight_kg': weight,
        'height_cm': height,
        'blood_sugar': sugar,
        'sugar_type': sugar != null ? _sugarType : null,
        'symptoms': symptoms.isEmpty ? null : symptoms,
        'notes': notes.isEmpty ? null : notes,
      };

      if (widget.existingRecord == null) {
        payload['recorded_by_user_id'] = me.userId ?? client.auth.currentUser!.id;
        payload['recorded_by_name'] = me.fullName;

        final inserted = await client
            .from('health_records')
            .insert(payload)
            .select('id')
            .single();

        await logFamilyActivity(
          client,
          familyId: me.familyId,
          targetProfileId: profileId,
          actorUserId: client.auth.currentUser!.id,
          actorName: me.fullName,
          actionType: 'create',
          entityType: 'record',
          entityId: inserted['id'] as String,
          summary: 'Mencatat pemeriksaan kesehatan untuk ${targetMember.fullName}',
        );
      } else {
        payload['updated_by_user_id'] = client.auth.currentUser!.id;
        payload['updated_by_name'] = me.fullName;

        await client
            .from('health_records')
            .update(payload)
            .eq('id', widget.existingRecord!.id);

        await logFamilyActivity(
          client,
          familyId: me.familyId,
          targetProfileId: profileId,
          actorUserId: client.auth.currentUser!.id,
          actorName: me.fullName,
          actionType: 'update',
          entityType: 'record',
          entityId: widget.existingRecord!.id,
          summary:
              'Memperbarui catatan kesehatan milik ${targetMember.fullName}',
        );
      }

      ref.invalidate(healthRecordsProvider);
      ref.invalidate(activityLogsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingRecord == null
                ? 'Catatan kesehatan berhasil disimpan!'
                : 'Catatan kesehatan berhasil diperbarui!',
          ),
          backgroundColor: AppColors.secondaryGreen,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final directoryAsync = ref.watch(familyDirectoryProvider);
    final myProfile = ref.watch(currentProfileProvider).valueOrNull;

    final editableMembers = (directoryAsync.valueOrNull ?? const <HealthProfile>[])
        .where((m) => m.canEdit)
        .toList();

    if (_selectedProfileId == null && editableMembers.isNotEmpty) {
      final preferred = ref.read(selectedProfileIdProvider);
      final match = editableMembers.cast<HealthProfile?>().firstWhere(
            (m) => m?.id == preferred,
            orElse: () => null,
          );
      final chosen = match ??
          editableMembers.cast<HealthProfile?>().firstWhere(
                (m) => m?.id == myProfile?.id,
                orElse: () => null,
              ) ??
          editableMembers.first;
      _selectedProfileId = chosen.id;
      _prefillHeightIfEmpty(chosen);
    }

    // Pratinjau status otomatis
    final sys = int.tryParse(_systolicController.text.trim());
    final dia = int.tryParse(_diastolicController.text.trim());
    final bpStatus = (sys != null && dia != null)
        ? MedicalEvaluator.evaluateBloodPressure(sys, dia)
        : null;

    final sugar = double.tryParse(_sugarController.text.trim().replaceAll(',', '.'));
    final sugarStatus = sugar != null
        ? MedicalEvaluator.evaluateBloodSugar(sugar, _sugarType)
        : null;

    final weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    final height = double.tryParse(_heightController.text.trim().replaceAll(',', '.'));
    final bmi = MedicalEvaluator.calculateBmi(weight, height);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingRecord == null
              ? 'Catat Pemeriksaan'
              : 'Ubah Catatan Pemeriksaan',
        ),
      ),
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
                      'Untuk Anggota Keluarga',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    if (editableMembers.isEmpty)
                      const Text('Memuat daftar anggota...')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: editableMembers.map((m) {
                          return ChoiceChip(
                            label: Text('${m.fullName} (${m.relationLabel})'),
                            selected: _selectedProfileId == m.id,
                            onSelected: widget.existingRecord != null
                                ? null
                                : (_) {
                                    setState(() {
                                      _selectedProfileId = m.id;
                                      _prefillHeightIfEmpty(m);
                                    });
                                  },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDateTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Waktu: ${AppDateFormatter.dateTime(_recordedAt)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Text(
                              'Ubah',
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Tekanan Darah
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tekanan Darah (Opsional)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (bpStatus != null) StatusBadge(status: bpStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _systolicController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Sistolik (Atas)',
                              hintText: '120',
                              suffixText: 'mmHg',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _diastolicController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Diastolik (Bawah)',
                              hintText: '80',
                              suffixText: 'mmHg',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Gula Darah
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gula Darah (Opsional)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (sugarStatus != null)
                          StatusBadge(status: sugarStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sugarController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Kadar Gula Darah',
                        hintText: '105',
                        suffixText: 'mg/dL',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Sewaktu'),
                          selected: _sugarType == 'random',
                          onSelected: (_) =>
                              setState(() => _sugarType = 'random'),
                        ),
                        ChoiceChip(
                          label: const Text('Puasa'),
                          selected: _sugarType == 'fasting',
                          onSelected: (_) =>
                              setState(() => _sugarType = 'fasting'),
                        ),
                        ChoiceChip(
                          label: const Text('2 Jam Stlh Makan'),
                          selected: _sugarType == 'post_meal',
                          onSelected: (_) =>
                              setState(() => _sugarType = 'post_meal'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Suhu, Nadi, Berat & Tinggi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tanda Vital & Fisik (Opsional)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (bmi != null)
                          StatusBadge(
                            status: MedicalEvaluator.evaluateBmi(bmi),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tempController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Suhu Tubuh',
                              hintText: '36.6',
                              suffixText: '°C',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _heartRateController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Denyut Nadi',
                              hintText: '76',
                              suffixText: 'bpm',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Berat Badan',
                              hintText: '60.5',
                              suffixText: 'kg',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Tinggi Badan',
                              hintText: '165',
                              suffixText: 'cm',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Keluhan & Catatan
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keluhan & Catatan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _symptomsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Keluhan Kesehatan',
                        hintText: 'Contoh: Pusing ringan, batuk sejak kemarin',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Tambahan',
                        hintText: 'Contoh: Diukur setelah istirahat 10 menit',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

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
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                widget.existingRecord == null
                    ? 'Simpan Pemeriksaan'
                    : 'Simpan Perubahan',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
