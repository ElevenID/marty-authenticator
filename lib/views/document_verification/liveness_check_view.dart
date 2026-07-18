import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../models/document_verification_config.dart';
import '../../models/liveness_challenge.dart';
import '../../models/liveness_gesture_detector.dart';
import '../../services/liveness_camera_image_converter.dart';
import '../../widgets/common/back_button.dart';
import 'review_and_submit_view.dart';

class LivenessCheckView extends StatefulWidget {
  final DocumentVerificationConfig config;
  final List<LivenessGesture>? gesturesOverride;
  final Widget? cameraPreviewOverride;
  final Duration mockGestureDelay;
  final Widget Function(LivenessChallenge? challenge)? reviewBuilder;
  final bool enableExpiryTicker;
  final Duration challengeTtl;

  const LivenessCheckView({
    super.key,
    required this.config,
    this.gesturesOverride,
    this.cameraPreviewOverride,
    this.mockGestureDelay = const Duration(seconds: 2),
    this.reviewBuilder,
    this.enableExpiryTicker = true,
    this.challengeTtl = const Duration(seconds: 60),
  });

  @override
  State<LivenessCheckView> createState() => _LivenessCheckViewState();
}

class _LivenessCheckViewState extends State<LivenessCheckView> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _isBusy = false;
  List<LivenessGesture> _gestures = [];
  int _currentGestureIndex = 0;
  String _feedback = '';
  LivenessChallenge? _challenge;
  int _expirySeconds = 0;

  @override
  void initState() {
    super.initState();
    _gestures =
        widget.gesturesOverride ??
        DocumentVerificationConfig.generateRandomGestures();
    _challenge = LivenessChallenge.create(
      gestures: _gestures,
      ttl: widget.challengeTtl,
      signingSecret: 'local-dev-secret',
    );
    _expirySeconds = widget.challengeTtl.inSeconds;
    if (widget.enableExpiryTicker) _startExpiryTicker();
    _initializeCamera();
    _initializeFaceDetector();
  }

  void _startExpiryTicker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _challenge == null) return false;
      final remaining = _challenge!.expiresAt
          .difference(DateTime.now().toUtc())
          .inSeconds;
      if (remaining <= 0) {
        setState(() => _expirySeconds = 0);
        return false;
      }
      setState(() => _expirySeconds = remaining);
      return true;
    });
  }

  void _initializeFaceDetector() {
    if (kIsWeb || widget.cameraPreviewOverride != null) return;
    final options = FaceDetectorOptions(
      enableClassification: true, // for smile and eyes
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _initializeCamera() async {
    try {
      if (widget.cameraPreviewOverride != null) {
        if (mounted) {
          setState(() {});
          _startWebMock();
        }
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      if (kIsWeb) {
        _startWebMock();
      } else {
        _controller!.startImageStream(_processImage);
      }
      setState(() {});
    } catch (e) {
      Logger.error('Error initializing liveness camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start camera: $e')));
      }
    }
  }

  void _startWebMock() async {
    while (mounted && _currentGestureIndex < _gestures.length) {
      await Future.delayed(widget.mockGestureDelay);
      if (!mounted) return;
      setState(() {
        _currentGestureIndex++;
        if (_currentGestureIndex >= _gestures.length) {
          _feedback = 'Verification Complete!';
          _finishVerification();
        } else {
          _feedback = 'Good! (Mocked)';
        }
      });
    }
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    try {
      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isNotEmpty) {
        _checkGesture(faces.first);
      }
    } catch (e) {
      Logger.error(e.toString());
    }

    _isBusy = false;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (kIsWeb) return null;
    if (_controller == null) return null;

    return LivenessCameraImageConverter.convert(
      image: image,
      camera: _controller!.description,
      deviceOrientation: _controller!.value.deviceOrientation,
      platform: defaultTargetPlatform,
    );
  }

  void _checkGesture(Face face) {
    if (_currentGestureIndex >= _gestures.length) return;

    final targetGesture = _gestures[_currentGestureIndex];

    // TODO: Add platform specific depth camera API integration here for better anti-spoofing

    final gestureDetected = LivenessGestureDetector.detects(
      targetGesture,
      smilingProbability: face.smilingProbability,
      headEulerAngleX: face.headEulerAngleX,
      headEulerAngleY: face.headEulerAngleY,
    );

    if (gestureDetected) {
      setState(() {
        _currentGestureIndex++;
        if (_currentGestureIndex >= _gestures.length) {
          _feedback = 'Verification Complete!';
          _finishVerification();
        } else {
          _feedback = 'Good!';
        }
      });
    }
  }

  void _finishVerification() {
    _controller?.stopImageStream();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            widget.reviewBuilder?.call(_challenge) ??
            ReviewAndSubmitView(livenessChallenge: _challenge),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameraPreviewOverride == null &&
        (_controller == null || !_controller!.value.isInitialized)) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leadingWidth: 100,
        leading: const CustomBackButton(),
        title: const Text(
          'Liveness Check',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: widget.cameraPreviewOverride ?? CameraPreview(_controller!),
          ),
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _currentGestureIndex < _gestures.length
                      ? _getGestureInstruction(_gestures[_currentGestureIndex])
                      : 'Verifying...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  _feedback,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 12),
                if (_challenge != null)
                  Text(
                    'Challenge: ${_challenge!.challengeId} · Expires in $_expirySeconds s',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGestureInstruction(LivenessGesture gesture) {
    switch (gesture) {
      case LivenessGesture.smile:
        return 'Smile!';
      case LivenessGesture.turnHeadLeft:
        return 'Turn head Left';
      case LivenessGesture.turnHeadRight:
        return 'Turn head Right';
      case LivenessGesture.lookUp:
        return 'Look Up';
      case LivenessGesture.lookDown:
        return 'Look Down';
    }
  }
}
