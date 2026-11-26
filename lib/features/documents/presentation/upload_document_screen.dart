import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/media_compressor.dart';
import '../../../models/health_profile.dart';

class UploadDocumentScreen extends ConsumerStatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  ConsumerState<UploadDocumentScreen> createState() =>
      _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends ConsumerState<UploadDocumentScreen> {
  String? _selectedProfileId;
  String _category = 'lab_result';
  DateTime _documentDate = DateTime.now();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  Uint8List? _fileBytes;
  String? _fileExtension;
  String? _mimeType;
  String? _pickedFileLabel;
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source);
    if (xfile == null) return;

    final compressed = await MediaCompressor.compressImageFile(File(xfile.path));
    setState(() {
      _fileBytes = compressed.bytes;
      _fileExtension = compressed.extension;
      _mimeType = compressed.mimeType;
      _pickedFileLabel =
          'Foto (${(compressed.bytes.length / 1024).toStringAsFixed(0)} KB)';
    });
  }

  Future<void> _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;

    final f = res.files.single;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) return;

    if (bytes.length > MediaCompressor.maxPdfSizeBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ukuran file PDF melebihi batas maksimal 5 MB'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
      return;
    }

    setState(() {
      _fileBytes = bytes;
      _fileExtension = 'pdf';
      _mimeType = 'application/pdf';
      _pickedFileLabel =
          '${f.name} (${(bytes.length / 1024).toStringAsFixed(0)} KB)';
    });
  }

  Future<void> _upload() async {
    if (_selectedProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pemilik dokumen')),
      );
      return;
    }
    if (_titleController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan judul dokumen')),
      );
      return;
    }
    if (_fileBytes == null || _fileExtension == null || _mimeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih foto atau file PDF terlebih dahulu')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final me = await ref.read(currentProfileProvider.future);
      final members = await ref.read(familyDirectoryProvider.future);
      if (me == null) throw Exception('Profil tidak ditemukan');

      final target = members.firstWhere(
        (m) => m.id == _selectedProfileId,
        orElse: () => me,
      );

      final docUuid = const Uuid().v4();
      final storagePath =
          '${me.familyId}/$_selectedProfileId/$docUuid.$_fileExtension';

      await client.storage.from('health-documents').uploadBinary(
            storagePath,
            _fileBytes!,
            fileOptions: FileOptions(contentType: _mimeType!),
          );

      final inserted = await client
          .from('health_documents')
          .insert({
            'family_id': me.familyId,
            'profile_id': _selectedProfileId,
            'uploaded_by_user_id': client.auth.currentUser!.id,
            'uploaded_by_name': me.fullName,
            'title': _titleController.text.trim(),
            'category': _category,
            'storage_path': storagePath,
            'mime_type': _mimeType,
            'file_size_bytes': _fileBytes!.length,
            'document_date': _documentDate.toIso8601String().substring(0, 10),
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          })
          .select('id')
          .single();

      await logFamilyActivity(
        client,
        familyId: me.familyId,
        targetProfileId: _selectedProfileId,
        actorUserId: client.auth.currentUser!.id,
        actorName: me.fullName,
        actionType: 'create',
        entityType: 'document',
        entityId: inserted['id'] as String,
        summary:
            'Mengunggah dokumen "${_titleController.text.trim()}" milik ${target.fullName}',
      );

      ref.invalidate(healthDocumentsProvider);
      ref.invalidate(activityLogsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dokumen kesehatan berhasil disimpan!'),
          backgroundColor: AppColors.secondaryGreen,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunggah dokumen: $e'),
          backgroundColor: AppColors.statusHigh,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
      appBar: AppBar(title: const Text('Unggah Dokumen Kesehatan')),
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
                      'Pemilik Dokumen',
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
                      'Kategori Dokumen',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _catChip('lab_result', 'Hasil Lab'),
                        _catChip('prescription', 'Resep Dokter'),
                        _catChip('referral', 'Surat Rujukan'),
                        _catChip('other', 'Lainnya'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul Dokumen',
                        hintText: 'Contoh: Hasil Cek Darah Lengkap Nov 2026',
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _documentDate,
                          firstDate: DateTime(2010),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _documentDate = picked);
                        }
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
                              Icons.date_range_rounded,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tanggal Dokumen: ${AppDateFormatter.dateOnly(_documentDate)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (Opsional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Berkas (Foto Otomatis Dikompresi)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Kamera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galeri'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Pilih File PDF (Maks 5 MB)'),
                    ),
                    if (_pickedFileLabel != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryGreenSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.secondaryGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _pickedFileLabel!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isUploading ? null : _upload,
              icon: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: const Text('Unggah & Simpan Dokumen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _category == value,
      onSelected: (_) => setState(() => _category = value),
    );
  }
}
