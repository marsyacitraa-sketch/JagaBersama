import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../models/health_document.dart';
import '../../../models/health_profile.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.document,
  });

  final HealthDocument document;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  String? _signedUrl;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  Future<void> _loadSignedUrl() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final url = await client.storage
          .from('health-documents')
          .createSignedUrl(widget.document.storagePath, 300);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat tautan dokumen: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Dokumen?'),
        content: const Text('Dokumen ini akan dihapus permanen.'),
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
    if (confirm != true || !mounted) return;

    try {
      final client = ref.read(supabaseClientProvider);
      final me = await ref.read(currentProfileProvider.future);

      await client.storage
          .from('health-documents')
          .remove([widget.document.storagePath]);
      await client
          .from('health_documents')
          .delete()
          .eq('id', widget.document.id);

      if (me != null) {
        await logFamilyActivity(
          client,
          familyId: me.familyId,
          targetProfileId: widget.document.profileId,
          actorUserId: client.auth.currentUser!.id,
          actorName: me.fullName,
          actionType: 'delete',
          entityType: 'document',
          entityId: widget.document.id,
          summary: 'Menghapus dokumen "${widget.document.title}"',
        );
      }

      ref.invalidate(healthDocumentsProvider);
      ref.invalidate(activityLogsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus dokumen: $e'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(familyDirectoryProvider).valueOrNull ?? const [];
    final owner = members.cast<HealthProfile?>().firstWhere(
          (m) => m?.id == widget.document.profileId,
          orElse: () => null,
        );
    final canEdit = owner?.canEdit ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.statusHigh),
              onPressed: _deleteDocument,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${owner?.fullName ?? 'Anggota'} • ${widget.document.categoryLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tanggal: ${AppDateFormatter.dateOnly(widget.document.documentDate)} • '
                  'Diunggah oleh ${widget.document.uploadedByName} (${widget.document.readableSize})',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (widget.document.notes != null &&
                    widget.document.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Catatan: ${widget.document.notes}'),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      )
                    : widget.document.isPdf
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    size: 72,
                                    color: AppColors.statusHigh,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Dokumen PDF siap dibuka di aplikasi pembaca PDF perangkat Anda.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: 240,
                                    child: FilledButton.icon(
                                      onPressed: () async {
                                        final uri = Uri.parse(_signedUrl!);
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                      icon: const Icon(Icons.open_in_new_rounded),
                                      label: const Text('Buka File PDF'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Center(
                              child: Image.network(
                                _signedUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return const CircularProgressIndicator();
                                },
                                errorBuilder: (_, __, ___) => const Text(
                                  'Gagal menampilkan gambar.',
                                ),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
