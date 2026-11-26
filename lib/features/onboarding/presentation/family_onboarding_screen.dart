import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';

enum _OnboardingMode { createFamily, joinFamily, claimProfile }

class FamilyOnboardingScreen extends ConsumerStatefulWidget {
  const FamilyOnboardingScreen({super.key});

  @override
  ConsumerState<FamilyOnboardingScreen> createState() =>
      _FamilyOnboardingScreenState();
}

class _FamilyOnboardingScreenState
    extends ConsumerState<FamilyOnboardingScreen> {
  _OnboardingMode _mode = _OnboardingMode.createFamily;
  final _familyNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _relationController = TextEditingController(text: 'Anak');
  final _codeController = TextEditingController();
  String _accessPermission = 'view_only';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    final metaName = user?.userMetadata?['full_name'] as String?;
    if (metaName != null && metaName.isNotEmpty) {
      _fullNameController.text = metaName;
    }
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    _fullNameController.dispose();
    _relationController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final client = ref.read(supabaseClientProvider);
    setState(() => _isLoading = true);

    try {
      if (_mode == _OnboardingMode.createFamily) {
        if (_familyNameController.text.trim().length < 2 ||
            _fullNameController.text.trim().length < 2) {
          throw Exception('Nama keluarga dan nama Anda wajib diisi.');
        }
        await client.rpc('create_family_with_owner', params: {
          'p_family_name': _familyNameController.text.trim(),
          'p_full_name': _fullNameController.text.trim(),
          'p_relation_label': _relationController.text.trim().isEmpty
              ? 'Admin Keluarga'
              : _relationController.text.trim(),
        });
      } else if (_mode == _OnboardingMode.joinFamily) {
        if (_codeController.text.trim().isEmpty ||
            _fullNameController.text.trim().length < 2) {
          throw Exception('Kode undangan dan nama lengkap wajib diisi.');
        }
        await client.rpc('join_family_by_invite_code', params: {
          'p_invite_code': _codeController.text.trim().toUpperCase(),
          'p_full_name': _fullNameController.text.trim(),
          'p_relation_label': _relationController.text.trim().isEmpty
              ? 'Anggota'
              : _relationController.text.trim(),
          'p_access_permission': _accessPermission,
        });
      } else {
        if (_codeController.text.trim().isEmpty) {
          throw Exception('Masukkan kode klaim profil dari Admin Keluarga.');
        }
        await client.rpc('claim_profile_by_code', params: {
          'p_claim_code': _codeController.text.trim().toUpperCase(),
        });
      }

      ref.invalidate(currentProfileProvider);
      ref.invalidate(familyGroupProvider);
      ref.invalidate(familyDirectoryProvider);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.statusHigh),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siapkan Grup Keluarga'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pilih cara Anda bergabung',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Satu akun terhubung dengan satu grup keluarga agar lebih praktis dipantau.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _ModeCard(
                selected: _mode == _OnboardingMode.createFamily,
                icon: Icons.family_restroom_rounded,
                title: 'Buat Keluarga Baru',
                subtitle: 'Anda menjadi Admin Utama dan mendapat kode undangan',
                onTap: () => setState(() => _mode = _OnboardingMode.createFamily),
              ),
              const SizedBox(height: 10),
              _ModeCard(
                selected: _mode == _OnboardingMode.joinFamily,
                icon: Icons.group_add_rounded,
                title: 'Gabung via Kode Undangan',
                subtitle: 'Masuk ke grup keluarga yang sudah dibuat anggota lain',
                onTap: () => setState(() => _mode = _OnboardingMode.joinFamily),
              ),
              const SizedBox(height: 10),
              _ModeCard(
                selected: _mode == _OnboardingMode.claimProfile,
                icon: Icons.verified_user_rounded,
                title: 'Klaim Profil yang Ada',
                subtitle:
                    'Untuk orang tua/anggota yang profilnya sudah dibuatkan Admin',
                onTap: () => setState(() => _mode = _OnboardingMode.claimProfile),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_mode == _OnboardingMode.createFamily) ...[
                        TextField(
                          controller: _familyNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama Grup Keluarga',
                            hintText: 'Contoh: Keluarga Santoso',
                            prefixIcon: Icon(Icons.home_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_mode != _OnboardingMode.createFamily) ...[
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: _mode == _OnboardingMode.joinFamily
                                ? 'Kode Undangan Keluarga'
                                : 'Kode Klaim Profil',
                            hintText: _mode == _OnboardingMode.joinFamily
                                ? 'Contoh: JB-A8K2M4'
                                : 'Contoh: KL-P9X4R2',
                            prefixIcon: const Icon(Icons.qr_code_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (_mode != _OnboardingMode.claimProfile) ...[
                        TextField(
                          controller: _fullNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap Anda',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _relationController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Peran di Keluarga',
                            hintText: 'Contoh: Ayah, Ibu, Anak, Kakak',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ],
                      if (_mode == _OnboardingMode.joinFamily) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Izin Akses untuk Pengelola Keluarga',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
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
                              onSelected: (_) => setState(
                                () => _accessPermission = 'view_only',
                              ),
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
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _mode == _OnboardingMode.createFamily
                                    ? 'Buat Grup Keluarga'
                                    : _mode == _OnboardingMode.joinFamily
                                        ? 'Gabung Keluarga'
                                        : 'Klaim Profil Sekarang',
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
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlueSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryBlue
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }
}
