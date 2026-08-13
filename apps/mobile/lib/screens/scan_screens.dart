import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prescription_scanner/services/prescription_processing_service.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';
import 'package:prescription_scanner/services/prescription_upload_service.dart';
import 'package:prescription_scanner/theme.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => recoverInterruptedPick());
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
    if (service == null) {
      setState(() => error = 'Supabase configuration is missing.');
      return;
    }
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
    } on ScanValidationException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'The image could not be opened. Please try another one.');
      }
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  Future<void> upload() async {
    final service = ref.read(prescriptionUploadServiceProvider);
    final selected = draft;
    if (service == null || selected == null) return;

    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final hasConsent = await service.hasCurrentAiConsent();
      if (!hasConsent) {
        if (!mounted) return;
        final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.shield_outlined, color: AppColors.teal),
            title: const Text('AI processing consent'),
            content: const Text(
              'Your cropped prescription image will be sent securely to Google Gemini to transcribe visible medicine details. The app will not ask Gemini to diagnose or recommend treatment. The original server image is deleted after a successful result.',
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
        if (accepted != true) return;
        await service.recordAiConsent();
      }

      final uploaded = await service.reserveAndUpload(selected);
      await service.deleteLocalDraft(selected);
      draft = null;
      if (!mounted) return;
      context.push(
        '/processing?prescriptionId=${Uri.encodeComponent(uploaded.prescriptionId)}',
      );
    } on ScanUploadException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'The secure upload could not be started. Please retry.');
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
                  onPressed: busy ? null : () => selectImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => selectImage(ImageSource.gallery),
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
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12),
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
              label: Text(uploading ? 'Uploading securely…' : 'Continue securely'),
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
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
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
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
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
      setState(() => error = 'The prescription ID is missing. Upload the image again.');
      return;
    }
    final service = ref.read(prescriptionProcessingServiceProvider);
    if (service == null) {
      setState(() => error = 'Supabase configuration is missing.');
      return;
    }

    setState(() {
      running = true;
      error = null;
    });
    try {
      final outcome = await service.process(widget.prescriptionId);
      ref.invalidate(quotaProvider);
      ref.invalidate(recentPrescriptionsProvider);
      ref.invalidate(prescriptionHistoryProvider);
      if (!mounted) return;
      context.go(
        '/result?prescriptionId=${Uri.encodeComponent(outcome.prescriptionId)}',
      );
    } on ProcessingException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F8F5), AppColors.canvas],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading prescription',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'You can safely leave this screen',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  width: 190,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 190,
                        height: 190,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0x3320C7AE), Colors.transparent],
                          ),
                        ),
                      ),
                      const _ProcessingPaper(),
                      AnimatedBuilder(
                        animation: controller,
                        builder: (_, __) => Positioned(
                          top: 49 + (112 * controller.value),
                          left: 43,
                          right: 43,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: const Color(0xFF20C7AE),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xAA20C7AE),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                error == null ? 'Finding visible details…' : 'Processing paused',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error == null
                    ? 'Gemini is structuring the prescription. Unclear fields will be marked for your review.'
                    : error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: error == null ? AppColors.muted : AppColors.danger,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      const _Step('Secure upload', 'Private image received', true, true),
                      const _Step('Quality check', 'Image limits validated', true, true),
                      _Step(
                        'Gemini extraction',
                        running ? 'Reading visible medicine details' : 'Waiting to retry',
                        running,
                        false,
                      ),
                      const _Step('Safety validation', 'Schema and confidence checks', false, false),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.muted, size: 16),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'No diagnosis or medicine recommendation is requested',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: running ? null : startProcessing,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try processing again'),
                ),
                TextButton(
                  onPressed: () => context.go('/upload'),
                  child: const Text('Upload a different image'),
                ),
              ],
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
      width: 126,
      height: 166,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x221F5866),
            blurRadius: 35,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: const Column(
        children: [
          _PaperLine(80),
          _PaperLine(60),
          _PaperLine(76),
          _PaperLine(55),
          _PaperLine(72),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.title, this.subtitle, this.active, this.done);
  final String title;
  final String subtitle;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFFE4F7EC)
                  : active
                      ? AppColors.teal
                      : const Color(0xFFE9EEF1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.auto_awesome,
              color: done
                  ? AppColors.success
                  : active
                      ? Colors.white
                      : AppColors.muted,
              size: 17,
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
