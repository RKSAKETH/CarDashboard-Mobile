import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ─── Fatigue Detection Service ────────────────────────────────────────────────
//
//  Uses the front-facing camera + ML Kit Face Detection to monitor:
//    • Both-eyes-open probability (threshold < 0.20 → eyes closed)
//    • Look-away head angle (|headEulerAngleY| > 30° → looking away)
//
//  If either condition persists for > 2 seconds → trigger alarm:
//    • Aggressive vibration (on devices that support it)
//    • TTS alert: "STAY FOCUSED!"
//
class FatigueDetectionService {
  // ── Config ─────────────────────────────────────────────────────────────────
  static const double _eyeOpenThreshold = 0.20;
  static const double _lookAwayAngle    = 30.0; // degrees
  static const int    _triggerMs        = 2000;  // 2 s
  static const int    _cooldownMs       = 4000;  // 4 s between alerts

  // ── State ──────────────────────────────────────────────────────────────────
  CameraController?  _cameraController;
  FaceDetector?      _detector;
  FlutterTts?        _tts;

  bool _isRunning   = false;
  bool _isAnalysing = false;

  DateTime? _fatigueStart;   // when the current fatigue event started
  DateTime? _lastAlarm;      // when the last alarm fired
  bool      _alarmActive = false;

  // ── Public callbacks ───────────────────────────────────────────────────────
  /// Called whenever the fatigue state changes (true = fatigued, false = ok)
  ValueChanged<bool>? onFatigueChanged;

  /// Called once when the 2-s threshold is crossed
  VoidCallback? onAlarmTriggered;

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isRunning   => _isRunning;
  bool get alarmActive => _alarmActive;
  CameraController? get cameraController => _cameraController;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<bool> init() async {
    try {
      // Initialise TTS
      _tts = FlutterTts();
      await _tts!.setLanguage('en-US');
      await _tts!.setSpeechRate(0.55);
      await _tts!.setVolume(1.0);

      // Grab front camera
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        front,
        ResolutionPreset.low,     // 240 p – low latency, low CPU
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,  // best for MLKit on Android
      );

      await _cameraController!.initialize();

      // Initialise ML Kit face detector
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,   // needed for eye-open probability
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('[FatigueDetection] init error: $e');
      return false;
    }
  }

  // ── Start / Stop ───────────────────────────────────────────────────────────
  Future<void> start() async {
    if (_isRunning || _cameraController == null) return;
    _isRunning   = true;
    _fatigueStart = null;
    _alarmActive  = false;

    await _cameraController!.startImageStream(_onFrame);
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    try {
      await _cameraController!.stopImageStream();
    } catch (_) {}
    _fatigueStart = null;
    _alarmActive  = false;
    onFatigueChanged?.call(false);
  }

  // ── Frame processing ───────────────────────────────────────────────────────
  Future<void> _onFrame(CameraImage image) async {
    if (_isAnalysing || !_isRunning || _detector == null) return;
    _isAnalysing = true;

    try {
      final inputImage = _cameraImageToInputImage(image);
      if (inputImage == null) return;

      final faces = await _detector!.processImage(inputImage);
      _evaluate(faces);
    } catch (e) {
      debugPrint('[FatigueDetection] frame error: $e');
    } finally {
      _isAnalysing = false;
    }
  }

  void _evaluate(List<Face> faces) {
    // No face detected = alert as well (looking away from camera)
    bool isFatigued = false;

    if (faces.isEmpty) {
      isFatigued = true; // no face in frame
    } else {
      final face = faces.first;

      // 1. Eye-open probability
      final leftEye  = face.leftEyeOpenProbability  ?? 1.0;
      final rightEye = face.rightEyeOpenProbability ?? 1.0;
      final eyesClosed = (leftEye < _eyeOpenThreshold) &&
                         (rightEye < _eyeOpenThreshold);

      // 2. Head turn angle (Y axis = yaw)
      final yaw = (face.headEulerAngleY ?? 0.0).abs();
      final lookingAway = yaw > _lookAwayAngle;

      isFatigued = eyesClosed || lookingAway;
    }

    _updateFatigueState(isFatigued);
  }

  void _updateFatigueState(bool isFatigued) {
    if (isFatigued) {
      _fatigueStart ??= DateTime.now();
      final elapsed = DateTime.now().difference(_fatigueStart!).inMilliseconds;

      if (elapsed >= _triggerMs) {
        final cooldown = _lastAlarm == null ||
            DateTime.now().difference(_lastAlarm!).inMilliseconds > _cooldownMs;

        if (cooldown) {
          _triggerAlarm();
        }
        if (!_alarmActive) {
          _alarmActive = true;
          onFatigueChanged?.call(true);
        }
      }
    } else {
      // Driver is attentive again
      final wasActive = _alarmActive;
      _fatigueStart = null;
      _alarmActive  = false;
      if (wasActive) onFatigueChanged?.call(false);
    }
  }

  // ── Alarm ──────────────────────────────────────────────────────────────────
  Future<void> _triggerAlarm() async {
    _lastAlarm = DateTime.now();
    onAlarmTriggered?.call();

    // Vibrate aggressively
    final canVibrate = (await Vibration.hasVibrator()) == true;
    if (canVibrate) {
      Vibration.vibrate(
        pattern: [0, 500, 100, 500, 100, 800],
        intensities: [0, 255, 0, 255, 0, 255],
      );
    }

    // TTS alert
    await _tts?.speak('STAY FOCUSED!');
  }

  // ── MLKit InputImage conversion ────────────────────────────────────────────
  InputImage? _cameraImageToInputImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) return null;

    final camera        = controller.description;
    final rotation      = _sensorOrientationToRotation(camera.sensorOrientation);
    final format        = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation _sensorOrientationToRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation0deg;
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    await stop();
    await _detector?.close();
    await _cameraController?.dispose();
    _detector          = null;
    _cameraController  = null;
  }
}
