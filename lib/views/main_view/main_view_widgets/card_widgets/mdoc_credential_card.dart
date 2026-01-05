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
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_credential_card.dart';
import '../../../../utils/customization/credential_card_theme.dart';

// Re-export MDocCredential from canonical models location
export '../../../../models/mdoc_credential.dart' show MDocCredential;
import '../../../../models/mdoc_credential.dart';

/// Widget for displaying mDoc/MDL credentials as cards
class MDocCredentialCard extends StatelessWidget {
  final MDocCredential credential;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPresent;
  final Function(int)? onAgeVerify;

  const MDocCredentialCard({
    super.key,
    required this.credential,
    this.isExpanded = false,
    this.onTap,
    this.onLongPress,
    this.onPresent,
    this.onAgeVerify,
  });

  @override
  Widget build(BuildContext context) {
    final cardTheme = context.credentialCardTheme;

    return BaseCredentialCard(
      gradientColors: cardTheme.getGradientForCredentialType(
        credential.docType,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with issuer authority and document type
          CredentialCardHeader(
            issuer: credential.issuingAuthority,
            label: _getDocTypeDisplayName(),
            fallbackIcon: _getDocTypeIcon(),
          ),

          const SizedBox(height: 16),

          // Main content area
          Row(
            children: [
              // Portrait/photo (if available)
              if (credential.portrait != null) _buildPortrait(),

              // Main information
              Expanded(
                child: CredentialCardFooter(
                  primaryValue: _getDisplayName(),
                  secondaryValue: _getSecondaryInfo(),
                  actionWidget: _buildStatusIndicator(cardTheme),
                  onPrimaryTap: onTap,
                  additionalActions: isExpanded
                      ? [
                          _buildActionButton(
                            icon: Icons.share,
                            label: 'Present',
                            onTap: onPresent,
                          ),
                          if (credential.ageOver21 != null)
                            _buildActionButton(
                              icon: Icons.cake,
                              label: '21+',
                              onTap: () => onAgeVerify?.call(21),
                            ),
                        ]
                      : null,
                ),
              ),
            ],
          ),

          // Expanded details
          if (isExpanded) ...[const SizedBox(height: 16), _buildExpandedInfo()],
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(CredentialCardTheme cardTheme) {
    Color statusColor = cardTheme.getStatusColor(
      credential.isExpired
          ? 'expired'
          : (credential.isValid ? 'valid' : 'invalid'),
    );
    IconData statusIcon;

    if (!credential.isValid) {
      statusIcon = Icons.error;
    } else if (credential.isExpired) {
      statusIcon = Icons.schedule;
    } else {
      statusIcon = Icons.verified;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Icon(statusIcon, color: statusColor, size: 14),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow('Document Type', credential.docType),
          if (credential.issueDate != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Issue Date', _formatDate(credential.issueDate!)),
          ],
          if (credential.expiryDate != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Expiry Date', _formatDate(credential.expiryDate!)),
          ],
          const SizedBox(height: 8),
          _buildInfoRow('Status', credential.isValid ? 'Valid' : 'Invalid'),
          const SizedBox(height: 8),
          _buildInfoRow('Standard', 'ISO 18013-5'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Uint8List _decodePortrait(String base64Portrait) {
    try {
      // Remove data URL prefix if present
      final cleanBase64 = base64Portrait.split(',').last;
      return base64Decode(cleanBase64);
    } catch (e) {
      return Uint8List(0);
    }
  }

  String _getDocTypeDisplayName() {
    switch (credential.docType) {
      case 'org.iso.18013.5.1.mDL':
        return 'Driving License';
      case 'org.iso.18013.5.1.mID':
        return 'Identity Document';
      case 'org.iso.18013.5.1.mPassport':
        return 'Passport';
      default:
        return 'Mobile Document';
    }
  }

  IconData _getDocTypeIcon() {
    switch (credential.docType) {
      case 'org.iso.18013.5.1.mDL':
        return Icons.drive_eta;
      case 'org.iso.18013.5.1.mID':
        return Icons.credit_card;
      case 'org.iso.18013.5.1.mPassport':
        return Icons.flight;
      default:
        return Icons.document_scanner;
    }
  }

  Widget _buildPortrait() {
    if (credential.portrait == null) {
      return const SizedBox(
        width: 60,
        height: 80,
        child: Icon(Icons.person, size: 40, color: Colors.white54),
      );
    }

    return Container(
      width: 60,
      height: 80,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.memory(
          _decodePortrait(credential.portrait!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.person, size: 40, color: Colors.white54),
        ),
      ),
    );
  }

  String _getDisplayName() {
    return credential.holderName;
  }

  String _getSecondaryInfo() {
    final expiryText = credential.expiryDate != null
        ? 'Expires ${_formatDate(credential.expiryDate!)}'
        : 'No expiry';
    return expiryText;
  }
}
