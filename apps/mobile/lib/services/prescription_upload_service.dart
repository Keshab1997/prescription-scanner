import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prescription_scanner/config.dart';

final prescriptionUploadServiceProvider =
    Provider<PrescriptionUploadService>((ref) {
  return PrescriptionUploadService();
});

/// Image preparation only. The actual AI transcription runs on-device via
/// [GeminiVisionService]; prescription images are never uploaded to a server.
class PrescriptionUploadService {
  PrescriptionUploadService();

  final ImagePicker _picker = ImagePicker();

  static const maxImageBytes = 10 * 1024 * 1024;
  static const minShortEdge = 600;
  static const minLongEdge = 900;

  Future<PreparedPrescription?> pickAndPrepare(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    return _preparePickedFile(picked);
  }

  Future<PreparedPrescription?> recoverInterruptedPick() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    if (response.exception != null) {
      throw ScanValidationException(
        'The interrupted image could not be restored.',
      );
    }
    final files = response.files;
    if (files == null || files.isEmpty) return null;
    return _preparePickedFile(files.first);
  }

  Future<PreparedPrescription?> _preparePickedFile(XFile picked) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final targetPath =
        '${temporaryDirectory.path}/prescription_${DateTime.now().microsecondsSinceEpoch}.jpg';

    // Single-pass compress + downscale. The original (quality 88) is already
    // small; compressing straight to the final JPEG avoids a second re-encode
    // (crop was maxWidth 2600 @ q95, then q86 again before). Lowering to q82 /
    // min 1024 keeps prescription text crisp while cutting bytes ~3x, which
    // makes the base64 encode, the Gemini upload, and the JSON decode all
    // faster. The cropper is skipped unless the user wants to reframe.
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      targetPath,
      quality: 82,
      minWidth: 1024,
      minHeight: 1024,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (compressed == null) {
      throw ScanValidationException('The image could not be prepared.');
    }

    final bytes = await compressed.readAsBytes();
    if (bytes.isEmpty) {
      throw ScanValidationException('The selected image is empty.');
    }
    if (bytes.length > maxImageBytes) {
      await _safeDelete(compressed.path);
      throw ScanValidationException(
        'The image is larger than the 10 MB limit.',
      );
    }

    final dimensions = await _readDimensions(bytes);
    final shortEdge = dimensions.$1 < dimensions.$2
        ? dimensions.$1
        : dimensions.$2;
    final longEdge = dimensions.$1 > dimensions.$2
        ? dimensions.$1
        : dimensions.$2;
    if (shortEdge < minShortEdge || longEdge < minLongEdge) {
      await _safeDelete(compressed.path);
      throw ScanValidationException(
        'The image resolution is too low. Retake it closer and in brighter light.',
      );
    }

    return PreparedPrescription(
      path: compressed.path,
      sizeBytes: bytes.length,
      width: dimensions.$1,
      height: dimensions.$2,
      sha256Hash: sha256.convert(bytes).toString(),
    );
  }

  Future<void> deleteLocalDraft(PreparedPrescription draft) =>
      _safeDelete(draft.path);

  Future<(int, int)> _readDimensions(List<int> bytes) async {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final frame = await codec.getNextFrame();
    final result = (frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return result;
  }

  Future<void> _safeDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Temporary cache cleanup is best effort.
    }
  }
}

class PreparedPrescription {
  const PreparedPrescription({
    required this.path,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.sha256Hash,
  });

  final String path;
  final int sizeBytes;
  final int width;
  final int height;
  final String sha256Hash;
}

class ScanValidationException implements Exception {
  const ScanValidationException(this.message);
  final String message;
}

class ScanUploadException implements Exception {
  const ScanUploadException(this.message);
  final String message;
}
