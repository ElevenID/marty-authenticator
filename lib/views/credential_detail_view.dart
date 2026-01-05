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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import '../models/credentials.dart';
import 'main_view/main_view_widgets/card_widgets/verifiable_credential_card.dart'
    show VerifiableCredentialCard;
import 'main_view/main_view_widgets/card_widgets/mdoc_credential_card.dart'
    show MDocCredentialCard;

/// Detail view for verifiable credentials with Apple Wallet-like presentation
class CredentialDetailView extends StatefulWidget {
  final dynamic credential; // Can be VerifiableCredential or MDocCredential
  final String? heroTag;

  const CredentialDetailView({
    super.key,
    required this.credential,
    this.heroTag,
  });

  @override
  State<CredentialDetailView> createState() => _CredentialDetailViewState();
}

class _CredentialDetailViewState extends State<CredentialDetailView>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _showFullDetails = false;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
    );

    // Start animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: GestureDetector(
        onTap: () => _closeView(),
        child: Stack(
          children: [
            // Background overlay
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(color: Colors.black.withOpacity(0.7)),
            ),

            // Main content
            SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: const EdgeInsets.only(top: 100),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    _buildHeader(),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildContent(),
                      ),
                    ),

                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title;
    String subtitle;

    if (widget.credential is VerifiableCredential) {
      final vc = widget.credential as VerifiableCredential;
      title = vc.credentialType;
      subtitle = vc.issuerName;
    } else if (widget.credential is MDocCredential) {
      final mdoc = widget.credential as MDocCredential;
      title = mdoc.documentType;
      subtitle = mdoc.issuingAuthority;
    } else {
      title = 'Credential Details';
      subtitle = 'Unknown Type';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _closeView(),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.credential is VerifiableCredential) {
      return _buildVerifiableCredentialDetails();
    } else if (widget.credential is MDocCredential) {
      return _buildMDocDetails();
    } else {
      return const Text('Unknown credential type');
    }
  }

  Widget _buildVerifiableCredentialDetails() {
    final vc = widget.credential as VerifiableCredential;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card preview
        VerifiableCredentialCard(credential: vc, isExpanded: false),

        const SizedBox(height: 24),

        // Toggle for detailed view
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Show Technical Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Switch(
              value: _showFullDetails,
              onChanged: (value) {
                setState(() => _showFullDetails = value);
                HapticFeedback.lightImpact();
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Basic info
        _buildInfoSection('Credential Information', [
          _buildInfoItem('Subject', vc.displayName),
          _buildInfoItem('Type', vc.credentialType),
          _buildInfoItem('Issuer', vc.issuerName),
          _buildInfoItem('Issue Date', _formatDate(vc.issuanceDate)),
          if (vc.expirationDate != null)
            _buildInfoItem('Expiry Date', _formatDate(vc.expirationDate!)),
          _buildInfoItem('Status', vc.isValid ? 'Valid' : 'Invalid'),
        ]),

        if (_showFullDetails) ...[
          const SizedBox(height: 24),
          _buildInfoSection('Technical Details', [
            _buildInfoItem('Credential ID', vc.id),
            _buildInfoItem('Issuer DID', vc.issuer['id']?.toString() ?? 'N/A'),
            _buildInfoItem(
              'Subject ID',
              vc.credentialSubject['id']?.toString() ?? 'N/A',
            ),
            if (vc.proof != null) ...[
              _buildInfoItem(
                'Proof Type',
                vc.proof!['type']?.toString() ?? 'N/A',
              ),
              _buildInfoItem(
                'Verification Method',
                vc.proof!['verificationMethod']?.toString() ?? 'N/A',
              ),
            ],
          ]),

          const SizedBox(height: 24),
          _buildJsonSection('Full Credential (JSON)', {
            'id': vc.id,
            'type': vc.types,
            'issuer': vc.issuer,
            'credentialSubject': vc.credentialSubject,
            'issuanceDate': vc.issuanceDate,
            if (vc.expirationDate != null) 'expirationDate': vc.expirationDate,
            if (vc.proof != null) 'proof': vc.proof,
            if (vc.context != null) '@context': vc.context,
          }),
        ],
      ],
    );
  }

  Widget _buildMDocDetails() {
    final mdoc = widget.credential as MDocCredential;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card preview
        MDocCredentialCard(credential: mdoc, isExpanded: false),

        const SizedBox(height: 24),

        // Basic info
        _buildInfoSection('Document Information', [
          _buildInfoItem('Holder', mdoc.holderName),
          _buildInfoItem('Document Type', mdoc.documentType),
          _buildInfoItem('Document Number', mdoc.documentNumber),
          _buildInfoItem('Issuing Authority', mdoc.issuingAuthority),
          if (mdoc.age != null) _buildInfoItem('Age', '${mdoc.age} years'),
          if (mdoc.issueDate != null)
            _buildInfoItem(
              'Issue Date',
              _formatDate(mdoc.issueDate!.toIso8601String()),
            ),
          if (mdoc.expiryDate != null)
            _buildInfoItem(
              'Expiry Date',
              _formatDate(mdoc.expiryDate!.toIso8601String()),
            ),
          _buildInfoItem('Status', mdoc.isValid ? 'Valid' : 'Invalid'),
          _buildInfoItem('Standard', 'ISO 18013-5'),
        ]),

        if (_showFullDetails) ...[
          const SizedBox(height: 24),
          _buildInfoSection('Technical Details', [
            _buildInfoItem('Document Type ID', mdoc.docType),
          ]),
        ],
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonSection(String title, Map<String, dynamic> data) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'JSON Data',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('JSON copied to clipboard'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  jsonStr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _shareCredential(),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _verifyCredential(),
              icon: const Icon(Icons.verified),
              label: const Text('Verify'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _closeView() {
    _slideController.reverse().then((_) {
      Navigator.of(context).pop();
    });
  }

  void _shareCredential() {
    HapticFeedback.lightImpact();
    // TODO: Implement credential sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share credential functionality coming soon...'),
      ),
    );
  }

  void _verifyCredential() {
    HapticFeedback.lightImpact();
    // TODO: Implement credential verification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verify credential functionality coming soon...'),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
