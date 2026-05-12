/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/// Enhanced QR scanner widget with SDK-integrated processing
///
/// This widget provides:
/// - Real-time QR code scanning with SDK processing
/// - Intelligent credential matching during scan
/// - Live preview of scan results with privacy assessment
/// - Optimized performance for credential workflows
/// - Hardware-accelerated processing capabilities

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../services/qr_scanner_service_enhanced.dart';
import '../services/spruce_client_extended.dart';
import '../services/spruce_platform_service_extended.dart';
import '../views/credential_selection_view.dart' hide SecurityLevel;
import '../widgets/presentation_request_view.dart';
import '../utils/logger.dart';

/// Enhanced QR scanner widget with SDK integration
class QRScannerEnhanced extends ConsumerStatefulWidget {
  final void Function(ProcessedQRResult result)? onScanResult;
  final bool enableBackgroundProcessing;
  final bool showLivePreview;
  final bool enableHapticFeedback;

  const QRScannerEnhanced({
    super.key,
    this.onScanResult,
    this.enableBackgroundProcessing = true,
    this.showLivePreview = true,
    this.enableHapticFeedback = true,
  });

  @override
  ConsumerState<QRScannerEnhanced> createState() => QRScannerEnhancedState();
}

class QRScannerEnhancedState extends ConsumerState<QRScannerEnhanced>
    with TickerProviderStateMixin {
  // Scanner state
  bool _isScanning = false;
  bool _isProcessing = false;
  String? _lastScannedCode;
  ProcessedQRResult? _currentResult;

  // Performance tracking
  DateTime? _scanStartTime;
  int _totalScans = 0;
  int _successfulScans = 0;

  // Animation controllers
  late AnimationController _processingAnimationController;
  late AnimationController _resultPreviewController;
  late Animation<double> _processingAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _processingAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _resultPreviewController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _processingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _processingAnimationController,
        curve: Curves.linear,
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _resultPreviewController,
            curve: Curves.elasticOut,
          ),
        );
  }

  @override
  void dispose() {
    _processingAnimationController.dispose();
    _resultPreviewController.dispose();
    super.dispose();
  }

  @visibleForTesting
  Future<void> handleScanResult(String scannedData) async {
    if (_isProcessing || scannedData == _lastScannedCode) {
      return; // Avoid duplicate processing
    }

    setState(() {
      _isProcessing = true;
      _lastScannedCode = scannedData;
      _scanStartTime = DateTime.now();
    });

    // Haptic feedback if enabled
    if (widget.enableHapticFeedback) {
      _provideFeedback();
    }

    try {
      _totalScans++;

      // Process QR code with enhanced service
      final qrService = ref.read(qrScannerServiceEnhancedProvider);
      final result = await qrService.processQRCode(scannedData);

      if (result.isSuccess) {
        _successfulScans++;
        await _handleSuccessfulScan(result);
      } else {
        await _handleScanError(result.errorMessage ?? 'Unknown error');
      }
    } catch (e) {
      Logger.error(
        'QR scan processing failed',
        error: e,
        name: 'QRScannerEnhanced',
      );
      await _handleScanError('Failed to process QR code: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleSuccessfulScan(ProcessedQRResult result) async {
    setState(() {
      _currentResult = result;
    });

    // Show live preview if enabled
    if (widget.showLivePreview) {
      await _showLivePreview(result);
    }

    // Call callback if provided
    widget.onScanResult?.call(result);

    // Auto-handle certain types of results
    await _autoHandleResult(result);
  }

  Future<void> _handleScanError(String error) async {
    Logger.warning('QR scan error: $error', name: 'QRScannerEnhanced');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(error)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showLivePreview(ProcessedQRResult result) async {
    await _resultPreviewController.forward();

    // Auto-hide preview after delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _resultPreviewController.reverse();
      }
    });
  }

  Future<void> _autoHandleResult(ProcessedQRResult result) async {
    final enrichedResult = result.enrichedResult;
    if (enrichedResult == null) return;

    final qrType = enrichedResult.validatedResult.parsedData.type;

    // Auto-navigate for presentation requests
    if (qrType == QRType.presentationRequest) {
      await _handlePresentationRequest(enrichedResult);
    }
    // Auto-process credential offers if fully compatible
    else if (qrType == QRType.credentialOffer &&
        _isFullyCompatibleOffer(enrichedResult)) {
      await _handleCredentialOffer(enrichedResult);
    }
  }

  Future<void> _handlePresentationRequest(
    EnrichedQRResult enrichedResult,
  ) async {
    final requestContent =
        enrichedResult.validatedResult.parsedData.parsedContent!;
    final requestUri = enrichedResult.validatedResult.parsedData.rawData;

    try {
      final client = ref.read(spruceIdClientExtendedProvider);

      // Initiate request processing via SDK
      // This will throw UserSelectionRequiredException if matches are found
      await client.initiateOID4VPRequestSDK(presentationRequest: requestUri);

      // If no exception, it means it was auto-approved (shouldn't happen with new flow)
      // or handled without UI
      _showSuccess('Presentation submitted successfully');
    } on UserSelectionRequiredException catch (e) {
      // Show selection UI
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PresentationRequestView(
            requestDetails: e.requestDetails,
            matchingCredentials: e.matches,
            onReject: () => Navigator.of(context).pop(),
            onApprove: (selection) async {
              Navigator.of(context).pop();
              await _completePresentation(
                e.sessionId,
                selection['credentialId'],
                selection['selectedFields'],
              );
            },
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to process presentation request: $e');
    }
  }

  Future<void> _completePresentation(
    String sessionId,
    String credentialId,
    List<String>? fields,
  ) async {
    try {
      final client = ref.read(spruceIdClientExtendedProvider);
      await client.completeOID4VPRequestSDK(
        sessionId: sessionId,
        selectedCredentialId: credentialId,
        selectedFields: fields,
      );
      _showSuccess('Presentation submitted successfully');
    } catch (e) {
      _showError('Failed to submit presentation: $e');
    }
  }

  Future<void> _handleCredentialOffer(EnrichedQRResult enrichedResult) async {
    // Show credential offer acceptance dialog
    final shouldAccept = await showDialog<bool>(
      context: context,
      builder: (context) => _buildCredentialOfferDialog(enrichedResult),
    );

    if (shouldAccept == true) {
      await _acceptCredentialOffer(enrichedResult);
    }
  }

  bool _isFullyCompatibleOffer(EnrichedQRResult enrichedResult) {
    final compatibility = enrichedResult.credentialCompatibility;
    if (compatibility == null) return false;

    return compatibility.every((c) => c.isSupported);
  }

  Future<void> _acceptCredentialOffer(EnrichedQRResult enrichedResult) async {
    try {
      final client = ref.read(spruceIdClientExtendedProvider);
      final offerUri =
          enrichedResult.validatedResult.parsedData.parsedContent?['offer_uri']
              as String? ??
          enrichedResult.validatedResult.parsedData.rawData;

      await client.handleOID4VCOfferSDK(credentialOffer: offerUri);

      _showSuccess('Credential offer accepted successfully');
    } catch (e) {
      _showError('Failed to accept credential offer: $e');
    }
  }

  void _provideFeedback() {
    // Implement haptic feedback based on platform
    if (!kIsWeb) {
      // Use HapticFeedback.lightImpact() or similar
      Logger.info('Providing haptic feedback for scan');
    }
  }

  void _showPresentationSuccess(Map<String, dynamic> presentation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Presentation created successfully'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main scanner interface
        _buildScannerInterface(),

        // Processing overlay
        if (_isProcessing) _buildProcessingOverlay(),

        // Live preview
        if (widget.showLivePreview && _currentResult != null)
          _buildLivePreview(),

        // Performance overlay (debug mode)
        if (kDebugMode) _buildPerformanceOverlay(),
      ],
    );
  }

  Widget _buildScannerInterface() {
    // For web, show image upload interface
    if (kIsWeb) {
      return _buildWebInterface();
    }

    // Check if running in test mode with injected QR code
    const testQrCode = String.fromEnvironment('QR_CODE');
    if (testQrCode.isNotEmpty) {
      return Stack(
        children: [
          Container(color: Colors.black), // Placeholder for camera
          _buildScannerOverlay(),
          const Center(
            child: Text(
              'Test Mode: Camera Disabled',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }

    // For mobile/desktop, use camera scanner
    return Stack(
      children: [
        ReaderWidget(
          onControllerCreated: (controller, _) {
            setState(() => _isScanning = controller != null);
          },
          actionButtonsAlignment: Alignment.bottomRight,
          showFlashlight: Platform.isIOS || Platform.isAndroid,
          flashOnIcon: const Icon(Icons.flash_on, color: Colors.white),
          flashOffIcon: const Icon(Icons.flash_off, color: Colors.white),
          showGallery: true,
          galleryIcon: const Icon(Icons.image, color: Colors.white),
          onScan: (result) => handleScanResult(result.text ?? ''),
        ),
        _buildScannerOverlay(),
      ],
    );
  }

  Widget _buildWebInterface() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 120, color: Colors.white70),
            const SizedBox(height: 32),
            Text(
              'Enhanced QR Scanner',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'SDK-powered credential processing',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _selectImageFromGallery,
              icon: Icon(Icons.upload_file),
              label: Text('Upload QR Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImageFromGallery() async {
    // Implementation would use image picker and process the selected image
    _showError('Image upload not implemented for web demo');
  }

  Widget _buildScannerOverlay() {
    return CustomPaint(
      painter: ScannerOverlayPainter(
        isProcessing: _isProcessing,
        animation: _processingAnimation,
      ),
      size: Size.infinite,
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _processingAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _processingAnimation.value * 2 * 3.14159,
                  child: Icon(
                    Icons.sync,
                    size: 64,
                    color: Colors.blue.withOpacity(0.8),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Processing with SDK...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing credentials and privacy implications',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Colors.blue),
                backgroundColor: Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreview() {
    if (_currentResult?.enrichedResult == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: _buildResultPreview(_currentResult!.enrichedResult!),
        ),
      ),
    );
  }

  Widget _buildResultPreview(EnrichedQRResult result) {
    final qrType = result.validatedResult.parsedData.type;
    final securityLevel = result.validatedResult.securityLevel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_getQRTypeIcon(qrType), color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              _getQRTypeLabel(qrType),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getSecurityColor(securityLevel),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                securityLevel.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (qrType == QRType.presentationRequest) ...[
          Text(
            '${result.matchingCredentials.length} matching credential${result.matchingCredentials.length == 1 ? '' : 's'} found',
            style: const TextStyle(color: Colors.white70),
          ),
          if (result.privacyAnalysis != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.privacy_tip,
                  size: 16,
                  color: _getRiskColor(
                    result.privacyAnalysis!.overallRiskLevel,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Privacy Risk: ${result.privacyAnalysis!.overallRiskLevel.name}',
                  style: TextStyle(
                    color: _getRiskColor(
                      result.privacyAnalysis!.overallRiskLevel,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],

        if (qrType == QRType.credentialOffer) ...[
          Builder(
            builder: (context) {
              final compatibilityResults = result.credentialCompatibility ?? [];
              final supportedCount = compatibilityResults
                  .where((c) => c.isSupported)
                  .length;

              return Text(
                '$supportedCount of ${compatibilityResults.length} credential${compatibilityResults.length == 1 ? '' : 's'} supported',
                style: const TextStyle(color: Colors.white70),
              );
            },
          ),
        ],

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => _resultPreviewController.reverse(),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () => _handleResultAction(result),
              child: Text(_getPrimaryActionLabel(qrType)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceOverlay() {
    final processingTime = _scanStartTime != null
        ? DateTime.now().difference(_scanStartTime!).inMilliseconds
        : 0;

    return Positioned(
      top: 50,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Scans: $_totalScans',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              'Success: $_successfulScans',
              style: const TextStyle(color: Colors.green, fontSize: 10),
            ),
            if (processingTime > 0)
              Text(
                '${processingTime}ms',
                style: const TextStyle(color: Colors.yellow, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialOfferDialog(EnrichedQRResult enrichedResult) {
    final offerContent =
        enrichedResult.validatedResult.parsedData.parsedContent!;
    final issuer = offerContent['issuer'] as Map<String, dynamic>?;
    final credentials = offerContent['credentials'] as List? ?? [];

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.card_membership, color: Colors.green),
          SizedBox(width: 8),
          Text('Credential Offer'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${issuer?['name'] ?? 'Unknown issuer'} is offering:'),
            const SizedBox(height: 16),
            ...credentials
                .take(3)
                .map(
                  (cred) => ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.verified,
                      color: Colors.green,
                      size: 20,
                    ),
                    title: Text(cred['type'] ?? 'Unknown credential'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            if (credentials.length > 3)
              Text('... and ${credentials.length - 3} more'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Decline'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Accept'),
        ),
      ],
    );
  }

  void _handleResultAction(EnrichedQRResult result) {
    final qrType = result.validatedResult.parsedData.type;

    if (qrType == QRType.presentationRequest) {
      _handlePresentationRequest(result);
    } else if (qrType == QRType.credentialOffer) {
      _handleCredentialOffer(result);
    }

    _resultPreviewController.reverse();
  }

  IconData _getQRTypeIcon(QRType type) {
    switch (type) {
      case QRType.presentationRequest:
        return Icons.request_page;
      case QRType.credentialOffer:
        return Icons.card_membership;
      case QRType.credentialData:
        return Icons.verified;
      case QRType.didcommMessage:
        return Icons.message;
      default:
        return Icons.qr_code;
    }
  }

  String _getQRTypeLabel(QRType type) {
    switch (type) {
      case QRType.presentationRequest:
        return 'Presentation Request';
      case QRType.credentialOffer:
        return 'Credential Offer';
      case QRType.credentialData:
        return 'Credential Data';
      case QRType.didcommMessage:
        return 'DIDComm Message';
      default:
        return 'QR Code';
    }
  }

  Color _getSecurityColor(SecurityLevel level) {
    switch (level) {
      case SecurityLevel.high:
        return Colors.green;
      case SecurityLevel.medium:
        return Colors.orange;
      case SecurityLevel.low:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return Colors.red;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.low:
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }

  String _getPrimaryActionLabel(QRType type) {
    switch (type) {
      case QRType.presentationRequest:
        return 'Share';
      case QRType.credentialOffer:
        return 'Accept';
      default:
        return 'Process';
    }
  }
}

/// Custom painter for scanner overlay with processing animation
class ScannerOverlayPainter extends CustomPainter {
  final bool isProcessing;
  final Animation<double> animation;

  ScannerOverlayPainter({required this.isProcessing, required this.animation})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw scanning frame
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.width * 0.8, // Square frame
    );

    // Draw corner brackets
    _drawCornerBrackets(canvas, frameRect, paint);

    // Draw scanning line if processing
    if (isProcessing) {
      _drawScanningLine(canvas, frameRect, paint);
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Paint paint) {
    const bracketLength = 30.0;

    // Top-left
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(bracketLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(0, bracketLength),
      paint,
    );

    // Top-right
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(-bracketLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(0, bracketLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(bracketLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -bracketLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-bracketLength, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -bracketLength),
      paint,
    );
  }

  void _drawScanningLine(Canvas canvas, Rect rect, Paint paint) {
    final lineY = rect.top + (rect.height * animation.value);

    final linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(rect.left, lineY),
      Offset(rect.right, lineY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) {
    return isProcessing != oldDelegate.isProcessing ||
        animation.value != oldDelegate.animation.value;
  }
}
