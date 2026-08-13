import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prescription_scanner/config.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final prescriptionUploadServiceProvider = Provider<PrescriptionUploadService?>((
  ref,
) {
  if (!AppConfig.hasSupabaseConfig) return null;
  return PrescriptionUploadService(Supabase.instance.client);
});

class PrescriptionUploadService {
  PrescriptionUploadService(this.client);

  final SupabaseClient client;
  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();

  static const maxImageBytes = 10 * 1024 * 1024;
  static const minShortEdge = 600;
  static const minLongEdge = 900;
  static const aiConsentPolicyVersion = '2026-08-13';

  Future<bool> hasCurrentAiConsent() async {
    final rows = await client
        .from('consent_records')
        .select('id')
        .eq('consent_type', 'ai_processing')
        .eq('policy_version', aiConsentPolicyVersion)
        .eq('granted', true)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> recordAiConsent() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const ScanUploadException('Sign in again to continue.');
    }
    await client.from('consent_records').insert({
      'user_id': userId,
      'consent_type': 'ai_processing',
      'policy_version': aiConsentPolicyVersion,
      'granted': true,
      'locale': 'en-IN',
    });
  }

  Future<PreparedPrescription?> pickAndPrepare(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 100,
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
    final cropped = await _cropper.cropImage(
      sourcePath: picked.path,
      maxWidth: 2600,
      maxHeight: 2600,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust prescription',
          toolbarColor: AppColors.teal,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.teal,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
      ],
    );
    if (cropped == null) return null;

    final temporaryDirectory = await getTemporaryDirectory();
    final targetPath =
        '${temporaryDirectory.path}/prescription_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      cropped.path,
      targetPath,
      quality: 86,
      minWidth: 1200,
      minHeight: 1200,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    await _safeDelete(cropped.path);
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

  Future<UploadedPrescription> reserveAndUpload(
    PreparedPrescription draft,
  ) async {
    String? prescriptionId;
    try {
      final rpcResult = await client.rpc(
        'create_prescription_upload',
        params: {
          'p_original_filename': 'prescription.jpg',
          'p_mime_type': 'image/jpeg',
          'p_size_bytes': draft.sizeBytes,
          'p_image_hash': draft.sha256Hash,
        },
      );
      final row = _firstRpcRow(rpcResult);
      prescriptionId = row['prescription_id']?.toString();
      final storagePath = row['storage_path']?.toString();
      if (prescriptionId == null || storagePath == null) {
        throw ScanUploadException('The upload reservation was invalid.');
      }

      await client.storage
          .from('prescriptions')
          .upload(
            storagePath,
            File(draft.path),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
              cacheControl: '0',
            ),
          );

      return UploadedPrescription(
        prescriptionId: prescriptionId,
        storagePath: storagePath,
      );
    } catch (error) {
      if (prescriptionId != null) {
        try {
          await client.rpc(
            'cancel_prescription_upload',
            params: {'p_prescription_id': prescriptionId},
          );
        } catch (_) {
          // A cleanup worker will remove stale reservations if this best-effort call fails.
        }
      }
      if (error is ScanUploadException) rethrow;
      if (error is PostgrestException) {
        throw ScanUploadException(_friendlyDatabaseMessage(error));
      }
      if (error is StorageException) {
        throw ScanUploadException(
          'Secure upload failed. Check your connection and retry.',
        );
      }
      throw ScanUploadException('The prescription could not be uploaded.');
    }
  }

  Future<void> deleteLocalDraft(PreparedPrescription draft) =>
      _safeDelete(draft.path);

  Map<String, dynamic> _firstRpcRow(Object? result) {
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    if (result is Map) return Map<String, dynamic>.from(result);
    return const {};
  }

  String _friendlyDatabaseMessage(PostgrestException error) {
    final message = error.message.toUpperCase();
    if (message.contains('DAILY_LIMIT_REACHED')) {
      return 'You have used all available scans for today.';
    }
    if (message.contains('AI_DISABLED')) {
      return 'AI processing is temporarily unavailable.';
    }
    if (message.contains('MAINTENANCE_MODE')) {
      return 'Prescription Scanner is under maintenance. Try again later.';
    }
    if (message.contains('USER_NOT_ACTIVE')) {
      return 'This account cannot upload prescriptions.';
    }
    if (message.contains('IMAGE_SIZE_LIMIT')) {
      return 'The image is larger than the server limit.';
    }
    return 'The secure upload could not be reserved.';
  }

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

class UploadedPrescription {
  const UploadedPrescription({
    required this.prescriptionId,
    required this.storagePath,
  });

  final String prescriptionId;
  final String storagePath;
}

class ScanValidationException implements Exception {
  const ScanValidationException(this.message);
  final String message;
}

class ScanUploadException implements Exception {
  const ScanUploadException(this.message);
  final String message;
}
