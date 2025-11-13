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

import 'base_credential_card.dart';
import '../../../../utils/customization/credential_card_theme.dart';

/// Model for W3C Verifiable Credential
class VerifiableCredential {
  final String id;
  final List<String> type;
  final Map<String, dynamic> issuer;
  final Map<String, dynamic> credentialSubject;
  final String issuanceDate;
  final String? expirationDate;
  final Map<String, dynamic>? proof;
  final List<String>? context;
  final Map<String, dynamic>? credentialStatus;

  VerifiableCredential({
    required this.id,
    required this.type,
    required this.issuer,
    required this.credentialSubject,
    required this.issuanceDate,
    this.expirationDate,
    this.proof,
    this.context,
    this.credentialStatus,
  });

  factory VerifiableCredential.fromJson(Map<String, dynamic> json) {
    return VerifiableCredential(
      id: json['id'] ?? '',
      type: List<String>.from(json['type'] ?? ['VerifiableCredential']),
      issuer: json['issuer'] is String
          ? {'id': json['issuer']}
          : Map<String, dynamic>.from(json['issuer'] ?? {}),
      credentialSubject: Map<String, dynamic>.from(
        json['credentialSubject'] ?? {},
      ),
      issuanceDate: json['issuanceDate'] ?? '',
      expirationDate: json['expirationDate'],
      proof: json['proof'] != null
          ? Map<String, dynamic>.from(json['proof'])
          : null,
      context: json['@context'] != null
          ? List<String>.from(json['@context'])
          : null,
      credentialStatus: json['credentialStatus'] != null
          ? Map<String, dynamic>.from(json['credentialStatus'])
          : null,
    );
  }

  String get issuerName {
    if (issuer.containsKey('name')) {
      return issuer['name'] as String;
    }

    final issuerId = issuer['id'] as String? ?? '';
    if (issuerId.startsWith('did:web:')) {
      return issuerId.replaceFirst('did:web:', '').split('.').first;
    } else if (issuerId.startsWith('did:')) {
      return issuerId.split(':')[1];
    }

    return 'Unknown Issuer';
  }

  String get subjectName {
    final subject = credentialSubject;
    return subject['name'] as String? ??
        subject['given_name'] as String? ??
        subject['id'] as String? ??
        'Unknown Subject';
  }

  String get credentialType {
    return type.where((t) => t != 'VerifiableCredential').firstOrNull ??
        'Credential';
  }

  bool get isExpired {
    if (expirationDate == null) return false;
    return DateTime.parse(expirationDate!).isBefore(DateTime.now());
  }

  bool get isValid {
    return proof != null && !isExpired;
  }

  String get status {
    if (!isValid) return 'invalid';
    if (isExpired) return 'expired';
    return 'valid';
  }
}

/// Widget for displaying W3C Verifiable Credentials as cards
class VerifiableCredentialCard extends StatelessWidget {
  final VerifiableCredential credential;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onShare;
  final VoidCallback? onVerify;

  const VerifiableCredentialCard({
    super.key,
    required this.credential,
    this.isExpanded = false,
    this.onTap,
    this.onLongPress,
    this.onShare,
    this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final cardTheme = context.credentialCardTheme;

    return BaseCredentialCard(
      gradientColors: cardTheme.getGradientForCredentialType(
        credential.credentialType,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with issuer and credential type
          CredentialCardHeader(
            issuer: credential.issuerName,
            label: credential.credentialType,
            fallbackIcon: _getCredentialIcon(),
          ),

          const SizedBox(height: 16),

          // Main content - subject name
          CredentialCardFooter(
            primaryValue: credential.subjectName,
            secondaryValue: _formatDate(credential.issuanceDate),
            actionWidget: _buildStatusIndicator(cardTheme),
            onPrimaryTap: onTap,
            additionalActions: isExpanded
                ? [
                    _buildActionButton(
                      icon: Icons.share,
                      label: 'Share',
                      onTap: onShare,
                    ),
                    _buildActionButton(
                      icon: Icons.verified,
                      label: 'Verify',
                      onTap: onVerify,
                    ),
                  ]
                : null,
          ),

          // Expanded details
          if (isExpanded) ...[const SizedBox(height: 16), _buildExpandedInfo()],
        ],
      ),
    );
  }

  List<Color> _getGradientColors(BuildContext context) {
    // Fallback - should now use the theme
    return context.credentialCardTheme.getGradientForCredentialType(
      credential.credentialType,
    );
  }

  IconData _getCredentialIcon() {
    final credType = credential.credentialType.toLowerCase();

    if (credType.contains('degree') || credType.contains('education')) {
      return Icons.school;
    } else if (credType.contains('license') || credType.contains('driver')) {
      return Icons.drive_eta;
    } else if (credType.contains('id') || credType.contains('identity')) {
      return Icons.badge;
    } else if (credType.contains('certificate')) {
      return Icons.workspace_premium;
    } else if (credType.contains('membership')) {
      return Icons.card_membership;
    } else if (credType.contains('employment') || credType.contains('work')) {
      return Icons.work;
    } else {
      return Icons.security;
    }
  }

  Widget _buildStatusIndicator(CredentialCardTheme cardTheme) {
    Color statusColor = cardTheme.getStatusColor(credential.status);
    IconData statusIcon;

    if (!credential.isValid) {
      statusIcon = Icons.error;
    } else if (credential.isExpired) {
      statusIcon = Icons.schedule;
    } else {
      statusIcon = Icons.verified;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Icon(statusIcon, color: statusColor, size: 16),
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
          _buildInfoRow('Credential ID', credential.id),
          const SizedBox(height: 8),
          _buildInfoRow('Issuer DID', credential.issuer['id'] ?? 'N/A'),
          if (credential.expirationDate != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Expires', _formatDate(credential.expirationDate!)),
          ],
          if (credential.proof != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Proof Type', credential.proof!['type'] ?? 'N/A'),
          ],
          const SizedBox(height: 8),
          _buildInfoRow('Status', credential.isValid ? 'Valid' : 'Invalid'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
