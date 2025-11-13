/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *          Frank Merkel <frank.merkel@netknights.it>
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
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:privacyidea_authenticator/l10n/app_localizations.dart';

import 'main_view_widgets/wallet_components/promotional_carousel.dart';
import 'main_view_widgets/expired_credentials_widget.dart';
// import 'main_view_widgets/card_widgets/mdl_placeholder_card.dart'; // No longer needed
// import 'main_view_widgets/wallet_components/mdl_placeholder_section.dart'; // Temporarily commented out
import '../../utils/utils.dart';
import '../../utils/view_utils.dart';
import '../../widgets/dialog_widgets/default_dialog.dart';
import '../qr_scanner_view/qr_scanner_view.dart';
import '../../model/processor_result.dart';
import '../../utils/riverpod/riverpod_providers/generated_providers/token_container_notifier.dart';
import '../../utils/riverpod/riverpod_providers/generated_providers/token_notifier.dart';

export 'wallet_landing_view.dart';

/// Wallet-style landing view that mimics iOS Wallet app
class WalletLandingView extends ConsumerStatefulWidget {
  static const routeName = '/walletLandingView';

  final Widget? backgroundImage;
  final String appName;

  const WalletLandingView({
    this.backgroundImage,
    this.appName = 'Marty Authenticator',
    super.key,
  });

  @override
  ConsumerState<WalletLandingView> createState() => _WalletLandingViewState();
}

class _WalletLandingViewState extends ConsumerState<WalletLandingView> {
  @override
  Widget build(BuildContext context) {
    // Wallet-style landing view with black background and iOS design
    return Container(
      color: Colors.black, // Wallet app uses black background
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              // Custom wallet-style header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Wallet title in upper left
                    const Text(
                      'Wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () async {
                        // Use the same QR scanning logic as the floating button
                        try {
                          if (await Permission.camera.isPermanentlyDenied) {
                            showAsyncDialog(
                              builder: (_) => DefaultDialog(
                                title: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.grantCameraPermissionDialogTitle,
                                ),
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.grantCameraPermissionDialogPermanentlyDenied,
                                ),
                              ),
                            );
                            return;
                          }
                        } catch (e) {
                          // Handle platform-specific permission issues
                        }
                        if (!context.mounted) return;

                        final qrCode = await Navigator.pushNamed(
                          context,
                          QRScannerView.routeName,
                        );
                        final resultHandlers = <ResultHandler>[
                          ref.read(tokenProvider.notifier),
                          ref.read(tokenContainerProvider.notifier),
                        ];
                        if (qrCode == null || !context.mounted) return;
                        final handled = await scanQrCode(
                          context: context,
                          resultHandlerList: resultHandlers,
                          qrCode: qrCode,
                        );
                        if (!handled) {
                          showErrorStatusMessage(
                            message: (l) => l.invalidQrScan,
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ), // Reduced from 28
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {}, // Placeholder for more actions
                      icon: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 24,
                      ), // Reduced from 28
                    ),
                  ],
                ),
              ),

              // Scrollable content (flexible constraints)
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            // Promotional carousel
                            const PromotionalCarousel(),

                            const SizedBox(height: 24),

                            // MDL placeholder card
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: _buildEnhancedMdlPlaceholder(),
                            ),

                            const SizedBox(height: 24),

                            // Passport placeholder card
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: _buildPassportPlaceholder(),
                            ),

                            const SizedBox(height: 30),

                            // Expired credentials widget - temporarily commented out to test overflow
                            // const ExpiredCredentialsWidget(),

                            // MDL placeholder section - temporarily commented out
                            // const MdlPlaceholderSection(),
                            const SizedBox(
                              height: 8,
                            ), // Reduced further to accommodate PromotionalCarousel
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigationArea(),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationArea() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(
        left: 40,
        right: 40,
        bottom: 4, // Further reduced to eliminate 49px overflow
        top: 1, // Reduced top padding
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Token Management Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/legacyMainView');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.list_alt, color: Color(0xFF007AFF), size: 18),
                    Text(
                      'Tokens',
                      style: TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // QR Scanner Button
          Semantics(
            label: AppLocalizations.of(context)!.a11yScanQrCodeButton,
            child: Container(
              height: 40, // Even smaller FAB
              width: 40,
              child: FloatingActionButton(
                onPressed: () async {
                  try {
                    if (await Permission.camera.isPermanentlyDenied) {
                      showAsyncDialog(
                        builder: (_) => DefaultDialog(
                          title: Text(
                            AppLocalizations.of(
                              context,
                            )!.grantCameraPermissionDialogTitle,
                          ),
                          content: Text(
                            AppLocalizations.of(
                              context,
                            )!.grantCameraPermissionDialogPermanentlyDenied,
                          ),
                        ),
                      );
                      return;
                    }
                  } catch (e) {
                    // Handle platform-specific permission issues (e.g., macOS during development)
                    // Continue to QR scanner as the camera permissions will be handled by the scanner itself
                  }
                  if (!context.mounted) return;

                  /// Open the QR-code scanner and call `handleQrCode`, with the scanned code as the argument.
                  final qrCode = await Navigator.pushNamed(
                    context,
                    QRScannerView.routeName,
                  );
                  final resultHandlers = <ResultHandler>[
                    ref.read(tokenProvider.notifier),
                    ref.read(tokenContainerProvider.notifier),
                  ];
                  if (qrCode == null || !context.mounted) return;
                  final handled = await scanQrCode(
                    context: context,
                    resultHandlerList: resultHandlers,
                    qrCode: qrCode,
                  );
                  if (!handled) {
                    showErrorStatusMessage(message: (l) => l.invalidQrScan);
                  }
                },
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 8,
                child: const Icon(Icons.qr_code_scanner_outlined, size: 20),
              ),
            ),
          ),

          // Empty space to balance the layout
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildEnhancedMdlPlaceholder() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Dotted circle pattern similar to wallet app
            _buildDottedPattern(),

            const SizedBox(height: 24),

            const Text(
              'Mobile Driver\'s License',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'Securely store your mobile driver\'s license\nfor quick and easy verification.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Add button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleAddMdl(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Add to Wallet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Learn more link
            TextButton(
              onPressed: () => _handleLearnMore(),
              child: Text(
                'Learn More',
                style: TextStyle(
                  color: const Color(0xFF007AFF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedPattern() {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(painter: DottedPatternPainter()),
    );
  }

  void _handleAddMdl() {
    // Show modal with add options
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(3),
              ),
              margin: const EdgeInsets.only(bottom: 20),
            ),

            const Text(
              'Add Driver\'s License',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            _buildAddOption(
              'Scan QR Code',
              'Use your camera to scan a QR code from your DMV',
              Icons.qr_code_scanner,
              () {
                Navigator.of(context).pop();
                _showComingSoon('QR Code scanning for MDL');
              },
            ),

            const SizedBox(height: 16),

            _buildAddOption(
              'DMV Mobile App',
              'Import from your state\'s official DMV app',
              Icons.phone_android,
              () {
                Navigator.of(context).pop();
                _showComingSoon('DMV app integration');
              },
            ),

            const SizedBox(height: 16),

            _buildAddOption(
              'Test MDL',
              'Add a test mobile driver\'s license for demo',
              Icons.science_outlined,
              () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test MDL added successfully!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF007AFF), size: 24),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _handleLearnMore() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Mobile Driver\'s License',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'A mobile driver\'s license (mDL) is a digital version of your physical driver\'s license that can be stored securely on your phone. It provides the same legal validity as your physical license while offering enhanced security and convenience.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(color: Color(0xFF007AFF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon!'),
        backgroundColor: const Color(0xFF007AFF),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPassportPlaceholder() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E), // Darker blue-purple for passport
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        // Subtle gradient for passport elegance
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF2E3F66), const Color(0xFF1A1A2E)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Passport emblem pattern
            _buildPassportEmblemPattern(),

            const SizedBox(height: 24),

            const Text(
              'Passport',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            Text(
              'Store your digital passport\nfor international travel verification.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Add button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleAddPassport(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6FA5), // Passport blue
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Add to Wallet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Learn more link
            TextButton(
              onPressed: () => _handlePassportLearnMore(),
              child: Text(
                'Learn More',
                style: TextStyle(
                  color: const Color(0xFF4A6FA5), // Passport blue
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassportEmblemPattern() {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(painter: PassportEmblemPainter()),
    );
  }

  void _handleAddPassport() {
    // Show modal with passport add options
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(3),
              ),
              margin: const EdgeInsets.only(bottom: 20),
            ),

            const Text(
              'Add Passport',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            _buildAddOption(
              'Scan QR Code',
              'Use your camera to scan a QR code from your passport authority',
              Icons.qr_code_scanner,
              () {
                Navigator.of(context).pop();
                // Handle passport QR code scanning
              },
            ),

            const SizedBox(height: 12),

            _buildAddOption(
              'Enter Details Manually',
              'Add your passport information manually',
              Icons.edit,
              () {
                Navigator.of(context).pop();
                // Handle manual passport entry
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _handlePassportLearnMore() {
    // Handle passport learn more
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Digital Passport',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Store your digital passport securely in your wallet for convenient travel verification and border control.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF4A6FA5)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the passport emblem pattern
class PassportEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw concentric circles to represent passport emblem
    canvas.drawCircle(center, 30, paint);
    canvas.drawCircle(center, 50, paint);

    // Draw stylized eagle/emblem silhouette
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white.withOpacity(0.06);

    // Draw a simplified emblem shape (like an eagle or coat of arms)
    final path = Path();
    path.moveTo(center.dx, center.dy - 25);
    path.lineTo(center.dx - 15, center.dy - 10);
    path.lineTo(center.dx - 20, center.dy + 5);
    path.lineTo(center.dx - 8, center.dy + 15);
    path.lineTo(center.dx, center.dy + 20);
    path.lineTo(center.dx + 8, center.dy + 15);
    path.lineTo(center.dx + 20, center.dy + 5);
    path.lineTo(center.dx + 15, center.dy - 10);
    path.close();

    canvas.drawPath(path, paint);

    // Add decorative elements around the emblem
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * (3.14159 / 180);
      final x = center.dx + 65 * cos(angle);
      final y = center.dy + 65 * sin(angle);
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// Custom painter for the dotted pattern in the placeholder card
class DottedPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    const double dotSize = 4.0;
    const double spacing = 12.0;

    // Create a grid of dots with varying opacity to create depth effect
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Calculate distance from center for varying opacity
        final centerX = size.width / 2;
        final centerY = size.height / 2;
        final distance =
            ((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
        final maxDistance = (centerX * centerX + centerY * centerY);
        final opacity = 0.3 - (distance / maxDistance) * 0.25;

        if (opacity > 0) {
          paint.color = Colors.white.withOpacity(opacity);
          canvas.drawCircle(Offset(x, y), dotSize / 2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
