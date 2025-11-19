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

/// Comprehensive credential selection view with SDK-enhanced capabilities
/// 
/// This view demonstrates the complete integration of SDK-enhanced services with:
/// - Advanced credential selection and filtering
/// - Privacy-preserving presentation creation
/// - Real-time security assessment
/// - Hardware-backed operations
/// - Comprehensive selective disclosure controls

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/spruce_sdk_services.dart';
import '../widgets/spruce_credential_selection_widget.dart';
import '../widgets/selective_disclosure_sheet.dart';
import '../utils/logger.dart';
import '../utils/spruce_channels.dart';

/// Main credential selection view
class CredentialSelectionView extends ConsumerStatefulWidget {
  final String? presentationRequest;
  final List<String> requestedAttributes;
  final String? challenge;
  final String? domain;

  const CredentialSelectionView({
    super.key,
    this.presentationRequest,
    required this.requestedAttributes,
    this.challenge,
    this.domain,
  });

  @override
  ConsumerState<CredentialSelectionView> createState() => 
      _CredentialSelectionViewState();
}

class _CredentialSelectionViewState extends ConsumerState<CredentialSelectionView> {
  List<Map<String, dynamic>> _availableCredentials = [];
  List<SelectableCredential> _selectedCredentials = [];
  Map<String, List<String>> _currentSelectiveDisclosure = {};
  bool _isLoading = false;
  bool _isCreatingPresentation = false;
  String? _error;
  SecurityAssessment? _securityAssessment;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use SDK-enhanced wallet manager to get credentials
      final walletManager = ref.read(spruceIdWalletManagerExtendedProvider);
      
      // Get all stored credentials
      final credentials = await walletManager.getAllCredentials();
      
      // Filter credentials that match the request
      _availableCredentials = _filterRelevantCredentials(credentials);
      
      // Perform security assessment
      await _performSecurityAssessment();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load credentials: $e';
        _isLoading = false;
      });
      Logger.error('Credential loading failed', error: e);
    }
  }

  List<Map<String, dynamic>> _filterRelevantCredentials(List<Map<String, dynamic>> credentials) {
    // Filter credentials based on requested attributes and compatibility
    return credentials.where((credential) {
      final claims = credential['credentialSubject'] as Map<String, dynamic>? ?? {};
      
      // Check if credential contains any of the requested attributes
      final hasRelevantAttributes = widget.requestedAttributes.any(
        (attr) => claims.containsKey(attr),
      );
      
      return hasRelevantAttributes;
    }).toList();
  }

  Future<void> _performSecurityAssessment() async {
    try {
      final client = ref.read(spruceIdClientExtendedProvider);
      
      // Assess each credential's security capabilities
      final assessments = <String, Map<String, dynamic>>{};
      
      for (final credential in _availableCredentials) {
        final credentialId = credential['id'] as String;
        try {
          final capabilities = await client.getCredentialCapabilitiesSDK(credentialId);
          assessments[credentialId] = capabilities;
        } catch (e) {
          Logger.warning('Failed to assess credential $credentialId: $e');
        }
      }
      
      _securityAssessment = SecurityAssessment(
        credentialAssessments: assessments,
        overallSecurityLevel: _calculateOverallSecurityLevel(assessments),
        recommendations: _generateSecurityRecommendations(assessments),
      );
    } catch (e) {
      Logger.error('Security assessment failed', error: e);
    }
  }

  SecurityLevel _calculateOverallSecurityLevel(Map<String, Map<String, dynamic>> assessments) {
    if (assessments.isEmpty) return SecurityLevel.unknown;
    
    // Calculate based on hardware backing and key security
    final hasHardwareBacking = assessments.values.any(
      (assessment) => assessment['hardware_backed'] == true,
    );
    
    final hasStrongCrypto = assessments.values.any(
      (assessment) => assessment['algorithm'] == 'Ed25519' || assessment['algorithm'] == 'P-256',
    );
    
    if (hasHardwareBacking && hasStrongCrypto) return SecurityLevel.high;
    if (hasStrongCrypto) return SecurityLevel.medium;
    return SecurityLevel.low;
  }

  List<String> _generateSecurityRecommendations(Map<String, Map<String, dynamic>> assessments) {
    final recommendations = <String>[];
    
    final softwareBackedCount = assessments.values.where(
      (assessment) => assessment['hardware_backed'] != true,
    ).length;
    
    if (softwareBackedCount > 0) {
      recommendations.add('Consider using hardware-backed credentials for enhanced security');
    }
    
    final weakCryptoCount = assessments.values.where(
      (assessment) => !['Ed25519', 'P-256'].contains(assessment['algorithm']),
    ).length;
    
    if (weakCryptoCount > 0) {
      recommendations.add('Some credentials use legacy cryptography - consider regenerating with modern algorithms');
    }
    
    return recommendations;
  }

  void _onSelectionChanged(
    List<SelectableCredential> selectedCredentials,
    Map<String, List<String>> selectiveDisclosure,
  ) {
    setState(() {
      _selectedCredentials = selectedCredentials;
      _currentSelectiveDisclosure = selectiveDisclosure;
    });
  }

  Future<void> _onPresentationCreate(
    List<SelectableCredential> selectedCredentials,
    Map<String, List<String>> selectiveDisclosure,
  ) async {
    setState(() {
      _isCreatingPresentation = true;
    });

    try {
      final client = ref.read(spruceIdClientExtendedProvider);
      
      // Generate secure key for presentation if needed
      final keyResult = await client.generateSecureKeySDK(
        algorithm: 'Ed25519',
        useHardwareModule: true,
        keyPolicies: {
          'user_presence_required': true,
          'purpose': 'presentation_signing',
        },
      );
      
      final keyId = keyResult['keyId'] as String;
      
      // Prepare credential data for presentation
      final credentialData = selectedCredentials.map((cred) {
        final disclosedClaims = <String, dynamic>{};
        final disclosedAttributes = selectiveDisclosure[cred.id] ?? [];
        
        for (final attr in disclosedAttributes) {
          if (cred.claims.containsKey(attr)) {
            disclosedClaims[attr] = cred.claims[attr];
          }
        }
        
        return {
          'id': cred.id,
          'type': cred.type,
          'credentialSubject': disclosedClaims,
          'issuer': cred.issuer,
        };
      }).toList();
      
      // Create presentation using SDK
      final presentation = await client.createPresentationSDK(
        credentials: credentialData,
        challenge: widget.challenge ?? 'default-challenge',
        domain: widget.domain ?? 'default-domain',
        selectiveDisclosure: selectiveDisclosure,
        keyId: keyId,
      );
      
      // Show success and return result
      _showPresentationSuccess(presentation);
      
    } catch (e) {
      _showError('Failed to create presentation: $e');
      Logger.error('Presentation creation failed', error: e);
    } finally {
      setState(() {
        _isCreatingPresentation = false;
      });
    }
  }

  Future<void> _showAdvancedDisclosureSheet(SelectableCredential credential) async {
    final result = await SelectiveDisclosureSheet.show(
      context: context,
      credential: credential,
      presentationRequest: {
        'requested_attributes': widget.requestedAttributes,
        'challenge': widget.challenge,
        'domain': widget.domain,
      },
    );

    if (result != null) {
      // Update the credential's attribute selections
      final updatedCredentials = _selectedCredentials.map((cred) {
        if (cred.id == credential.id) {
          return cred.copyWith(attributeSelections: result);
        }
        return cred;
      }).toList();

      final updatedDisclosure = Map<String, List<String>>.from(_currentSelectiveDisclosure);
      updatedDisclosure[credential.id] = result.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      _onSelectionChanged(updatedCredentials, updatedDisclosure);
    }
  }

  void _showPresentationSuccess(Map<String, dynamic> presentation) {
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
            const Text('Verifiable presentation created successfully with selective disclosure.'),
            const SizedBox(height: 16),
            Text(
              'Presentation ID: ${presentation['id'] ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Security Level: ${_securityAssessment?.overallSecurityLevel.name ?? 'Unknown'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(presentation); // Return result
            },
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () => _sharePresentation(presentation),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePresentation(Map<String, dynamic> presentation) async {
    // Implementation would depend on sharing mechanism (QR code, NFC, etc.)
    _showInfo('Presentation sharing functionality would be implemented here');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credential Selection'),
        actions: [
          if (_securityAssessment != null)
            IconButton(
              icon: Icon(
                _securityAssessment!.overallSecurityLevel.icon,
                color: _securityAssessment!.overallSecurityLevel.color,
              ),
              onPressed: _showSecurityAssessment,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading credentials...'),
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
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCredentials,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_availableCredentials.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No suitable credentials found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'No credentials contain the requested attributes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.requestedAttributes.isNotEmpty) _buildRequestSummary(),
          const SizedBox(height: 24),
          if (_securityAssessment != null) _buildSecurityOverview(),
          const SizedBox(height: 24),
          SpruceCredentialSelectionWidget(
            availableCredentials: _availableCredentials,
            requestedAttributes: widget.requestedAttributes,
            presentationRequest: widget.presentationRequest,
            onSelectionChanged: _onSelectionChanged,
            onPresentationCreate: _onPresentationCreate,
          ),
          const SizedBox(height: 24),
          if (_selectedCredentials.isNotEmpty) _buildAdvancedControls(),
        ],
      ),
    );
  }

  Widget _buildRequestSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.request_page, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Presentation Request',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Requested attributes:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.requestedAttributes.map((attr) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                attr,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )).toList(),
          ),
          if (widget.domain != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.domain, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Domain: ${widget.domain}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityOverview() {
    if (_securityAssessment == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _securityAssessment!.overallSecurityLevel.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _securityAssessment!.overallSecurityLevel.color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _securityAssessment!.overallSecurityLevel.icon,
                color: _securityAssessment!.overallSecurityLevel.color,
              ),
              const SizedBox(width: 8),
              Text(
                'Security Assessment',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _securityAssessment!.overallSecurityLevel.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _securityAssessment!.overallSecurityLevel.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (_securityAssessment!.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...(_securityAssessment!.recommendations.take(2).map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ))),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Controls',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...(_selectedCredentials.map((credential) => Card(
          child: ListTile(
            leading: Icon(Icons.tune, color: Theme.of(context).primaryColor),
            title: Text('Fine-tune ${credential.name}'),
            subtitle: Text('${credential.disclosedAttributes.length} attributes disclosed'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showAdvancedDisclosureSheet(credential),
          ),
        ))),
      ],
    );
  }

  void _showSecurityAssessment() {
    if (_securityAssessment == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Assessment'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _securityAssessment!.overallSecurityLevel.icon,
                    color: _securityAssessment!.overallSecurityLevel.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Overall Security: ${_securityAssessment!.overallSecurityLevel.label}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Recommendations:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...(_securityAssessment!.recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(rec)),
                  ],
                ),
              ))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Security assessment data structure
class SecurityAssessment {
  final Map<String, Map<String, dynamic>> credentialAssessments;
  final SecurityLevel overallSecurityLevel;
  final List<String> recommendations;

  const SecurityAssessment({
    required this.credentialAssessments,
    required this.overallSecurityLevel,
    required this.recommendations,
  });
}

/// Security levels for credential operations
enum SecurityLevel {
  unknown(Icons.help, Colors.grey, 'Unknown'),
  low(Icons.warning, Colors.red, 'Low Security'),
  medium(Icons.verified_user, Colors.orange, 'Medium Security'),
  high(Icons.security, Colors.green, 'High Security');

  const SecurityLevel(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;
}
