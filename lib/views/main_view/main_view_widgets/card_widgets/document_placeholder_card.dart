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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/verification_state_provider.dart';

class DocumentPlaceholderCard extends ConsumerWidget {
  const DocumentPlaceholderCard({
    required this.title,
    required this.description,
    required this.documentType,
    required this.issuer,
    required this.color,
    required this.icon,
    required this.onScan,
    this.extraMenuItem,
    super.key,
  });

  final String title;
  final String description;
  final String documentType;
  final String issuer;
  final Color color;
  final IconData icon;
  final VoidCallback onScan;
  final WidgetBuilder? extraMenuItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(verificationStateProvider);

    if (status == VerificationStatus.issued) {
      return const SizedBox.shrink();
    }

    final isPending = status == VerificationStatus.pendingApproval;
    return Container(
      height: 220.0,
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Center(
        child: Container(
          height: 220.0,
          width: 380.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            color: color,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: isPending ? null : onScan,
            borderRadius: BorderRadius.circular(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 30),
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPending ? 'Waiting for approval...' : description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCardMenu(context, ref),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCardMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white),
              title: const Text(
                'Card Details',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCardDetails(context, ref);
              },
            ),
            if (extraMenuItem case final buildItem?) buildItem(context),
            if (ref.watch(verificationStateProvider) ==
                VerificationStatus.pendingApproval)
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text(
                  'Cancel Verification',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(verificationStateProvider.notifier)
                      .setStatus(VerificationStatus.none);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCardDetails(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: $documentType',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text('Status:', style: TextStyle(color: Colors.white70)),
            Text(
              ref.watch(verificationStateProvider) ==
                      VerificationStatus.pendingApproval
                  ? 'Pending Approval'
                  : 'Not Submitted',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Issuer: $issuer',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
