/*
 * privacyIDEA Authenticator
 *
 * Author: Frank Merkel <frank.merkel@netknights.it>
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
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget to display expired credentials at the bottom of the tokens list
class ExpiredCredentialsWidget extends ConsumerStatefulWidget {
  const ExpiredCredentialsWidget({super.key});

  @override
  ConsumerState<ExpiredCredentialsWidget> createState() =>
      _ExpiredCredentialsWidgetState();
}

class _ExpiredCredentialsWidgetState
    extends ConsumerState<ExpiredCredentialsWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual expired credentials from provider when implemented
    final expiredCredentials = _getMockExpiredCredentials();

    if (expiredCredentials.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Expired Credentials',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${expiredCredentials.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _isExpanded
                ? Column(
                    children: [
                      const Divider(height: 1),
                      ...expiredCredentials.map(
                        (credential) => _buildExpiredCredentialTile(credential),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredCredentialTile(ExpiredCredentialData credential) {
    return InkWell(
      onTap: () {
        _showExpiredCredentialDetails(credential);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCredentialIcon(credential.type),
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    credential.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Expired ${_formatExpiredDate(credential.expiredDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCredentialIcon(String type) {
    switch (type.toLowerCase()) {
      case 'mdl':
      case 'driver_license':
        return Icons.credit_card;
      case 'degree':
      case 'education':
        return Icons.school;
      case 'certificate':
        return Icons.verified;
      case 'membership':
        return Icons.card_membership;
      case 'employment':
        return Icons.work;
      default:
        return Icons.badge;
    }
  }

  String _formatExpiredDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    }
  }

  void _showExpiredCredentialDetails(ExpiredCredentialData credential) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getCredentialIcon(credential.type),
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                credential.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${credential.type}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Expired: ${credential.expiredDate.toString().split(' ')[0]}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Issuer: ${credential.issuer}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (credential.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                credential.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showRenewOptions(credential);
            },
            child: const Text('Renew'),
          ),
        ],
      ),
    );
  }

  void _showRenewOptions(ExpiredCredentialData credential) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renew Credential'),
        content: Text(
          'To renew your ${credential.type.toLowerCase()}, please contact ${credential.issuer} or use their official renewal process.',
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

  // Mock data - replace with actual expired credentials provider when implemented
  List<ExpiredCredentialData> _getMockExpiredCredentials() {
    return [
      ExpiredCredentialData(
        id: '1',
        title: 'Driver\'s License',
        type: 'MDL',
        issuer: 'Department of Motor Vehicles',
        expiredDate: DateTime.now().subtract(const Duration(days: 30)),
        description: 'State-issued mobile driver\'s license',
      ),
      ExpiredCredentialData(
        id: '2',
        title: 'Professional Certificate',
        type: 'Certificate',
        issuer: 'Certification Authority',
        expiredDate: DateTime.now().subtract(const Duration(days: 90)),
        description: 'Professional certification credential',
      ),
    ];
  }
}

/// Data class for expired credentials
class ExpiredCredentialData {
  final String id;
  final String title;
  final String type;
  final String issuer;
  final DateTime expiredDate;
  final String description;

  const ExpiredCredentialData({
    required this.id,
    required this.title,
    required this.type,
    required this.issuer,
    required this.expiredDate,
    required this.description,
  });
}
