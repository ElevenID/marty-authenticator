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

import '../../../../widgets/horizontal_stack.dart';
import '../../../../model/promotional_credential.dart';
import 'verifiable_credential_card.dart';
import 'mdoc_credential_card.dart';
import 'promotional_credential_card.dart';
import 'grouped_credential_stack.dart';

/// Widget that displays credentials using horizontal stacking effect
/// Cards are stacked sideways (left to right) with interactive selection
class HorizontalStackedCredentials extends StatefulWidget {
  final CredentialGroup group;
  final Function(dynamic credential) onCredentialTap;
  final Function(VerifiableCredential credential)? onShare;
  final Function(VerifiableCredential credential)? onVerify;
  final Function(MDocCredential credential)? onPresent;
  final Function(MDocCredential credential, int age)? onAgeVerify;

  const HorizontalStackedCredentials({
    super.key,
    required this.group,
    required this.onCredentialTap,
    this.onShare,
    this.onVerify,
    this.onPresent,
    this.onAgeVerify,
  });

  @override
  State<HorizontalStackedCredentials> createState() =>
      _HorizontalStackedCredentialsState();
}

class _HorizontalStackedCredentialsState
    extends State<HorizontalStackedCredentials>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
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

  void _selectCard(int index) {
    if (_selectedIndex == index) {
      // Double tap - trigger action
      widget.onCredentialTap(widget.group.allCredentials[index]);
    } else {
      // Select card
      setState(() {
        _selectedIndex = index;
      });
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildHorizontalStackedCredentials();
  }

  Widget _buildHorizontalStackedCredentials() {
    const double stackSpacing =
        15.0; // Horizontal spacing between stacked cards
    final credentials = widget.group.allCredentials;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      height: 200, // Reduced height to prevent overflow
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 320 + (credentials.length - 1) * stackSpacing,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Build cards from back to front so front card is interactive
              for (int i = credentials.length - 1; i >= 0; i--)
                AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, child) {
                    // Calculate dynamic spacing when selected
                    double dynamicSpacing = stackSpacing;
                    bool isSelected = _selectedIndex == i;

                    if (isSelected) {
                      // Selected card gets slightly more separation
                      dynamicSpacing += (5 * _expandAnimation.value);
                    }

                    return HorizontalStack(
                      dx: dynamicSpacing,
                      order: i,
                      child: GestureDetector(
                        onTap: () => _selectCard(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // Add perspective
                            ..rotateY(
                              isSelected ? 0 : -0.1,
                            ), // Slight rotation for depth
                          child: AnimatedScale(
                            scale: isSelected ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: _buildCredentialWidget(credentials[i], i),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialWidget(dynamic credential, int index) {
    Widget credentialCard;
    bool isSelected = _selectedIndex == index;

    if (credential is VerifiableCredential) {
      credentialCard = VerifiableCredentialCard(
        credential: credential,
        isExpanded: isSelected,
        onTap: () {}, // Handled by parent gesture detector
        onShare: () => widget.onShare?.call(credential),
        onVerify: () => widget.onVerify?.call(credential),
      );
    } else if (credential is MDocCredential) {
      credentialCard = MDocCredentialCard(
        credential: credential,
        isExpanded: isSelected,
        onTap: () {}, // Handled by parent gesture detector
        onPresent: () => widget.onPresent?.call(credential),
        onAgeVerify: (age) => widget.onAgeVerify?.call(credential, age),
      );
    } else if (credential is PromotionalCredential) {
      credentialCard = PromotionalCredentialCard(
        credential: credential,
        isExpanded: isSelected,
        onTap: () {}, // Handled by parent gesture detector
      );
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: 300, // Fixed width for horizontal stacking
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.2 : 0.1),
            blurRadius: isSelected ? 12 : 8,
            offset: Offset(0, isSelected ? 6 : 4),
          ),
        ],
      ),
      child: credentialCard,
    );
  }
}
