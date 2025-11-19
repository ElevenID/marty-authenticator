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

import '../card_widgets/base_credential_card.dart';

/// Widget for Mobile Driver's License placeholder
class MdlPlaceholder extends StatelessWidget {
  final VoidCallback onTap;

  const MdlPlaceholder({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCredentialCard(
      gradientColors: const [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with issuer and credential type
          CredentialCardHeader(
            issuer: 'Department of Motor Vehicles',
            label: 'Mobile Driver\'s License',
            fallbackIcon: Icons.add_card,
          ),

          const SizedBox(height: 16),

          // Main content - subject name
          CredentialCardFooter(
            primaryValue: 'Add to Wallet',
            secondaryValue: 'Tap to add your digital driver\'s license',
            actionWidget: Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.3),
              size: 16,
            ),
            onPrimaryTap: onTap,
          ),
        ],
      ),
    );
  }
}

/// Widget for Passport placeholder
class PassportPlaceholder extends StatelessWidget {
  final VoidCallback onTap;

  const PassportPlaceholder({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCredentialCard(
      gradientColors: const [Color(0xFF2E3F66), Color(0xFF1A1A2E)],
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with issuer and credential type
          CredentialCardHeader(
            issuer: 'State Passport Office',
            label: 'Passport',
            fallbackIcon: Icons.flight_takeoff,
          ),

          const SizedBox(height: 16),

          // Main content - subject name
          CredentialCardFooter(
            primaryValue: 'Add to Wallet',
            secondaryValue: 'Tap to add your digital passport',
            actionWidget: Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.3),
              size: 16,
            ),
            onPrimaryTap: onTap,
          ),
        ],
      ),
    );
  }
}