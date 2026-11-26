import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class CompressedMediaResult {
  const CompressedMediaResult({
    required this.bytes,
    required this.extension,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String extension;
  final String mimeType;
}

class MediaCompressor {
  MediaCompressor._();

  static const int maxPdfSizeBytes = 5 * 1024 * 1024; // 5 MB

  /// Mengompresi gambar agar hemat kuota Supabase Storage Free Tier (1 GB).
  static Future<CompressedMediaResult> compressImageFile(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/jb_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 75,
      minWidth: 1280,
      minHeight: 1280,
      format: CompressFormat.jpeg,
    );

    if (compressed != null) {
      final bytes = await compressed.readAsBytes();
      return CompressedMediaResult(
        bytes: bytes,
        extension: 'jpg',
        mimeType: 'image/jpeg',
      );
    }

    final fallbackBytes = await file.readAsBytes();
    return CompressedMediaResult(
      bytes: fallbackBytes,
      extension: 'jpg',
      mimeType: 'image/jpeg',
    );
  }
}
