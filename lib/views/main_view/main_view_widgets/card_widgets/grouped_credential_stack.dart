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

import '../../../../model/promotional_credential.dart';
import '../../../../utils/customization/credential_card_theme.dart';
import 'verifiable_credential_card.dart';
import 'mdoc_credential_card.dart';
import 'promotional_credential_card.dart';

/// Data class for grouped credentials from the same issuer
class CredentialGroup {
  final String issuerName;
  final List<VerifiableCredential> verifiableCredentials;
  final List<MDocCredential> mDocCredentials;
  final List<PromotionalCredential> promotionalCredentials;
  final bool isPromotional;

  CredentialGroup({
    required this.issuerName,
    this.verifiableCredentials = const [],
    this.mDocCredentials = const [],
    this.promotionalCredentials = const [],
    this.isPromotional = false,
  });

  int get totalCount =>
      verifiableCredentials.length +
      mDocCredentials.length +
      promotionalCredentials.length;
  bool get hasSingle => totalCount == 1;
  bool get hasMultiple => totalCount > 1;

  /// Get all credentials as a mixed list for iteration
  List<dynamic> get allCredentials => [
    ...promotionalCredentials,
    ...verifiableCredentials,
    ...mDocCredentials,
  ];

  /// Get the primary (most recent or first) credential for display
  dynamic get primaryCredential {
    if (promotionalCredentials.isNotEmpty) {
      return promotionalCredentials.first;
    }
    if (verifiableCredentials.isNotEmpty) {
      return verifiableCredentials.first;
    }
    if (mDocCredentials.isNotEmpty) {
      return mDocCredentials.first;
    }
    return null;
  }
}

/// Widget that displays grouped credentials as a stack with horizontal scrolling
class GroupedCredentialStack extends StatefulWidget {
  final CredentialGroup group;
  final Function(dynamic credential) onCredentialTap;
  final Function(VerifiableCredential credential)? onShare;
  final Function(VerifiableCredential credential)? onVerify;
  final Function(MDocCredential credential)? onPresent;
  final Function(MDocCredential credential, int age)? onAgeVerify;

  const GroupedCredentialStack({
    super.key,
    required this.group,
    required this.onCredentialTap,
    this.onShare,
    this.onVerify,
    this.onPresent,
    this.onAgeVerify,
  });

  @override
  State<GroupedCredentialStack> createState() => _GroupedCredentialStackState();
}

class _GroupedCredentialStackState extends State<GroupedCredentialStack> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Extract gradient colors from the primary credential for consistent theming
  List<Color> _getPrimaryCredentialColors(BuildContext context) {
    final credential = widget.group.primaryCredential;
    if (credential == null) return [Colors.grey.shade200, Colors.grey.shade300];

    final theme = context.credentialCardTheme;

    if (credential is VerifiableCredential) {
      return theme.getGradientForCredentialType(credential.type.first);
    } else if (credential is MDocCredential) {
      return theme.getGradientForCredentialType(credential.docType);
    }

    return [Colors.grey.shade200, Colors.grey.shade300];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.group.hasSingle) {
      return _buildSingleCredential();
    }

    return _buildStackedCredentials();
  }

  Widget _buildSingleCredential() {
    final credential = widget.group.primaryCredential;
    if (credential == null) return const SizedBox.shrink();

    Widget credentialCard;

    if (credential is VerifiableCredential) {
      credentialCard = VerifiableCredentialCard(
        credential: credential,
        isExpanded: false,
        onTap: () => widget.onCredentialTap(credential),
        onShare: () => widget.onShare?.call(credential),
        onVerify: () => widget.onVerify?.call(credential),
      );
    } else if (credential is MDocCredential) {
      credentialCard = MDocCredentialCard(
        credential: credential,
        isExpanded: false,
        onTap: () => widget.onCredentialTap(credential),
        onPresent: () => widget.onPresent?.call(credential),
        onAgeVerify: (age) => widget.onAgeVerify?.call(credential, age),
      );
    } else {
      return const SizedBox.shrink();
    }

    // Ensure consistent minimum height and left alignment
    return Container(
      constraints: BoxConstraints(minHeight: 180, maxHeight: 220),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: credentialCard,
    );
  }

  Widget _buildStackedCredentials() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: BoxConstraints(minHeight: 180, maxHeight: 220),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stack indicator and issuer info
              _buildStackHeader(),
              const SizedBox(height: 4),

              // Horizontally scrollable stacked card view
              Expanded(child: ClipRect(child: _buildScrollableStack())),

              // Page indicators
              const SizedBox(height: 3),
              SizedBox(height: 12, child: _buildPageIndicators()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStackHeader() {
    return Row(
      children: [
        // Stack icon indicating multiple cards
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.layers,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.group.totalCount}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Issuer name
        Expanded(
          child: Text(
            widget.group.issuerName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Swipe hint icon
        Icon(Icons.swipe, color: Colors.grey.withOpacity(0.6), size: 20),
      ],
    );
  }

  Widget _buildScrollableStack() {
    return Builder(
      builder: (context) {
        final gradientColors = _getPrimaryCredentialColors(context);
        final stackColor = gradientColors.first.withOpacity(0.15);
        final borderColor = gradientColors.last.withOpacity(0.25);

        return Stack(
          children: [
            // Background cards to create stack effect (reduced for side scroll)
            for (int i = 1; i < widget.group.totalCount && i <= 2; i++)
              Transform.translate(
                offset: Offset(i * 2.5, i * 1.5),
                child: Container(
                  height: 170, // Adjusted to fit within 220px container
                  decoration: BoxDecoration(
                    color: stackColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                ),
              ),

            // Scrollable credentials
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.group.totalCount,
              itemBuilder: (context, index) {
                final credential = widget.group.allCredentials[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildCredentialWidget(credential),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildCredentialWidget(dynamic credential) {
    if (credential == null) return const SizedBox.shrink();

    Widget credentialCard;

    if (credential is PromotionalCredential) {
      credentialCard = PromotionalCredentialCard(
        credential: credential,
        isExpanded: false, // Never expand in stack view
        onTap: () => widget.onCredentialTap(credential),
      );
    } else if (credential is VerifiableCredential) {
      credentialCard = VerifiableCredentialCard(
        credential: credential,
        isExpanded: false, // Never expand in stack view
        onTap: () => widget.onCredentialTap(credential),
        onShare: () => widget.onShare?.call(credential),
        onVerify: () => widget.onVerify?.call(credential),
      );
    } else if (credential is MDocCredential) {
      credentialCard = MDocCredentialCard(
        credential: credential,
        isExpanded: false, // Never expand in stack view
        onTap: () => widget.onCredentialTap(credential),
        onPresent: () => widget.onPresent?.call(credential),
        onAgeVerify: (age) => widget.onAgeVerify?.call(credential, age),
      );
    } else {
      return const SizedBox.shrink();
    }

    // Allow flexible height while maintaining consistent layout
    return credentialCard;
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.group.totalCount,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentIndex
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}
