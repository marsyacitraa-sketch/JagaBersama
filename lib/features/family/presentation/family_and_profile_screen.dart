import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/accessibility_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../models/health_profile.dart';

class FamilyAndProfileScreen extends ConsumerWidget {
  const FamilyAndProfileScreen({super.key});

  Future<void> _copyCode(BuildContext context, String label, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label ($code) disalin ke clipboard'),
        backgroundColor: AppColors.secondaryGreen,
      ),
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    WidgetRef ref,
    HealthProfile member,
    String newRole,
  ) async {
    try {
      await ref.read(supabaseClientProvider).rpc('update_member_role', params: {
        'p_profile_id': member.id,
        'p_new_role': newRole,
      });
      ref.invalidate(familyDirectoryProvider);
      ref.invalidate(activityLogsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peran anggota berhasil diperbarui'),
          backgroundColor: AppColors.secondaryGreen,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah peran: $e'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    HealthProfile member,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${member.fullName}?'),
        content: const Text(
          'Profil beserta seluruh riwayat kesehatan dan jadwalnya di keluarga ini akan dihapus permanen.',
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
      await client.from('health_profiles').delete().eq('id', member.id);

      if (me != null) {
        await logFamilyActivity(
          client,
          familyId: me.familyId,
          actorUserId: client.auth.currentUser!.id,
          actorName: me.fullName,
          actionType: 'delete',
          entityType: 'profile',
          summary: 'Menghapus profil anggota "${member.fullName}"',
        );
      }
      ref.invalidate(familyDirectoryProvider);
      ref.invalidate(healthRecordsProvider);
      ref.invalidate(healthSchedulesProvider);
      ref.invalidate(activityLogsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus anggota: $e'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentProfileProvider);
    final familyAsync = ref.watch(familyGroupProvider);
    final directoryAsync = ref.watch(familyDirectoryProvider);
    final largeText = ref.watch(largeTextModeProvider);

    final me = meAsync.valueOrNull;
    final family = familyAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Keluarga & Profil')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentProfileProvider);
          ref.invalidate(familyGroupProvider);
          ref.invalidate(familyDirectoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Profil Saya
            if (me != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.primaryBlueSoft,
                            child: Text(
                              me.fullName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  me.fullName,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  '${me.relationLabel} • ${me.roleLabel}',
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                context.push('/profile/edit', extra: me),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Ubah Profil & Izin',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoPill(
                            label: 'Izin Pengelola: ${me.permissionLabel}',
                            color: AppColors.secondaryGreen,
                            bg: AppColors.secondaryGreenSoft,
                          ),
                          if (me.bloodType != null)
                            _InfoPill(
                              label: 'Gol. Darah: ${me.bloodType}',
                              color: AppColors.primaryBlue,
                              bg: AppColors.primaryBlueSoft,
                            ),
                        ],
                      ),
                      if (me.allergies != null && me.allergies!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Alergi: ${me.allergies}'),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Kartu Grup Keluarga & Kode Undangan
            if (family != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        family.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bagikan kode undangan agar anggota keluarga lain dapat bergabung:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlueSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                family.inviteCode,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _copyCode(
                                context,
                                'Kode undangan',
                                family.inviteCode,
                              ),
                              icon: const Icon(Icons.copy_rounded),
                              tooltip: 'Salin',
                            ),
                            IconButton(
                              onPressed: () => Share.share(
                                'Gabung ke grup kesehatan keluarga "${family.name}" di aplikasi JagaBersama menggunakan kode undangan: ${family.inviteCode}',
                              ),
                              icon: const Icon(Icons.share_rounded),
                              tooltip: 'Bagikan',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Daftar Anggota Keluarga
            SectionHeader(
              title: 'Anggota Keluarga',
              actionLabel: (me?.isManager ?? false) ? '+ Tanpa Akun' : null,
              onAction: (me?.isManager ?? false)
                  ? () => context.push('/family/add-dependent')
                  : null,
            ),
            const SizedBox(height: 10),
            directoryAsync.when(
              data: (members) {
                return Column(
                  children: members.map((m) {
                    final isMe = m.id == me?.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: m.isDependent
                                      ? AppColors.secondaryGreenSoft
                                      : AppColors.primaryBlueSoft,
                                  child: Icon(
                                    m.isDependent
                                        ? Icons.elderly_rounded
                                        : Icons.person_rounded,
                                    color: m.isDependent
                                        ? AppColors.secondaryGreen
                                        : AppColors.primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${m.fullName}${isMe ? ' (Anda)' : ''}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '${m.relationLabel} • ${m.roleLabel}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                                if ((me?.isOwner ?? false) && !isMe)
                                  PopupMenuButton<String>(
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        context.push('/profile/edit', extra: m);
                                      } else if (action == 'make_caretaker') {
                                        _changeRole(
                                            context, ref, m, 'caretaker');
                                      } else if (action == 'make_member') {
                                        _changeRole(context, ref, m, 'member');
                                      } else if (action == 'delete') {
                                        _removeMember(context, ref, m);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (m.isDependent)
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Ubah Profil'),
                                        ),
                                      if (!m.isDependent && m.role == 'member')
                                        const PopupMenuItem(
                                          value: 'make_caretaker',
                                          child: Text('Jadikan Pengelola'),
                                        ),
                                      if (!m.isDependent &&
                                          m.role == 'caretaker')
                                        const PopupMenuItem(
                                          value: 'make_member',
                                          child: Text('Jadikan Anggota Biasa'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          'Hapus Anggota',
                                          style: TextStyle(
                                            color: AppColors.statusHigh,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else if ((me?.isCaretaker ?? false) &&
                                    m.isDependent)
                                  IconButton(
                                    onPressed: () =>
                                        context.push('/profile/edit', extra: m),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                              ],
                            ),
                            if (m.isDependent &&
                                m.claimCode != null &&
                                (me?.isManager ?? false)) ...[
                              const SizedBox(height: 10),
                              InkWell(
                                onTap: () => _copyCode(
                                  context,
                                  'Kode klaim ${m.fullName}',
                                  m.claimCode!,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryGreenSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.key_rounded,
                                        size: 16,
                                        color: AppColors.secondaryGreen,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Kode Klaim: ${m.claimCode} (Ketuk salin)',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.secondaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Gagal memuat anggota: $e'),
            ),
            const SizedBox(height: 14),

            // Jejak Aktivitas & Pengaturan
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.history_edu_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    title: const Text('Log Aktivitas & Perubahan Data'),
                    subtitle: const Text(
                      'Telusuri siapa yang mencatat atau mengubah data',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/family/activity-logs'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.text_fields_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    title: const Text('Mode Teks Besar (Ramah Lansia)'),
                    subtitle: const Text('Memperbesar ukuran tulisan aplikasi'),
                    value: largeText,
                    onChanged: (_) =>
                        ref.read(largeTextModeProvider.notifier).toggle(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.statusHigh,
                    ),
                    title: const Text(
                      'Keluar dari Akun',
                      style: TextStyle(
                        color: AppColors.statusHigh,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      await ref.read(supabaseClientProvider).auth.signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
