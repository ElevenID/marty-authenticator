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

/// Model for mDoc/MDL credentials (ISO 18013-5 compliant)
class MDocCredential {
  final String docType;
  final Map<String, dynamic> issuerSigned;
  final Map<String, dynamic> deviceSigned;
  final String? portrait;
  final DateTime? issueDate;
  final DateTime? expiryDate;

  MDocCredential({
    required this.docType,
    required this.issuerSigned,
    required this.deviceSigned,
    this.portrait,
    this.issueDate,
    this.expiryDate,
  });

  factory MDocCredential.fromCbor(Map<String, dynamic> cborData) {
    return MDocCredential(
      docType: cborData['docType'] ?? 'org.iso.18013.5.1.mDL',
      issuerSigned: Map<String, dynamic>.from(cborData['issuerSigned'] ?? {}),
      deviceSigned: Map<String, dynamic>.from(cborData['deviceSigned'] ?? {}),
      portrait: cborData['portrait'],
      issueDate: cborData['issue_date'] != null
          ? DateTime.parse(cborData['issue_date'])
          : null,
      expiryDate: cborData['expiry_date'] != null
          ? DateTime.parse(cborData['expiry_date'])
          : null,
    );
  }

  String get documentType {
    switch (docType) {
      case 'org.iso.18013.5.1.mDL':
        return 'Mobile Driving License';
      case 'org.iso.18013.5.1.mID':
        return 'Mobile ID';
      case 'org.iso.18013.5.1.mPassport':
        return 'Mobile Passport';
      default:
        return 'Mobile Document';
    }
  }

  String get holderName {
    final nameSpace = issuerSigned['nameSpaces'] as Map<String, dynamic>?;
    final personalDataRaw = nameSpace?['org.iso.18013.5.1'];

    // Handle both List and Map structures safely
    if (personalDataRaw is List<dynamic>) {
      for (final item in personalDataRaw) {
        final data = item as Map<String, dynamic>?;
        if (data?['elementIdentifier'] == 'given_name' ||
            data?['elementIdentifier'] == 'family_name') {
          return '${data?['elementValue'] ?? 'Unknown'} User';
        }
      }
    } else if (personalDataRaw is Map<String, dynamic>) {
      // Handle map-based structure
      final givenName = personalDataRaw['given_name'];
      final familyName = personalDataRaw['family_name'];
      if (givenName != null || familyName != null) {
        return '${givenName ?? familyName ?? 'Unknown'} User';
      }
    }

    return 'Document Holder';
  }

  String get issuingAuthority {
    final nameSpace = issuerSigned['nameSpaces'] as Map<String, dynamic>?;
    final personalDataRaw = nameSpace?['org.iso.18013.5.1'];

    // Handle both List and Map structures safely
    if (personalDataRaw is List<dynamic>) {
      for (final item in personalDataRaw) {
        final data = item as Map<String, dynamic>?;
        if (data?['elementIdentifier'] == 'issuing_authority') {
          return data?['elementValue'] ?? 'Unknown Authority';
        }
      }
    } else if (personalDataRaw is Map<String, dynamic>) {
      // Handle map-based structure
      final authority = personalDataRaw['issuing_authority'];
      if (authority != null) {
        return authority.toString();
      }
    }

    return 'Issuing Authority';
  }

  String get documentNumber {
    final nameSpace = issuerSigned['nameSpaces'] as Map<String, dynamic>?;
    final personalDataRaw = nameSpace?['org.iso.18013.5.1'];

    // Handle both List and Map structures safely
    if (personalDataRaw is List<dynamic>) {
      for (final item in personalDataRaw) {
        final data = item as Map<String, dynamic>?;
        if (data?['elementIdentifier'] == 'document_number') {
          return data?['elementValue'] ?? 'Unknown';
        }
      }
    } else if (personalDataRaw is Map<String, dynamic>) {
      // Handle map-based structure
      final docNumber = personalDataRaw['document_number'];
      if (docNumber != null) {
        return docNumber.toString();
      }
    }

    return '••••••••';
  }

  int? get age {
    final nameSpace = issuerSigned['nameSpaces'] as Map<String, dynamic>?;
    final personalDataRaw = nameSpace?['org.iso.18013.5.1'];

    // Handle both List and Map structures safely
    if (personalDataRaw is List<dynamic>) {
      for (final item in personalDataRaw) {
        final data = item as Map<String, dynamic>?;
        if (data?['elementIdentifier'] == 'birth_date') {
          final birthDate = data?['elementValue'];
          if (birthDate != null) {
            final birth = DateTime.parse(birthDate);
            final now = DateTime.now();
            return now.year - birth.year;
          }
        }
      }
    } else if (personalDataRaw is Map<String, dynamic>) {
      // Handle map-based structure
      final birthDate = personalDataRaw['birth_date'];
      if (birthDate != null) {
        try {
          final birth = DateTime.parse(birthDate.toString());
          final now = DateTime.now();
          return now.year - birth.year;
        } catch (e) {
          // Invalid date format
          return null;
        }
      }
    }

    return null;
  }

  bool get isExpired {
    return expiryDate?.isBefore(DateTime.now()) ?? false;
  }

  bool get isValid {
    return !isExpired && issuerSigned.isNotEmpty;
  }

  bool? get ageOver21 {
    return age != null ? age! >= 21 : null;
  }
}

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
