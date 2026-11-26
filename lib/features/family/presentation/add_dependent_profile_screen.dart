import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';

class AddDependentProfileScreen extends ConsumerStatefulWidget {
  const AddDependentProfileScreen({super.key});

  @override
  ConsumerState<AddDependentProfileScreen> createState() =>
      _AddDependentProfileScreenState();
}

class _AddDependentProfileScreenState
    extends ConsumerState<AddDependentProfileScreen> {
  final _nameController = TextEditingController();
  final _relationController = TextEditingController(text: 'Orang Tua');
  final _heightController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _chronicController = TextEditingController();

  DateTime? _birthDate;
  String? _gender;
  String _bloodType = 'Tidak Tahu';
  bool _isSaving = false;

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
        const SnackBar(content: Text('Masukkan nama lengkap anggota')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final height = double.tryParse(
        _heightController.text.trim().replaceAll(',', '.'),
      );

      await client.rpc('create_managed_profile', params: {
        'p_full_name': _nameController.text.trim(),
        'p_relation_label': _relationController.text.trim().isEmpty
            ? 'Anggota'
            : _relationController.text.trim(),
        'p_birth_date': _birthDate?.toIso8601String().substring(0, 10),
        'p_gender': _gender,
        'p_blood_type': _bloodType,
        'p_allergies': _allergiesController.text.trim(),
        'p_chronic_conditions': _chronicController.text.trim(),
        'p_default_height_cm': height,
      });

      ref.invalidate(familyDirectoryProvider);
      ref.invalidate(activityLogsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profil anggota tanpa akun berhasil dibuat beserta kode klaimnya!',
          ),
          backgroundColor: AppColors.secondaryGreen,
        ),
      );
      context.pop();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
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
      appBar: AppBar(title: const Text('Tambah Anggota Tanpa Akun')),
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
                      'Cocok untuk orang tua/lansia atau anak kecil yang belum memakai HP sendiri. Sistem otomatis membuatkan Kode Klaim jika kelak mereka ingin masuk memakai akun sendiri.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap',
                        hintText: 'Contoh: Ibu Siti Aminah',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _relationController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Hubungan Keluarga',
                        hintText: 'Contoh: Ibu, Ayah, Nenek, Anak',
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(1960, 1, 1),
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
                        labelText: 'Tinggi Badan Bawaan (cm, Opsional)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _allergiesController,
                      decoration: const InputDecoration(
                        labelText: 'Alergi (Opsional)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _chronicController,
                      decoration: const InputDecoration(
                        labelText: 'Riwayat Kondisi Kesehatan (Opsional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                  : const Text('Buat Profil Anggota'),
            ),
          ],
        ),
      ),
    );
  }
}
