import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../models/document_verification_config.dart';
import '../../widgets/common/back_button.dart';
import 'review_and_submit_view.dart';

class LivenessCheckView extends StatefulWidget {
  final DocumentVerificationConfig config;

  const LivenessCheckView({super.key, required this.config});

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

  @override
  void initState() {
    super.initState();
    _gestures = DocumentVerificationConfig.generateRandomGestures();
    _initializeCamera();
    _initializeFaceDetector();
  }

  void _initializeFaceDetector() {
    if (kIsWeb) return;
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
      await Future.delayed(const Duration(seconds: 2));
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

    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      var rotationCompensation =
          _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (defaultTargetPlatform == TargetPlatform.android &&
            format != InputImageFormat.nv21) ||
        (defaultTargetPlatform == TargetPlatform.iOS &&
            format != InputImageFormat.bgra8888))
      return null;

    // Since we're streaming images, we need to concatenate the planes
    if (image.planes.length != 1) return null;
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

  static final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  void _checkGesture(Face face) {
    if (_currentGestureIndex >= _gestures.length) return;

    final targetGesture = _gestures[_currentGestureIndex];
    bool gestureDetected = false;

    // TODO: Add platform specific depth camera API integration here for better anti-spoofing

    switch (targetGesture) {
      case LivenessGesture.smile:
        if ((face.smilingProbability ?? 0) > 0.8) gestureDetected = true;
        break;
      case LivenessGesture.turnHeadLeft:
        if ((face.headEulerAngleY ?? 0) > 45) gestureDetected = true;
        break;
      case LivenessGesture.turnHeadRight:
        if ((face.headEulerAngleY ?? 0) < -45) gestureDetected = true;
        break;
      case LivenessGesture.lookUp:
        if ((face.headEulerAngleX ?? 0) > 20) gestureDetected = true;
        break;
      case LivenessGesture.lookDown:
        if ((face.headEulerAngleX ?? 0) < -20) gestureDetected = true;
        break;
    }

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
      MaterialPageRoute(builder: (context) => const ReviewAndSubmitView()),
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
    if (_controller == null || !_controller!.value.isInitialized) {
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
            child: CameraPreview(_controller!),
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
