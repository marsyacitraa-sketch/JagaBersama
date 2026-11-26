import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/health_profile.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  final HealthProfile profile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _relationController;
  late final TextEditingController _heightController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _chronicController;

  DateTime? _birthDate;
  String? _gender;
  String _bloodType = 'Tidak Tahu';
  String _accessPermission = 'view_only';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.fullName);
    _relationController = TextEditingController(text: p.relationLabel);
    _heightController = TextEditingController(
      text: p.defaultHeightCm?.toStringAsFixed(0) ?? '',
    );
    _allergiesController = TextEditingController(text: p.allergies ?? '');
    _chronicController =
        TextEditingController(text: p.chronicConditions ?? '');
    _birthDate = p.birthDate;
    _gender = p.gender;
    _bloodType = p.bloodType ?? 'Tidak Tahu';
    _accessPermission = p.accessPermission;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _heightController.dispose();
    _allergiesController.dispose();
    _chronicController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama lengkap minimal 2 karakter')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final me = await ref.read(currentProfileProvider.future);

      final defaultHeight = double.tryParse(
        _heightController.text.trim().replaceAll(',', '.'),
      );

      await client.from('health_profiles').update({
        'full_name': _nameController.text.trim(),
        'relation_label': _relationController.text.trim().isEmpty
            ? 'Anggota'
            : _relationController.text.trim(),
        'birth_date': _birthDate?.toIso8601String().substring(0, 10),
        'gender': _gender,
        'blood_type': _bloodType,
        'default_height_cm': defaultHeight,
        'allergies': _allergiesController.text.trim().isEmpty
            ? null
            : _allergiesController.text.trim(),
        'chronic_conditions': _chronicController.text.trim().isEmpty
            ? null
            : _chronicController.text.trim(),
        if (!widget.profile.isDependent) 'access_permission': _accessPermission,
      }).eq('id', widget.profile.id);

      if (me != null) {
        final permChanged = !widget.profile.isDependent &&
            _accessPermission != widget.profile.accessPermission;
        await logFamilyActivity(
          client,
          familyId: me.familyId,
          targetProfileId: widget.profile.id,
          actorUserId: client.auth.currentUser!.id,
          actorName: me.fullName,
          actionType: permChanged ? 'permission_change' : 'update',
          entityType: 'profile',
          entityId: widget.profile.id,
          summary: permChanged
              ? 'Mengubah izin akses profil ${_nameController.text.trim()}'
              : 'Memperbarui data profil ${_nameController.text.trim()}',
        );
      }

      ref.invalidate(currentProfileProvider);
      ref.invalidate(familyDirectoryProvider);
      ref.invalidate(activityLogsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: AppColors.secondaryGreen,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan profil: $e'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Profil Kesehatan')),
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
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _relationController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Hubungan Keluarga',
                        hintText: 'Contoh: Ayah, Ibu, Anak',
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _birthDate ?? DateTime(1980, 1, 1),
                          firstDate: DateTime(1920),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _birthDate = picked);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cake_outlined,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _birthDate == null
                                    ? 'Pilih Tanggal Lahir (Opsional)'
                                    : 'Tanggal Lahir: ${AppDateFormatter.dateOnly(_birthDate!)}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Jenis Kelamin',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Laki-laki'),
                          selected: _gender == 'Laki-laki',
                          onSelected: (_) =>
                              setState(() => _gender = 'Laki-laki'),
                        ),
                        ChoiceChip(
                          label: const Text('Perempuan'),
                          selected: _gender == 'Perempuan',
                          onSelected: (_) =>
                              setState(() => _gender = 'Perempuan'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Golongan Darah',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['A', 'B', 'AB', 'O', 'Tidak Tahu']
                          .map(
                            (b) => ChoiceChip(
                              label: Text(b),
                              selected: _bloodType == b,
                              onSelected: (_) => setState(() => _bloodType = b),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tinggi Badan Bawaan (cm)',
                        hintText: '165',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _allergiesController,
                      decoration: const InputDecoration(
                        labelText: 'Riwayat Alergi',
                        hintText: 'Contoh: Alergi obat penisilin, udang',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _chronicController,
                      decoration: const InputDecoration(
                        labelText: 'Kondisi / Riwayat Penyakit',
                        hintText: 'Contoh: Hipertensi ringan, Diabetes',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!widget.profile.isDependent) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Izin Akses untuk Admin & Pengelola',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tentukan apakah Admin/Pengelola boleh melihat atau membantu menginput catatan kesehatan Anda.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Privat'),
                            selected: _accessPermission == 'private',
                            onSelected: (_) =>
                                setState(() => _accessPermission = 'private'),
                          ),
                          ChoiceChip(
                            label: const Text('Lihat Saja'),
                            selected: _accessPermission == 'view_only',
                            onSelected: (_) =>
                                setState(() => _accessPermission = 'view_only'),
                          ),
                          ChoiceChip(
                            label: const Text('Lihat & Input'),
                            selected: _accessPermission == 'view_and_edit',
                            onSelected: (_) => setState(
                              () => _accessPermission = 'view_and_edit',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Profil'),
            ),
          ],
        ),
      ),
    );
  }
}
