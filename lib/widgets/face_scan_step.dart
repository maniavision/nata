import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/face_verification_service.dart';
import '../services/liveness.dart';

/// Identity verification, step 2: a live selfie matched with the ID photo.
///
/// 1. Liveness: the front camera streams frames to the native face detector
///    while the user blinks and turns their head (random order).
/// 2. A selfie is taken once they look straight at the camera, uploaded, and
///    the `verify-identity` edge function compares it with the ID photo.
/// 3. A match verifies the user. Otherwise they can retry until the server
///    runs out of attempts, after which the ID goes to manual review.
class FaceScanStep extends StatefulWidget {
  final FaceVerificationService service;
  final VoidCallback onBack;

  /// Called when the step is over: verified, or sent to manual review.
  final VoidCallback onDone;

  /// Lists the device's cameras; tests replace it.
  final Future<List<CameraDescription>> Function() cameras;

  const FaceScanStep({
    super.key,
    required this.service,
    required this.onBack,
    required this.onDone,
    this.cameras = availableCameras,
  });

  @override
  State<FaceScanStep> createState() => _FaceScanStepState();
}

enum _Phase { intro, starting, scanning, verifying, result }

class _FaceScanStepState extends State<FaceScanStep> {
  /// The liveness check gives up after this long.
  static const _timeLimit = Duration(seconds: 60);

  /// Analysing every frame is wasted work: a few per second is plenty.
  static const _frameInterval = Duration(milliseconds: 150);

  _Phase _phase = _Phase.intro;
  CameraController? _camera;
  LivenessSession _session = LivenessSession();
  Timer? _timeout;
  bool _analysing = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  /// The outcome to show in the result phase.
  FaceMatchResult? _result;

  /// An error message instead of a result (camera denied, timeout...).
  String Function(AppLocalizations)? _error;

  @override
  void dispose() {
    _timeout?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.starting;
      _error = null;
      _result = null;
      _session = LivenessSession();
    });
    try {
      final cameras = await widget.cameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      _camera = camera;
      setState(() => _phase = _Phase.scanning);
      _timeout = Timer(_timeLimit, () => _fail((l) => l.faceScanTimeout));
      await camera.startImageStream(_onFrame);
    } on CameraException catch (e) {
      debugPrint('[FaceScan] camera error: ${e.code} ${e.description}');
      final denied =
          e.code.contains('AccessDenied') || e.code.contains('Restricted');
      _fail(denied ? (l) => l.faceScanCameraDenied : (l) => l.faceScanError);
    } catch (e) {
      debugPrint('[FaceScan] camera error: $e');
      _fail((l) => l.faceScanError);
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final camera = _camera;
    final now = DateTime.now();
    if (_analysing ||
        camera == null ||
        _phase != _Phase.scanning ||
        now.difference(_lastFrame) < _frameInterval) {
      return;
    }
    _analysing = true;
    _lastFrame = now;
    try {
      final frame = await widget.service.analyzeFrame(
        image,
        camera.description.sensorOrientation,
      );
      if (frame == null || !mounted || _phase != _Phase.scanning) return;
      final before = _session.prompt;
      final prompt = _session.add(frame);
      if (prompt != before) setState(() {});
      if (_session.isDone) await _captureAndVerify();
    } finally {
      _analysing = false;
    }
  }

  Future<void> _captureAndVerify() async {
    final camera = _camera!;
    _timeout?.cancel();
    setState(() => _phase = _Phase.verifying);
    try {
      await camera.stopImageStream();
      final photo = await camera.takePicture();
      await _closeCamera();
      final jpeg = await widget.service.selfieJpeg(photo.path);
      if (jpeg == null) throw StateError('Selfie could not be encoded');
      await widget.service.uploadSelfie(jpeg);
      final result = await widget.service.verify();
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = _Phase.result;
      });
    } catch (e) {
      debugPrint('[FaceScan] verify error: $e');
      _fail((l) => l.faceScanError);
    }
  }

  Future<void> _closeCamera() async {
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } catch (_) {}
    await camera.dispose();
  }

  void _fail(String Function(AppLocalizations) message) {
    _timeout?.cancel();
    _closeCamera();
    if (!mounted) return;
    setState(() {
      _error = message;
      _phase = _Phase.result;
    });
  }

  String _promptText(AppLocalizations l) => switch (_session.prompt) {
    LivenessPrompt.noFace => l.livenessNoFace,
    LivenessPrompt.multipleFaces => l.livenessMultipleFaces,
    LivenessPrompt.blink => l.livenessBlink,
    LivenessPrompt.turnHead => l.livenessTurnHead,
    LivenessPrompt.lookStraight ||
    LivenessPrompt.done => l.livenessLookStraight,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        _header(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Text(
                  l.faceScanTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.faceScanBody,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 20),
                _viewfinder(),
                const SizedBox(height: 16),
                _status(l),
              ],
            ),
          ),
        ),
        _footer(l),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('face-scan-back'),
            onTap: _phase == _Phase.verifying ? null : widget.onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The oval the user puts their face in: the live camera while scanning,
  /// an icon otherwise.
  Widget _viewfinder() {
    final camera = _camera;
    final live =
        _phase == _Phase.scanning &&
        camera != null &&
        camera.value.isInitialized;
    final done = _session.completed;
    final borderColor =
        _phase == _Phase.result && _result?.verdict == FaceMatchVerdict.match
        ? const Color(0xFF168A68)
        : live &&
              _session.prompt != LivenessPrompt.noFace &&
              _session.prompt != LivenessPrompt.multipleFaces
        ? const Color(0xFF168A68)
        : AppColors.border;
    return Column(
      children: [
        Container(
          width: 230,
          height: 300,
          decoration: ShapeDecoration(
            shape: OvalBorder(side: BorderSide(color: borderColor, width: 4)),
            color: AppColors.muted,
          ),
          child: ClipOval(
            child: live
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      // The preview size is landscape; the oval is portrait.
                      width: camera.value.previewSize!.height,
                      height: camera.value.previewSize!.width,
                      child: CameraPreview(camera),
                    ),
                  )
                : Center(
                    child:
                        _phase == _Phase.starting || _phase == _Phase.verifying
                        ? const CircularProgressIndicator(
                            color: AppColors.accent,
                            strokeWidth: 2.5,
                          )
                        : Icon(
                            _result?.verdict == FaceMatchVerdict.match
                                ? Icons.verified_rounded
                                : Icons.face_retouching_natural_rounded,
                            size: 72,
                            color: _result?.verdict == FaceMatchVerdict.match
                                ? const Color(0xFF168A68)
                                : AppColors.mutedForeground,
                          ),
                  ),
          ),
        ),
        if (live) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _session.challenges.length; i++)
                Container(
                  width: 28,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i < done
                        ? const Color(0xFF168A68)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _status(AppLocalizations l) {
    final String text;
    Color color = AppColors.foreground;
    switch (_phase) {
      case _Phase.intro:
        text = l.faceScanIntro;
        color = AppColors.mutedForeground;
      case _Phase.starting:
        text = '';
      case _Phase.scanning:
        text = _promptText(l);
      case _Phase.verifying:
        text = l.faceScanVerifying;
        color = AppColors.mutedForeground;
      case _Phase.result:
        final error = _error;
        final result = _result;
        if (error != null) {
          text = error(l);
          color = AppColors.destructive;
        } else {
          switch (result!.verdict) {
            case FaceMatchVerdict.match:
              text = l.faceScanVerified;
              color = const Color(0xFF168A68);
            case FaceMatchVerdict.noMatch:
              text = l.faceScanNoMatch(result.attemptsLeft);
              color = AppColors.destructive;
            case FaceMatchVerdict.noFace:
              text = l.faceScanNoFace(result.attemptsLeft);
              color = AppColors.destructive;
            case FaceMatchVerdict.manualReview:
              text = l.faceScanManualReview;
              color = AppColors.mutedForeground;
          }
        }
    }
    return Text(
      text,
      key: const ValueKey('face-scan-status'),
      textAlign: TextAlign.center,
      style: GoogleFonts.dmSans(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: color,
      ),
    );
  }

  Widget _footer(AppLocalizations l) {
    final verdict = _result?.verdict;
    final finished =
        verdict == FaceMatchVerdict.match ||
        verdict == FaceMatchVerdict.manualReview;
    final String? label = switch (_phase) {
      _Phase.intro => l.startBiometricScan,
      _Phase.result => finished ? l.faceScanContinue : l.faceScanTryAgain,
      _ => null,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              key: const ValueKey('face-scan-action'),
              onPressed: label == null
                  ? null
                  : finished
                  ? widget.onDone
                  : _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.muted,
                shape: const StadiumBorder(),
              ),
              child: Text(
                label ?? '',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (_phase == _Phase.result && !finished)
            TextButton(
              key: const ValueKey('face-scan-skip'),
              // The verification stays pending: a person reviews the ID.
              onPressed: widget.onDone,
              child: Text(
                l.faceScanSkip,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
          Text(
            l.biometricLocalNote,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
