import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:admin_api_key_manager/admin_api_key_manager.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:prescription_scanner/legal/legal_copy.dart';
import 'package:prescription_scanner/services/analytics_service.dart';
import 'package:prescription_scanner/services/consent_store.dart';
import 'package:prescription_scanner/services/gemini_vision_service.dart';
import 'package:prescription_scanner/services/prescription_repository.dart';
import 'package:prescription_scanner/services/prescription_upload_service.dart';
import 'package:prescription_scanner/services/result_store.dart';
import 'package:prescription_scanner/theme.dart';
import 'package:prescription_scanner/widgets/ui_animations.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  PreparedPrescription? draft;
  late final PrescriptionUploadService _uploadService;
  bool preparing = false;
  bool scanning = false;
  bool checkingConsent = false;
  bool aiConsentGranted = false;
  String? error;

  bool get busy => preparing || scanning || checkingConsent;
  bool get _showProgressOverlay => preparing || scanning;
  bool get _canScan => !busy && aiConsentGranted;
  String get _progressTitle => preparing ? 'Preparing image…' : 'Scanning with AI…';
  String get _progressMessage => preparing
      ? 'Creating a clear, optimized local copy before AI transcription.'
      : 'Sending the prepared image to Google Gemini for transcription.';

  @override
  void initState() {
    super.initState();
    _uploadService = ref.read(prescriptionUploadServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      recoverInterruptedPick();
      unawaited(_warmUpScanDependencies());
      unawaited(_ensureAiConsentBeforeScan());
    });
  }

  @override
  void dispose() {
    final currentDraft = draft;
    if (currentDraft != null) {
      unawaited(_uploadService.deleteLocalDraft(currentDraft));
    }
    super.dispose();
  }

  Future<void> recoverInterruptedPick() async {
    final service = ref.read(prescriptionUploadServiceProvider);
    if (busy) return;
    try {
      final recovered = await service.recoverInterruptedPick();
      if (recovered != null && mounted) setState(() => draft = recovered);
    } on ScanValidationException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  String get _ownerUid => fb.FirebaseAuth.instance.currentUser?.uid ?? guestOwnerUid;

  Future<void> _warmUpScanDependencies() async {
    try {
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.reload();
        final refreshedUser = fb.FirebaseAuth.instance.currentUser;
        if (refreshedUser?.emailVerified == true) {
          await refreshedUser!.getIdToken(true);
        }
      }
      final ownerUid = fb.FirebaseAuth.instance.currentUser?.uid ?? guestOwnerUid;
      unawaited(ref.read(prescriptionRepositoryProvider).loadQuota(ownerUid));
      ApiKeyManager.instance.initialize();
      unawaited(ApiKeyManager.instance.ensureReady());
    } catch (exception) {
      debugPrint('[scan] Warm-up skipped: $exception');
    }
  }

  Future<bool> _ensureAiConsentBeforeScan({bool showError = false}) async {
    if (checkingConsent) return aiConsentGranted;
    setState(() => checkingConsent = true);
    try {
      final ownerUid = _ownerUid;
      final hasConsent = await ConsentStore.hasAiConsent(ownerUid);
      if (hasConsent) {
        if (mounted) setState(() => aiConsentGranted = true);
        return true;
      }
      if (!mounted) return false;
      final accepted = await _showAiConsentDialog();
      if (accepted != true) {
        if (mounted && showError) {
          setState(
            () => error =
                'Please allow AI transcription consent before scanning an image.',
          );
        }
        return false;
      }
      await ConsentStore.grantAiConsent(ownerUid);
      if (mounted) {
        setState(() {
          aiConsentGranted = true;
          error = null;
        });
      }
      return true;
    } finally {
      if (mounted) setState(() => checkingConsent = false);
    }
  }

  Future<bool?> _showAiConsentDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.shield_outlined, color: AppColors.teal),
        title: const Text('AI processing consent'),
        content: SingleChildScrollView(
          child: Text(
            '${LegalCopy.medicalFull}\n\n${LegalCopy.privacySummary}',
          ),
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
  }

  Future<bool> _confirmCameraPermission() async {
    final allowed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.photo_camera_outlined, color: AppColors.teal),
        title: const Text(LegalCopy.cameraRationaleTitle),
        content: const Text(LegalCopy.cameraRationale),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Allow camera'),
          ),
        ],
      ),
    );
    return allowed == true;
  }

  Future<void> selectImage(ImageSource source) async {
    final consentReady =
        aiConsentGranted || await _ensureAiConsentBeforeScan(showError: true);
    if (!consentReady || !mounted) return;
    if (source == ImageSource.camera) {
      final cameraOk = await _confirmCameraPermission();
      if (!cameraOk || !mounted) return;
    }

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
      // Start AI extraction immediately on selection so the direct Gemini API
      // call begins without a second tap. The explicit retry button stays
      // available if processing fails.
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
    if (selected == null) return;

    setState(() {
      scanning = true;
      error = null;
    });
    try {
      // Anonymous guests are allowed a small number of free scans per day;
      // signed-in users keep the (larger) account allowance. Guests still
      // verify email only after creating an account.
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      final ownerUid = currentUser?.uid ?? guestOwnerUid;
      unawaited(AnalyticsService.logScanStarted(guest: currentUser == null));
      if (currentUser != null) {
        await currentUser.reload();
        final refreshedUser = fb.FirebaseAuth.instance.currentUser;
        if (refreshedUser == null || !refreshedUser.emailVerified) {
          throw const VisionException(
            'Verify your email, then sign out and sign in again before scanning.',
            statusCode: 403,
          );
        }
        // Refresh the ID token so Firestore receives the latest email_verified
        // claim immediately after the user clicks the verification link.
        await refreshedUser.getIdToken(true);
      }

      final repository = ref.read(prescriptionRepositoryProvider);
      final quota = await repository.loadQuota(ownerUid);
      if (quota.maintenanceMode || !quota.aiEnabled) {
        throw const VisionException(
          'AI scanning is temporarily unavailable. Please try again later.',
          statusCode: 503,
        );
      }
      if (quota.remaining <= 0) {
        if (quota.isGuest && mounted) {
          // Free guest scan used up: invite the user to sign in for more.
          final signIn = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              icon: const Icon(Icons.lock_open_rounded, color: AppColors.teal),
              title: const Text('Free scan used up'),
              content: const Text(
                'You have used your free scan for today. Sign in to unlock 2 more free scans.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          );
          if (signIn == true) {
            if (mounted) context.go('/login');
            return;
          }
          if (mounted) setState(() => scanning = false);
          return;
        }
        throw const VisionException(
          'You have used today’s scan limit. Please try again tomorrow.',
          statusCode: 429,
        );
      }

      final consentReady =
          aiConsentGranted || await _ensureAiConsentBeforeScan(showError: true);
      if (!consentReady) return;

      // Supabase-free path: send the local image straight to Gemini.
      final localId = const Uuid().v4();
      final result = await vision.processImage(selected.path, localId: localId);
      await ResultStore.instance.save(ownerUid, result);
      unawaited(AnalyticsService.logScanSucceeded(guest: currentUser == null));

      // Record quota/usage (Firestore for signed-in users, local Hive for
      // guests). A metrics failure must not discard a successful result.
      try {
        await repository.recordSuccessfulScan(ownerUid: ownerUid);
      } catch (exception) {
        debugPrint('[scan] Could not record per-user usage: $exception');
      }
      ref.invalidate(quotaProvider);
      ref.invalidate(recentPrescriptionsProvider);
      ref.invalidate(prescriptionHistoryProvider);

      // Clean up the local draft file now that it has been processed.
      await service.deleteLocalDraft(selected);
      draft = null;
      if (!mounted) return;
      context.go(
        '/processing?prescriptionId=${Uri.encodeComponent(result.id)}',
      );
    } on VisionException catch (exception) {
      unawaited(
        AnalyticsService.logScanFailed(reason: exception.statusCode.toString()),
      );
      if (mounted) setState(() => error = exception.message);
    } on FirebaseException catch (exception, stackTrace) {
      debugPrint('[scan] Firebase ${exception.code}: ${exception.message}');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        final message = exception.code == 'permission-denied'
            ? 'Firebase access was denied. Verify your email, sign out and sign in again, then retry.'
            : 'Firebase could not load your scan settings (${exception.code}). Please retry.';
        setState(() => error = message);
      }
    } catch (exception, stackTrace) {
      debugPrint('[scan] Unexpected failure: $exception');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(
          () => error = 'The scan could not be completed. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => scanning = false);
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
      body: Stack(
        children: [
          ListView(
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
                  'Preparing image…',
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
                  icon: scanning
                      ? const SizedBox.square(
                          dimension: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    scanning ? 'Scanning with AI…' : 'Retry scan',
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
                        LegalCopy.medicalShort,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 10),
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
          if (_showProgressOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          _progressTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _progressMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

class _EmptyScanFrame extends StatefulWidget {
  const _EmptyScanFrame({super.key});

  @override
  State<_EmptyScanFrame> createState() => _EmptyScanFrameState();
}

class _EmptyScanFrameState extends State<_EmptyScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beam;

  @override
  void initState() {
    super.initState();
    _beam = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..repeat();
  }

  @override
  void dispose() {
    _beam.dispose();
    super.dispose();
  }

  static const double _previewHeight = 320;
  static const double _animationViewportHeight = 132;
  static const double _contentHeight = 224;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('empty-scan-preview'),
      height: _previewHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0FBF9), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFFA8C4C0)),
        ),
        child: Center(
          child: SizedBox(
            height: _contentHeight,
            width: double.infinity,
            child: Column(
              children: [
                // Ripple growth is paint-only and clipped inside this fixed
                // viewport. It cannot resize this Column or reach the copy.
                SizedBox(
                  key: const ValueKey('scan-animation-viewport'),
                  height: _animationViewportHeight,
                  width: double.infinity,
                  child: ClipRect(
                    child: RepaintBoundary(
                      child: Center(
                        child: PulseRing(
                          color: AppColors.tealBright,
                          pulses: 1,
                          child: _BeamPaper(beam: _beam),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  key: ValueKey('scan-preview-title'),
                  height: 24,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Place the full prescription in frame',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(
                  key: ValueKey('scan-preview-subtitle'),
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Center(
                      child: Text(
                        'Use bright, even light and keep every corner visible.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BeamPaper extends StatelessWidget {
  const _BeamPaper({required this.beam});
  final Animation<double> beam;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: beam,
      builder: (context, _) => Container(
        key: const ValueKey('scan-document'),
        width: 80,
        height: 104,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              const Column(
                children: [
                  _PaperLine(30, color: Color(0xFF8ED0C6)),
                  SizedBox(height: 6),
                  _PaperLine(48),
                  SizedBox(height: 6),
                  _PaperLine(38),
                  SizedBox(height: 6),
                  _PaperLine(46),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                top: -3 + beam.value * (78 - 3),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.9),
                        blurRadius: 10,
                        spreadRadius: 2,
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
      final ownerUid =
          fb.FirebaseAuth.instance.currentUser?.uid ?? guestOwnerUid;
      final result = ResultStore.instance.get(ownerUid, widget.prescriptionId);
      if (result == null) {
        if (mounted) {
          setState(
            () => error = 'The result could not be found. Please scan again.',
          );
        }
        return;
      }
      if (!mounted) return;
      context.go('/result?prescriptionId=${Uri.encodeComponent(result.id)}');
    } catch (_) {
      if (mounted) {
        setState(() => error = 'The result could not be loaded. Please retry.');
      }
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
                            Entrance(
                              child: SizedBox(
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
                                    _OrbitingDots(animation: controller),

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
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < 3; i++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      right: i == 2 ? 0 : 8,
                                    ),
                                    child: AnimatedBuilder(
                                      animation: controller,
                                      builder: (context, _) => Opacity(
                                        opacity:
                                            (controller.value - i / 3 + 1) %
                                            1.0,
                                        child: const Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: AppColors.teal,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                Text(
                                  'KeshabStudios AI is structuring...',
                                  style: TextStyle(
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
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

class _OrbitingDots extends StatelessWidget {
  const _OrbitingDots({required this.animation});
  final Animation<double> animation;

  static const double _radius = 128;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value * 2 * math.pi;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: _radius * math.cos(t + i * 2 * math.pi / 3) - 4,
                top: _radius * math.sin(t + i * 2 * math.pi / 3) - 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.indigo.withValues(alpha: 0.55),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
