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
import 'base_credential_card.dart';

/// Placeholder card for mobile Driver's License (mDL)
/// Similar to Apple Cash card in Apple Wallet - shows promotional content when no mDL is issued
class MdlPlaceholderCard extends StatelessWidget {
  final bool hasIssuedMdl;
  final VoidCallback? onTap;

  const MdlPlaceholderCard({super.key, this.hasIssuedMdl = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return BaseCredentialCard(
      gradientColors: const [
        Color(0xFF1C1C1E), // Dark background similar to Apple Cash
        Color(0xFF2C2C2E),
      ],
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Service logo/text at top
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.credit_card,
                  size: 20,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mobile Driver\'s License',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Main text
          if (!hasIssuedMdl) ...[
            const Text(
              'Get Your mDL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Store your driver\'s license securely on your phone',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ] else ...[
            const Text(
              'mDL Ready',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to view your mobile driver\'s license',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
