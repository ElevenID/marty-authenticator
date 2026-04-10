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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mdoc_credential.dart';
import '../services/zk_verification_service.dart';

/// Detail view for mobile Driver's License (mDL)
/// Shows setup information when not issued, or displays the mDL when available
class MdlDetailView extends ConsumerStatefulWidget {
  final MDocCredential? credential;

  const MdlDetailView({super.key, this.credential});

  @override
  ConsumerState<MdlDetailView> createState() => _MdlDetailViewState();
}

class _MdlDetailViewState extends ConsumerState<MdlDetailView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCredential = widget.credential != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Custom app bar
            _buildAppBar(context),

            // Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: hasCredential
                      ? _buildIssuedMdlView()
                      : _buildGetMdlView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          if (widget.credential != null)
            IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.white),
              onPressed: () => _showOptions(),
            ),
        ],
      ),
    );
  }

  Widget _buildGetMdlView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Large card preview
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
              ),
            ),
            child: Stack(
              children: [
                // Dot pattern
                Positioned.fill(
                  child: CustomPaint(painter: _DotPatternPainter()),
                ),
                // Card content
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.credit_card,
                              size: 24,
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Mobile Driver\'s License',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'Get Your mDL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Information section
          _buildInfoSection(
            icon: Icons.security,
            title: 'Secure & Private',
            description:
                'Your mDL is stored securely on your device and protected with biometric authentication.',
          ),

          const SizedBox(height: 24),

          _buildInfoSection(
            icon: Icons.verified_user,
            title: 'Officially Recognized',
            description:
                'Accepted by TSA and participating organizations as a valid form of identification.',
          ),

          const SizedBox(height: 24),

          _buildInfoSection(
            icon: Icons.offline_bolt,
            title: 'Works Offline',
            description:
                'Access your mDL anytime, even without an internet connection.',
          ),

          const SizedBox(height: 48),

          // Get Started button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startMdlIssuance(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () => _showLearnMore(),
            child: const Text(
              'Learn More',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildIssuedMdlView() {
    final credential = widget.credential!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Large card display
          Container(
            height: 240,
            margin: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade800, Colors.blue.shade900],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    credential.issuingAuthority,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    credential.holderName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DL: ${credential.documentNumber}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.qr_code,
                  label: 'Present',
                  onTap: () => _presentCredential(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () => _shareCredential(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.security,
                  label: 'Verify Age',
                  onTap: () => _verifyAge(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Details section
          _buildDetailRow('Name', credential.holderName),
          _buildDetailRow(
            'Birth Date',
            'N/A',
          ), // birthDate not directly available
          _buildDetailRow('Document Number', credential.documentNumber),
          _buildDetailRow('Expires', _formatDate(credential.expiryDate)),
          _buildDetailRow('Issued By', credential.issuingAuthority),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          Text(
            value ?? 'N/A',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.month}/${date.day}/${date.year}';
  }

  void _startMdlIssuance() {
    HapticFeedback.mediumImpact();
    // TODO: Implement mDL issuance flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting mDL issuance process...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLearnMore() {
    // TODO: Show learn more dialog or navigate to info page
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Mobile Driver\'s License'),
        content: const Text(
          'A mobile Driver\'s License (mDL) is a digital version of your physical driver\'s license. '
          'It provides the same legal validity while offering enhanced security and privacy features.\n\n'
          'Your mDL is stored securely on your device and can be presented using NFC, QR codes, or Bluetooth.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showOptions() {
    // TODO: Show options menu
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.white),
            title: const Text('Refresh', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // TODO: Refresh credential
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Remove mDL',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              // TODO: Remove credential
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _presentCredential() {
    HapticFeedback.mediumImpact();
    // TODO: Implement credential presentation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Presenting credential...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareCredential() {
    HapticFeedback.lightImpact();
    // TODO: Implement credential sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing credential...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _verifyAge() async {
    HapticFeedback.mediumImpact();

    final zkService = ref.read(zkVerificationServiceProvider);

    // Check if supported first
    final supported = await zkService.isSupported();
    if (!supported && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ZK Proofs not supported on this device/OS version'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating ZK Proof of Age (18+)...'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Generic implementation using Presentation Definition
    try {
      // Mock data - In a real app these come from the credential and backend session
      final request = PdProofRequest(
        presentationDefinition: {
          "input_descriptors": [
            {
              "id": "age_over_18",
              "schema": [
                {"uri": "org.iso.18013.5.1.mDL"},
              ],
              "constraints": {
                "fields": [
                  {
                    "path": ["\$.credentialSubject.birth_date"],
                    "filter": {"type": "string"},
                  },
                ],
              },
            },
          ],
        },
        mdocBytes: Uint8List(0),
        issuerPkx: '',
        issuerPky: '',
        docType: 'org.iso.18013.5.1.mDL',
        secrets: {"birth_date": "1990-01-01"},
        sessionNonce: Uint8List(0),
      );

      final proof = await zkService.generateProof(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Proof generated successfully! Size: ${proof.length} bytes',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating proof: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Custom painter for the dot pattern background
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    const dotSize = 2.0;
    const spacing = 12.0;

    // Create a semi-circle dot pattern
    final centerX = size.width * 0.75;
    final centerY = size.height * 0.5;
    final maxRadius = size.width * 0.6;

    for (double radius = 20; radius < maxRadius; radius += spacing) {
      final dotsInCircle = (2 * math.pi * radius / spacing).floor();
      for (int i = 0; i < dotsInCircle; i++) {
        final angle = (i / dotsInCircle) * 2 * math.pi;
        final x = centerX + radius * math.cos(angle);
        final y = centerY + radius * math.sin(angle);

        // Only draw dots within card bounds
        if (x >= 0 && x <= size.width && y >= 0 && y <= size.height) {
          canvas.drawCircle(Offset(x, y), dotSize, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
