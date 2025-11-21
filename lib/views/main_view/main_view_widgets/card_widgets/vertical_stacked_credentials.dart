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

import '../../../../widgets/vertical_stack.dart';
import '../../../../model/promotional_credential.dart';
import 'verifiable_credential_card.dart';
import 'mdoc_credential_card.dart';
import 'promotional_credential_card.dart';
import 'grouped_credential_stack.dart';

/// Widget that displays credentials using vertical stacking effect similar to iOS Wallet
class VerticalStackedCredentials extends StatefulWidget {
  final CredentialGroup group;
  final Function(dynamic credential) onCredentialTap;
  final Function(VerifiableCredential credential)? onShare;
  final Function(VerifiableCredential credential)? onVerify;
  final Function(MDocCredential credential)? onPresent;
  final Function(MDocCredential credential, int age)? onAgeVerify;

  const VerticalStackedCredentials({
    super.key,
    required this.group,
    required this.onCredentialTap,
    this.onShare,
    this.onVerify,
    this.onPresent,
    this.onAgeVerify,
  });

  @override
  State<VerticalStackedCredentials> createState() =>
      _VerticalStackedCredentialsState();
}

class _VerticalStackedCredentialsState extends State<VerticalStackedCredentials>
    with TickerProviderStateMixin {
  int _expandedIndex = -1;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = -1;
        _animationController.reverse();
      } else {
        _expandedIndex = index;
        _animationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildVerticalStackedCredentials();
  }

  Widget _buildVerticalStackedCredentials() {
    const double stackSpacing = 20.0; // Vertical spacing between stacked cards
    final credentials = widget.group.allCredentials;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      height: 220, // Reduced height to prevent overflow
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Build cards from bottom to top so top card is interactive
          for (int i = credentials.length - 1; i >= 0; i--)
            AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                // Calculate dynamic spacing when expanded
                double dynamicSpacing = stackSpacing;
                if (_expandedIndex != -1 && i > _expandedIndex) {
                  // Cards below expanded card get pushed down more
                  dynamicSpacing = stackSpacing + (50 * _expandAnimation.value);
                }

                return VerticalStack(
                  dy: dynamicSpacing,
                  order: i,
                  child: GestureDetector(
                    onTap: () => _handleCardTap(i),
                    child: AnimatedScale(
                      scale: _expandedIndex == i ? 1.02 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: _buildCredentialWidget(credentials[i], i),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _handleCardTap(int index) {
    if (_expandedIndex == -1) {
      // No card expanded, expand this one
      _toggleExpanded(index);
    } else if (_expandedIndex == index) {
      // This card is expanded, either collapse or trigger action
      if (_animationController.value > 0.8) {
        // Card is fully expanded, trigger the main action
        widget.onCredentialTap(widget.group.allCredentials[index]);
      } else {
        // Card is expanding, just collapse it
        _toggleExpanded(index);
      }
    } else {
      // Different card is expanded, switch to this one
      _expandedIndex = index;
      _animationController.reset();
      _animationController.forward();
      setState(() {});
    }
  }

  Widget _buildCredentialWidget(dynamic credential, int index) {
    Widget credentialCard;
    bool isExpanded = _expandedIndex == index;

    if (credential is VerifiableCredential) {
      credentialCard = VerifiableCredentialCard(
        credential: credential,
        isExpanded: isExpanded,
        onTap: () {}, // Handled by parent gesture detector
        onShare: () => widget.onShare?.call(credential),
        onVerify: () => widget.onVerify?.call(credential),
      );
    } else if (credential is MDocCredential) {
      credentialCard = MDocCredentialCard(
        credential: credential,
        isExpanded: isExpanded,
        onTap: () {}, // Handled by parent gesture detector
        onPresent: () => widget.onPresent?.call(credential),
        onAgeVerify: (age) => widget.onAgeVerify?.call(credential, age),
      );
    } else if (credential is PromotionalCredential) {
      credentialCard = PromotionalCredentialCard(
        credential: credential,
        isExpanded: isExpanded,
        onTap: () {}, // Handled by parent gesture detector
      );
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: credentialCard,
    );
  }
}
