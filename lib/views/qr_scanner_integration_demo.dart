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

/// Integration demonstration showing QR scanner working with credential selection
/// 
/// This demonstrates the complete flow:
/// 1. QR scanner detects presentation request
/// 2. Parse request to extract required attributes
/// 3. Launch credential selection view with SDK-enhanced capabilities
/// 4. Create presentation with selective disclosure
/// 5. Return presentation or share via QR code

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../views/credential_selection_view.dart';
import '../services/spruce_sdk_services.dart';
import '../utils/logger.dart';
import '../widgets/qr_scanner.dart';

/// Demo integration showing QR scanner -> Credential selection workflow
class QrScannerIntegrationDemo extends ConsumerStatefulWidget {
  const QrScannerIntegrationDemo({super.key});

  @override
  ConsumerState<QrScannerIntegrationDemo> createState() => _QrScannerIntegrationDemoState();
}

class _QrScannerIntegrationDemoState extends ConsumerState<QrScannerIntegrationDemo> {
  String? _lastScannedCode;
  Map<String, dynamic>? _parsedRequest;
  bool _isProcessing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner + SDK Integration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Integration Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Scan QR codes for presentation requests. The system will parse the request, '
                  'launch credential selection with SDK-enhanced privacy controls, and create '
                  'secure presentations with selective disclosure.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_lastScannedCode != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Last scanned: ${_lastScannedCode!.length > 50 ? _lastScannedCode!.substring(0, 50) + "..." : _lastScannedCode}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (_parsedRequest != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Parsed request: ${_parsedRequest!['type'] ?? 'Unknown'} '
                    '(${(_parsedRequest!['requested_attributes'] as List?)?.length ?? 0} attributes)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // QR Scanner area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildScannerArea(),
              ),
            ),
          ),

          // Demo buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Simulate Presentation Request'),
                        onPressed: _isProcessing ? null : _simulatePresentationRequest,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.credit_card),
                        label: const Text('Simulate Credential Offer'),
                        onPressed: _isProcessing ? null : _simulateCredentialOffer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.security),
                    label: const Text('Show SDK Security Features'),
                    onPressed: _showSdkSecurityFeatures,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerArea() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing request...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _error = null),
              child: const Text('Clear Error'),
            ),
          ],
        ),
      );
    }

    // In a real implementation, this would be the actual QR scanner widget
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: Colors.blue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'QR Scanner Area',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Camera would be active here',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Use demo buttons below to simulate QR code scanning',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _simulatePresentationRequest() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Simulate scanning a presentation request QR code
      final mockPresentationRequest = {
        'type': 'PresentationRequest',
        'version': '1.0',
        'challenge': 'challenge-${DateTime.now().millisecondsSinceEpoch}',
        'domain': 'example-verifier.com',
        'requested_attributes': [
          'name',
          'email',
          'date_of_birth',
          'address',
          'phone_number'
        ],
        'optional_attributes': [
          'profile_picture',
          'emergency_contact'
        ],
        'purpose': 'Identity verification for secure access',
        'verifier': {
          'name': 'Demo Verifier Service',
          'did': 'did:example:123456789abcdefghi',
          'logo': 'https://example.com/logo.png'
        },
        'presentation_definition': {
          'format': {
            'jwt_vc': {'alg': ['EdDSA', 'ES256K']}
          },
          'input_descriptors': [
            {
              'id': 'identity_credential',
              'purpose': 'We need to verify your identity',
              'constraints': {
                'fields': [
                  {'path': ['\$.credentialSubject.name']},
                  {'path': ['\$.credentialSubject.email']},
                ]
              }
            }
          ]
        }
      };

      final qrCodeContent = jsonEncode(mockPresentationRequest);
      
      await _handleScannedCode(qrCodeContent);
      
    } catch (e) {
      setState(() {
        _error = 'Failed to simulate presentation request: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _simulateCredentialOffer() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Simulate scanning a credential offer QR code
      final mockCredentialOffer = {
        'type': 'CredentialOffer',
        'version': '1.0',
        'issuer': {
          'name': 'Demo Identity Issuer',
          'did': 'did:example:issuer123',
          'logo': 'https://issuer.example.com/logo.png'
        },
        'credentials': [
          {
            'type': 'IdentityCredential',
            'format': 'jwt_vc',
            'cryptographic_binding_methods_supported': ['did:key'],
            'proof_types_supported': ['JsonWebSignature2020'],
            'credential_definition': {
              'type': ['VerifiableCredential', 'IdentityCredential'],
              'credentialSubject': {
                'name': 'John Doe',
                'email': 'john.doe@example.com',
                'date_of_birth': '1990-01-01',
                'id_number': '123456789'
              }
            }
          }
        ],
        'grants': {
          'authorization_code': {
            'issuer_state': 'state-${DateTime.now().millisecondsSinceEpoch}'
          },
          'urn:ietf:params:oauth:grant-type:pre-authorized_code': {
            'pre-authorized_code': 'code-${DateTime.now().millisecondsSinceEpoch}',
            'user_pin_required': false
          }
        }
      };

      final qrCodeContent = jsonEncode(mockCredentialOffer);
      
      await _handleScannedCode(qrCodeContent);
      
    } catch (e) {
      setState(() {
        _error = 'Failed to simulate credential offer: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleScannedCode(String qrCodeContent) async {
    setState(() {
      _lastScannedCode = qrCodeContent;
    });

    try {
      // Parse the QR code content
      final parsedData = jsonDecode(qrCodeContent) as Map<String, dynamic>;
      
      setState(() {
        _parsedRequest = parsedData;
      });

      // Handle based on type
      final type = parsedData['type'] as String?;
      
      if (type == 'PresentationRequest') {
        await _handlePresentationRequest(parsedData);
      } else if (type == 'CredentialOffer') {
        await _handleCredentialOffer(parsedData);
      } else {
        throw Exception('Unknown QR code type: $type');
      }
      
    } catch (e) {
      setState(() {
        _error = 'Failed to parse QR code: $e';
      });
    }
  }

  Future<void> _handlePresentationRequest(Map<String, dynamic> request) async {
    final requestedAttributes = (request['requested_attributes'] as List?)
        ?.cast<String>() ?? [];
    
    if (requestedAttributes.isEmpty) {
      throw Exception('No requested attributes found in presentation request');
    }

    // Show confirmation dialog first
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.blue),
            SizedBox(width: 8),
            Text('Presentation Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request['verifier']?['name'] ?? 'Unknown verifier'} is requesting:'),
            const SizedBox(height: 12),
            ...requestedAttributes.take(3).map((attr) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(attr),
                ],
              ),
            )),
            if (requestedAttributes.length > 3)
              Text('... and ${requestedAttributes.length - 3} more attributes'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can choose which information to share using selective disclosure.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    // Launch credential selection view
    final presentation = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => CredentialSelectionView(
          presentationRequest: jsonEncode(request),
          requestedAttributes: requestedAttributes,
          challenge: request['challenge'] as String?,
          domain: request['domain'] as String?,
        ),
      ),
    );

    if (presentation != null) {
      _showPresentationResult(presentation);
    }
  }

  Future<void> _handleCredentialOffer(Map<String, dynamic> offer) async {
    // Show credential offer details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.card_membership, color: Colors.green),
            SizedBox(width: 8),
            Text('Credential Offer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${offer['issuer']?['name'] ?? 'Unknown issuer'} is offering credentials:'),
            const SizedBox(height: 12),
            ...(offer['credentials'] as List?)?.take(3).map((cred) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.verified, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(cred['type'] ?? 'Unknown credential'),
                ],
              ),
            )) ?? [],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Credential offer handling would be implemented with SDK credential storage.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showInfo('Credential offer would be processed using SDK wallet manager');
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showPresentationResult(Map<String, dynamic> presentation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Presentation Created'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Presentation created successfully with SDK-enhanced security.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Presentation Details:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('ID: ${presentation['id'] ?? 'N/A'}'),
                  Text('Type: ${presentation['type'] ?? 'N/A'}'),
                  if (presentation['proof'] != null)
                    Text('Signed: ✓'),
                  if (presentation['selectiveDisclosure'] != null)
                    Text('Selective Disclosure: ✓'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sharePresentation(presentation);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePresentation(Map<String, dynamic> presentation) async {
    // In a real implementation, this would generate a QR code or use other sharing mechanisms
    final presentationJson = jsonEncode(presentation);
    
    await Clipboard.setData(ClipboardData(text: presentationJson));
    
    _showInfo('Presentation copied to clipboard. In production, this would be shared via QR code or NFC.');
  }

  void _showSdkSecurityFeatures() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.green),
            SizedBox(width: 8),
            Text('SDK Security Features'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFeatureItem(
                'Hardware-Backed Keys',
                'Cryptographic keys stored in secure hardware modules (HSM/TEE)',
                Icons.memory,
              ),
              _buildFeatureItem(
                'Selective Disclosure',
                'Share only required information with fine-grained privacy controls',
                Icons.visibility_off,
              ),
              _buildFeatureItem(
                'Zero-Knowledge Proofs',
                'Prove attributes without revealing the actual data',
                Icons.lock,
              ),
              _buildFeatureItem(
                'Biometric Authentication',
                'User presence verification through secure biometric sensors',
                Icons.fingerprint,
              ),
              _buildFeatureItem(
                'Credential Lifecycle',
                'Automated renewal, revocation checking, and expiry management',
                Icons.refresh,
              ),
              _buildFeatureItem(
                'Cross-Platform Security',
                '45% Android, 62% iOS code reduction with consistent security',
                Icons.devices,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Scanner Integration'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This demo shows how the QR scanner integrates with SDK-enhanced credential selection:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('1. QR codes are scanned and parsed'),
              const Text('2. Presentation requests launch credential selection'),
              const Text('3. Users choose credentials and attributes to share'),
              const Text('4. SDK creates secure presentations with selective disclosure'),
              const Text('5. Results can be shared back via QR codes'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Use the demo buttons to simulate different QR code types and see the complete workflow in action.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
