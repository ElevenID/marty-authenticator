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
import '../../../../model/promotional_credential.dart';
import '../../../../utils/riverpod/providers/credentials_provider.dart';
import 'base_credential_card.dart';

/// Card widget for displaying promotional credentials using the same design as regular credentials
class PromotionalCredentialCard extends ConsumerStatefulWidget {
  final PromotionalCredential credential;
  final VoidCallback? onTap;
  final bool isExpanded;

  const PromotionalCredentialCard({
    super.key,
    required this.credential,
    this.onTap,
    this.isExpanded = true,
  });

  @override
  ConsumerState<PromotionalCredentialCard> createState() =>
      _PromotionalCredentialCardState();
}

class _PromotionalCredentialCardState
    extends ConsumerState<PromotionalCredentialCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _dismissController;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _heightAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _dismissController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dismissController,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          height: _isDismissing ? _heightAnimation.value * 200 : null,
          curve: Curves.easeInOut,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: BaseCredentialCard(
              gradientColors: widget.credential.gradientColors,
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with dismiss button
                  Row(
                    children: [
                      Icon(
                        widget.credential.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _isDismissing ? null : () => _dismissCard(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        tooltip: 'Dismiss',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Title and subtitle
                  Text(
                    widget.credential.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  Text(
                    widget.credential.subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    widget.credential.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                    maxLines: widget.isExpanded ? null : 2,
                    overflow: widget.isExpanded ? null : TextOverflow.ellipsis,
                  ),

                  if (widget.isExpanded) ...[
                    const SizedBox(height: 16),

                    // Action button
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Learn More',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _dismissCard() async {
    if (_isDismissing) return;

    setState(() {
      _isDismissing = true;
    });

    // Start dismiss animation
    await _dismissController.forward();

    // Dismiss the card from the provider
    if (mounted) {
      ref
          .read(credentialsProvider.notifier)
          .dismissPromotionalCard(widget.credential.id);
    }
  }
}
