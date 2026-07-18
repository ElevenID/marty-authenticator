import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import '../../models/document_verification_config.dart';
import '../../widgets/common/back_button.dart';
import 'liveness_check_view.dart';

Future<List<CameraDescription>> _availableDocumentCameras() =>
    availableCameras();
Future<void> _documentDelay(Duration duration) => Future.delayed(duration);

class DocumentScanningView extends StatefulWidget {
  final DocumentVerificationConfig config;
  final int currentStepIndex;
  final Widget? cameraPreviewOverride;
  final Duration processingDelay;
  final Duration cameraReleaseDelay;
  final Widget Function(DocumentVerificationConfig config)? livenessBuilder;
  final Widget Function(DocumentVerificationConfig config, int stepIndex)?
  scanningBuilder;
  final Future<List<CameraDescription>> Function() cameraProvider;
  final Future<void> Function(Duration duration) delay;

  const DocumentScanningView({
    super.key,
    required this.config,
    this.currentStepIndex = 0,
    this.cameraPreviewOverride,
    this.processingDelay = const Duration(seconds: 1),
    this.cameraReleaseDelay = const Duration(milliseconds: 500),
    this.livenessBuilder,
    this.scanningBuilder,
    this.cameraProvider = _availableDocumentCameras,
    this.delay = _documentDelay,
  });

  @override
  State<DocumentScanningView> createState() => _DocumentScanningViewState();
}

class _DocumentScanningViewState extends State<DocumentScanningView> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isScanning = false;
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameraPreviewOverride != null) {
      if (mounted) setState(() => _cameraReady = true);
      return;
    }
    final cameras = await widget.cameraProvider();
    if (cameras.isEmpty) return;

    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!.initialize();
    if (mounted) {
      setState(() => _cameraReady = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.config.steps[widget.currentStepIndex];
    String instruction = '';
    if (step == VerificationStep.scanFront) {
      instruction = 'Scan Front of Document';
    } else if (step == VerificationStep.scanBack) {
      instruction = 'Scan Back of Document';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leadingWidth: 100,
        leading: const CustomBackButton(),
        title: const Text(
          'Scan Document',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (_cameraReady &&
              (widget.cameraPreviewOverride != null ||
                  (snapshot.connectionState == ConnectionState.done &&
                      _controller != null &&
                      _controller!.value.isInitialized))) {
            return Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child:
                      widget.cameraPreviewOverride ??
                      CameraPreview(_controller!),
                ),
                _buildOverlay(instruction),
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: _isScanning ? null : _takePicture,
                      backgroundColor: Colors.white,
                      child: _isScanning
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Icon(Icons.camera_alt, color: Colors.black),
                    ),
                  ),
                ),
                if (_isScanning)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Processing Document...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildOverlay(String instruction) {
    return Stack(
      children: [
        // Semi-transparent background with cutout
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.width * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Instruction text
        Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: Text(
            instruction,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _takePicture() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      await _initializeControllerFuture;

      // Mocking the "crispness check", "edge detection", "OCR", etc.
      // In the future:
      // 1. Detect edges and square the document
      // 2. Check for crispness/blur
      // 3. Check for watermarks
      // 4. OCR text

      // Simulate processing delay
      await widget.delay(widget.processingDelay);

      // We need to dispose the controller before navigating to the next step
      // because on many devices we can't have multiple active camera sessions.
      await _controller?.dispose();
      _controller = null;

      // Give the OS time to release the camera resource
      await widget.delay(widget.cameraReleaseDelay);

      if (!mounted) return;

      // Navigate to next step
      final nextIndex = widget.currentStepIndex + 1;
      if (nextIndex < widget.config.steps.length) {
        final nextStep = widget.config.steps[nextIndex];
        if (nextStep == VerificationStep.liveness) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  widget.livenessBuilder?.call(widget.config) ??
                  LivenessCheckView(config: widget.config),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  widget.scanningBuilder?.call(widget.config, nextIndex) ??
                  DocumentScanningView(
                    config: widget.config,
                    currentStepIndex: nextIndex,
                  ),
            ),
          );
        }

        // Re-initialize camera when returning to this view
        if (mounted) {
          _initializeCamera();
          setState(() => _isScanning = false);
        }
      } else {
        // A custom flow may end after a scan without a liveness step.
        if (mounted) setState(() => _isScanning = false);
      }
    } catch (e) {
      Logger.error(e.toString());
      if (mounted) {
        setState(() => _isScanning = false);
        _initializeCamera(); // Try to recover
      }
    }
  }
}
