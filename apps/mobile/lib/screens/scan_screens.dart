import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prescription_scanner/services/gemini_vision_service.dart';
import 'package:prescription_scanner/services/prescription_upload_service.dart';
import 'package:prescription_scanner/services/result_store.dart';
import 'package:prescription_scanner/theme.dart';

const String _consentBox = 'rx_consent';

Future<bool> _hasLocalAiConsent() async {
  final box = await Hive.openBox(_consentBox);
  return box.get('ai_consent_v1', defaultValue: false) as bool;
}

Future<void> _recordLocalAiConsent() async {
  final box = await Hive.openBox(_consentBox);
  await box.put('ai_consent_v1', true);
}

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  PreparedPrescription? draft;
  bool preparing = false;
  bool uploading = false;
  String? error;

  bool get busy => preparing || uploading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => recoverInterruptedPick(),
    );
  }

  @override
  void dispose() {
    final service = ref.read(prescriptionUploadServiceProvider);
    final currentDraft = draft;
    if (service != null && currentDraft != null) {
      unawaited(service.deleteLocalDraft(currentDraft));
    }
    super.dispose();
  }

  Future<void> recoverInterruptedPick() async {
    final service = ref.read(prescriptionUploadServiceProvider);
    if (service == null || busy) return;
    try {
      final recovered = await service.recoverInterruptedPick();
      if (recovered != null && mounted) setState(() => draft = recovered);
    } on ScanValidationException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> selectImage(ImageSource source) async {
    final service = ref.read(prescriptionUploadServiceProvider);
    setState(() {
      preparing = true;
      error = null;
    });
    try {
      final prepared = await service.pickAndPrepare(source);
      if (!mounted || prepared == null) return;
      final oldDraft = draft;
      setState(() => draft = prepared);
      if (oldDraft != null) unawaited(service.deleteLocalDraft(oldDraft));
      // Start AI extraction immediately on selection so the slow on-device
      // Gemini call begins without a second tap. The explicit "Continue
      // securely" button stays available to retry if processing fails.
      unawaited(upload());
    } on ScanValidationException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              error = 'The image could not be opened. Please try another one.',
        );
      }
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> upload() async {
    final service = ref.read(prescriptionUploadServiceProvider);
    final vision = GeminiVisionService();
    final selected = draft;
    if (service == null || selected == null) return;

    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final hasConsent = await _hasLocalAiConsent();
      if (!hasConsent) {
        if (!mounted) return;
        final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.shield_outlined, color: AppColors.teal),
            title: const Text('AI processing consent'),
            content: const Text(
              'Your prescription image will be sent securely to KeshabStudios AI to transcribe visible medicine details. The app will not ask the AI to diagnose or recommend treatment. The original image is processed on device and never stored on a server.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('I understand and continue'),
              ),
            ],
          ),
        );
        if (accepted != true) {
          if (mounted) setState(() => uploading = false);
          return;
        }
        await _recordLocalAiConsent();
      }

      // Supabase-free path: send the local image straight to Gemini.
      final localId = const Uuid().v4();
      final result = await vision.processImage(selected.path, localId: localId);
      ResultStore.instance.save(result);

      // Clean up the local draft file now that it has been processed.
      await service.deleteLocalDraft(selected);
      draft = null;
      if (!mounted) return;
      context.push(
        '/processing?prescriptionId=${Uri.encodeComponent(result.id)}',
      );
    } on VisionException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'The scan could not be completed. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New scan'),
            Text(
              'Original image auto-deletes after extraction',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: draft == null
                ? const _EmptyScanFrame(key: ValueKey('empty'))
                : _SelectedScanFrame(
                    key: const ValueKey('selected'),
                    draft: draft!,
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => selectImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => selectImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          if (preparing) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
            const SizedBox(height: 7),
            const Text(
              'Preparing a private, optimized copy…',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFEEEEF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (draft != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : upload,
              icon: uploading
                  ? const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(
                uploading ? 'Uploading securely…' : 'Continue securely',
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For a clearer result',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 12),
                  _Tip('1', 'Keep the paper flat and avoid shadows.'),
                  _Tip('2', 'Upload one prescription page at a time.'),
                  _Tip('3', 'Do not crop medicine names or instructions.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyScanFrame extends StatelessWidget {
  const _EmptyScanFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FBF9), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFA8C4C0)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PaperPreview(),
            SizedBox(height: 24),
            Text(
              'Place the full prescription in frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: Text(
                'Use bright, even light and keep every corner visible.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedScanFrame extends StatelessWidget {
  const _SelectedScanFrame({required this.draft, super.key});
  final PreparedPrescription draft;

  @override
  Widget build(BuildContext context) {
    final megabytes = draft.sizeBytes / (1024 * 1024);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: .78,
            child: Image.file(File(draft.path), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '${draft.width} × ${draft.height} · ${megabytes.toStringAsFixed(1)} MB',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaperPreview extends StatelessWidget {
  const _PaperPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 104,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x221B4955),
            blurRadius: 25,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: const Column(
        children: [
          _PaperLine(30, color: Color(0xFF8ED0C6)),
          _PaperLine(48),
          _PaperLine(38),
          _PaperLine(46),
        ],
      ),
    );
  }
}

class _PaperLine extends StatelessWidget {
  const _PaperLine(this.width, {this.color = AppColors.line});
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 5,
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.number, this.text);
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.indigoSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.indigo,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({required this.prescriptionId, super.key});
  final String prescriptionId;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool running = false;
  String? error;

  @override
  initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => startProcessing());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> startProcessing() async {
    if (running) return;
    if (widget.prescriptionId.isEmpty) {
      setState(
        () => error = 'The prescription ID is missing. Upload the image again.',
      );
      return;
    }

    setState(() {
      running = true;
      error = null;
    });

    try {
      // The vision call already ran on the upload screen; the result is stored
      // locally. Show it immediately instead of a fixed fake spinner delay.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final result = ResultStore.instance.get(widget.prescriptionId);
      if (result == null) {
        if (mounted)
          setState(
            () => error = 'The result could not be found. Please scan again.',
          );
        return;
      }
      if (!mounted) return;
      context.go('/result?prescriptionId=${Uri.encodeComponent(result.id)}');
    } catch (_) {
      if (mounted)
        setState(() => error = 'The result could not be loaded. Please retry.');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.tealSoft,
              AppColors.canvas,
              AppColors.canvas,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        shadowColor: AppColors.teal.withValues(alpha: 0.1),
                        elevation: 8,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI is Extracting',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Please wait a moment safely.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: error != null
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.danger,
                                  size: 48,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: startProcessing,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 260,
                              height: 320,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Background Animated Glow
                                  AnimatedBuilder(
                                    animation: controller,
                                    builder: (context, child) {
                                      return Container(
                                        width: 220 + (30 * controller.value),
                                        height: 280 + (30 * controller.value),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.rectangle,
                                          borderRadius: BorderRadius.circular(
                                            40,
                                          ),
                                          gradient: RadialGradient(
                                            colors: [
                                              AppColors.teal.withValues(
                                                alpha:
                                                    0.2 -
                                                    (0.1 * controller.value),
                                              ),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  const _ProcessingPaper(),

                                  // Premium Scanning Line
                                  AnimatedBuilder(
                                    animation: controller,
                                    builder: (_, _) => Positioned(
                                      top: 40 + (190 * controller.value),
                                      left: 20,
                                      right: 20,
                                      child: Column(
                                        children: [
                                          Container(
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: AppColors.teal,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.teal
                                                      .withValues(alpha: 0.8),
                                                  blurRadius: 16,
                                                  spreadRadius: 2,
                                                ),
                                                BoxShadow(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  AppColors.teal.withValues(
                                                    alpha: 0.15,
                                                  ),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            const CircularProgressIndicator(
                              color: AppColors.teal,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'KeshabStudios AI is structuring...',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.2,
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

class _ProcessingPaper extends StatelessWidget {
  const _ProcessingPaper();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 240,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: _PaperLine(100, color: AppColors.teal)),
            ],
          ),
          const SizedBox(height: 32),
          const _PaperLine(120, color: AppColors.line),
          const SizedBox(height: 16),
          const _PaperLine(90, color: AppColors.line),
          const SizedBox(height: 16),
          const _PaperLine(140, color: AppColors.line),
          const SizedBox(height: 16),
          const _PaperLine(80, color: AppColors.line),
        ],
      ),
    );
  }
}

