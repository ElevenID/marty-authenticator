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

/// Enhanced QR scanner view with SpruceID SDK integration
/// 
/// This view replaces the standard QR scanner with enhanced capabilities:
/// - Real-time credential processing during scan
/// - Privacy analysis and risk assessment
/// - Intelligent credential matching
/// - Optimized performance for SSI workflows

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n/app_localizations.dart';
import '../../services/qr_scanner_service_enhanced.dart';
import '../../utils/logger.dart';
import '../../views/view_interface.dart';
import '../../widgets/dialog_widgets/default_dialog.dart';
import '../../widgets/qr_scanner_enhanced.dart';

/// Enhanced QR scanner view with SDK integration
class QRScannerViewEnhanced extends StatefulView {
  static const routeName = '/qr_scanner_enhanced';

  final void Function(ProcessedQRResult result)? onScanResult;
  final bool enableBackgroundProcessing;
  final bool showLivePreview;

  const QRScannerViewEnhanced({
    super.key,
    this.onScanResult,
    this.enableBackgroundProcessing = true,
    this.showLivePreview = true,
  });

  @override
  State<QRScannerViewEnhanced> createState() => _QRScannerViewEnhancedState();

  @override
  RouteSettings get routeSettings =>
      const RouteSettings(name: QRScannerViewEnhanced.routeName);
}

class _QRScannerViewEnhancedState extends State<QRScannerViewEnhanced>
    with TickerProviderStateMixin {
  
  bool _isPermissionGranted = false;
  bool _isCheckingPermissions = true;
  ProcessedQRResult? _lastProcessedResult;
  
  // Animation controllers for enhanced UX
  late AnimationController _permissionCheckController;
  late Animation<double> _permissionCheckAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkPermissions();
  }

  void _initializeAnimations() {
    _permissionCheckController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _permissionCheckAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _permissionCheckController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _permissionCheckController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      final status = await _requestCameraPermission();
      setState(() {
        _isPermissionGranted = status == PermissionStatus.granted;
        _isCheckingPermissions = false;
      });

      if (!_isPermissionGranted && mounted) {
        await _showPermissionDialog();
      }
    } catch (e) {
      Logger.error('Permission check failed', error: e, name: 'QRScannerViewEnhanced');
      setState(() {
        _isCheckingPermissions = false;
        _isPermissionGranted = false;
      });
    }
  }

  Future<PermissionStatus> _requestCameraPermission() async {
    try {
      // On web, bypass camera permissions since we use image upload
      if (kIsWeb) {
        return PermissionStatus.granted;
      }

      // Check current permission status
      final currentStatus = await Permission.camera.status;
      if (currentStatus == PermissionStatus.granted) {
        return currentStatus;
      }

      // Request permission if not already granted
      if (currentStatus == PermissionStatus.denied || 
          currentStatus == PermissionStatus.restricted) {
        final requestedStatus = await Permission.camera.request();
        return requestedStatus;
      }

      return currentStatus;
    } catch (e) {
      Logger.error('Failed to request camera permission', error: e, name: 'QRScannerViewEnhanced');
      return PermissionStatus.denied;
    }
  }

  Future<void> _showPermissionDialog() async {
    final localizations = AppLocalizations.of(context)!;
    
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return DefaultDialog(
          title: localizations.cameraPermissionDialogTitle,
          content: _buildPermissionDialogContent(),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await openAppSettings();
              },
              child: Text(localizations.cameraPermissionDialogButton),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionDialogContent() {
    final localizations = AppLocalizations.of(context)!;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.camera_alt, color: Colors.blue, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                localizations.cameraPermissionDialogPermanentlyDenied,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.enhanced_encryption, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enhanced QR scanner with SDK-powered credential processing',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleScanResult(ProcessedQRResult result) {
    setState(() {
      _lastProcessedResult = result;
    });
    
    // Log scan result for debugging
    Logger.info(
      'Enhanced QR scan completed: ${result.enrichedResult?.validatedResult.parsedData.type ?? 'unknown'}',
      name: 'QRScannerViewEnhanced'
    );
    
    // Call external callback if provided
    widget.onScanResult?.call(result);
    
    // Auto-navigate back for successful processing
    if (result.isSuccess && result.enrichedResult != null) {
      _handleSuccessfulResult(result);
    }
  }

  Future<void> _handleSuccessfulResult(ProcessedQRResult result) async {
    final enrichedResult = result.enrichedResult!;
    final qrType = enrichedResult.validatedResult.parsedData.type;
    
    // Show success feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Successfully processed ${_getQRTypeLabel(qrType)}'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // For certain QR types, stay on the scanner for multiple scans
    final shouldStayOpen = qrType == QRType.credentialData || 
                          qrType == QRType.didcommMessage;
    
    if (!shouldStayOpen) {
      // Auto-close after short delay for presentation requests and offers
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      });
    }
  }

  String _getQRTypeLabel(QRType type) {
    switch (type) {
      case QRType.presentationRequest: return 'presentation request';
      case QRType.credentialOffer: return 'credential offer';
      case QRType.credentialData: return 'credential';
      case QRType.didcommMessage: return 'DIDComm message';
      default: return 'QR code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(localizations.scanQrCode),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          // Enhanced scanner indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.enhanced_encryption, size: 16),
                const SizedBox(width: 4),
                Text(
                  'SDK',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isCheckingPermissions) {
      return _buildPermissionCheckingView();
    }

    if (!_isPermissionGranted) {
      return _buildPermissionDeniedView();
    }

    return _buildScannerView();
  }

  Widget _buildPermissionCheckingView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _permissionCheckAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * _permissionCheckAnimation.value),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 80,
                    color: Colors.white70,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Checking camera permissions...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enhanced scanner requires camera access',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
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

  Widget _buildPermissionDeniedView() {
    final localizations = AppLocalizations.of(context)!;
    
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 120,
              color: Colors.white54,
            ),
            const SizedBox(height: 32),
            Text(
              localizations.cameraPermissionDialogTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.cameraPermissionDialogPermanentlyDenied,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.enhanced_encryption, color: Colors.blue, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Enhanced QR Scanner',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SDK-powered credential processing\nwith privacy analysis',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  child: Text(localizations.cameraPermissionDialogButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return QRScannerEnhanced(
      onScanResult: _handleScanResult,
      enableBackgroundProcessing: widget.enableBackgroundProcessing,
      showLivePreview: widget.showLivePreview,
      enableHapticFeedback: true,
    );
  }
}

/// Consumer widget wrapper for easier provider access
class QRScannerViewEnhancedConsumer extends ConsumerWidget {
  final void Function(ProcessedQRResult result)? onScanResult;
  final bool enableBackgroundProcessing;
  final bool showLivePreview;

  const QRScannerViewEnhancedConsumer({
    super.key,
    this.onScanResult,
    this.enableBackgroundProcessing = true,
    this.showLivePreview = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize enhanced QR scanner service
    ref.watch(qrScannerServiceEnhancedProvider);
    
    return QRScannerViewEnhanced(
      onScanResult: onScanResult,
      enableBackgroundProcessing: enableBackgroundProcessing,
      showLivePreview: showLivePreview,
    );
  }
}
