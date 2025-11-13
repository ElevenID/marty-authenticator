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

/// Data model for promotional cards
class PromoCard {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String buttonText;
  final IconData icon;
  final Color iconColor;
  final LinearGradient gradient;

  PromoCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.buttonText,
    required this.icon,
    required this.iconColor,
    required this.gradient,
  });
}

/// Apple Wallet-style demo view with authentic layout
class CredentialDemoView extends StatefulWidget {
  const CredentialDemoView({super.key});

  @override
  State<CredentialDemoView> createState() => _CredentialDemoViewState();
}

class _CredentialDemoViewState extends State<CredentialDemoView>
    with TickerProviderStateMixin {
  late List<PromoCard> _promoCards;
  late List<PromoCard> _allAvailableCards; // Pool of all possible cards
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, Animation<double>> _animations = {};
  final Map<String, AnimationController> _slideControllers = {};
  final Map<String, Animation<Offset>> _slideAnimations = {};

  @override
  void initState() {
    super.initState();
    _initializePromoCards();
  }

  @override
  void dispose() {
    // Dispose all animation controllers
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    for (var controller in _slideControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializePromoCards() {
    // Create a small pool of promotional cards to test collapse behavior
    _allAvailableCards = [
      // Welcome card - special first-time card
      PromoCard(
        id: 'welcome',
        title: 'WELCOME',
        subtitle: 'Welcome to Your Digital Wallet',
        description: 'Store and manage your credentials securely',
        buttonText: 'GET STARTED',
        icon: Icons.celebration,
        iconColor: Colors.pink,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF0F5), Color(0xFFFFF5F8)],
        ),
      ),
      PromoCard(
        id: 'promo_1',
        title: 'PRIVACYIDEA CARD',
        subtitle: 'Secure your digital identity',
        description: 'Get enhanced authentication',
        buttonText: 'LEARN MORE',
        icon: Icons.security,
        iconColor: Colors.blue,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF5F5F5)],
        ),
      ),
      PromoCard(
        id: 'promo_2',
        title: 'SECURITY UPDATE',
        subtitle: 'Enhanced protection available',
        description: 'Update your security settings',
        buttonText: 'UPDATE NOW',
        icon: Icons.shield,
        iconColor: Colors.green,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F5E8), Color(0xFFF0F8F0)],
        ),
      ),
      PromoCard(
        id: 'promo_3',
        title: 'NEW FEATURES',
        subtitle: 'Discover what\'s new',
        description: 'Explore latest capabilities',
        buttonText: 'EXPLORE',
        icon: Icons.star,
        iconColor: Colors.orange,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4E6), Color(0xFFFFF8F0)],
        ),
      ),
      PromoCard(
        id: 'promo_4',
        title: 'BIOMETRIC LOGIN',
        subtitle: 'Unlock with your face or finger',
        description: 'Enable biometric authentication',
        buttonText: 'ENABLE',
        icon: Icons.fingerprint,
        iconColor: Colors.purple,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3E5F5), Color(0xFFF8F5F9)],
        ),
      ),
    ];

    // Start with 4 cards including the welcome card
    _promoCards = _allAvailableCards.take(4).toList();

    // Note: Removed complex animations for now to fix touch issues
  }

  void _createAnimationsForCards(List<PromoCard> cards) {
    for (var card in cards) {
      if (!_animationControllers.containsKey(card.id)) {
        // Collapse/fade animation - starts visible (1.0), goes to hidden (0.0) when removing
        final controller = AnimationController(
          duration: const Duration(milliseconds: 500),
          vsync: this,
          value: 1.0, // Start fully visible
        );
        // Direct use of controller - 1.0 = visible, 0.0 = hidden
        final animation = controller;

        _animationControllers[card.id] = controller;
        _animations[card.id] = animation;

        // Slide-in animation (starts from right, slides to center)
        final slideController = AnimationController(
          duration: const Duration(milliseconds: 600),
          vsync: this,
          value: 1.0, // Start at end position (center)
        );
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(1.0, 0.0), // Start from right
              end: Offset.zero, // End at center
            ).animate(
              CurvedAnimation(
                parent: slideController,
                curve: Curves.easeOutCubic,
              ),
            );

        _slideControllers[card.id] = slideController;
        _slideAnimations[card.id] = slideAnimation;
      }
    }
  }

  PromoCard? _getNextAvailableCard() {
    // Find cards that are not currently displayed
    final displayedIds = _promoCards.map((card) => card.id).toSet();
    final availableCards = _allAvailableCards
        .where((card) => !displayedIds.contains(card.id))
        .toList();

    return availableCards.isNotEmpty ? availableCards.first : null;
  }

  Future<void> _removeCard(String cardId) async {
    setState(() {
      // Remove the card from the current list
      _promoCards.removeWhere((card) => card.id == cardId);

      // DON'T replace with new cards - just remove so we can test collapse
      // final nextCard = _getNextAvailableCard();
      // if (nextCard != null) {
      //   _promoCards.add(nextCard);
      // } else {
      if (_promoCards.isEmpty) {
        // ALL PROMOTIONAL CARDS REMOVED - Section should be hidden now!
      }
      // }
    });

    // Show snackbar feedback
    if (!mounted) return;

    final remainingCards = _promoCards.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✖️ Card removed! $remainingCards cards remaining'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPromoCard(PromoCard promoCard) {
    return Container(
      width: 300, // Fixed width for horizontal cards
      height: 140, // Fixed height for consistency
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: promoCard.gradient,
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    promoCard.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      _removeCard(promoCard.id);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: promoCard.iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      promoCard.icon,
                      color: promoCard.iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      promoCard.subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      promoCard.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${promoCard.buttonText} tapped!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: promoCard.iconColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        promoCard.buttonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top header with Wallet title and action buttons
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Wallet',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.add,
                            color: Colors.black,
                            size: 24,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('➕ Add new credential'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.more_horiz,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('⋯ More options'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable content area
            Expanded(
              child: Column(
                children: [
                  // Promotional cards section - Horizontal scrolling carousel (conditional)
                  if (_promoCards.isNotEmpty)
                    Container(
                      height: 160, // Fixed height for horizontal scrolling
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _promoCards.length,
                        itemBuilder: (context, index) {
                          final card = _promoCards[index];
                          return _buildPromoCard(card);
                        },
                      ),
                    ),

                  // Active credentials section
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        top: _promoCards.isEmpty
                            ? 20.0
                            : 0.0, // Add top padding when no promo cards
                      ),
                      child: Column(
                        children: [
                          // University Degree Credential
                          _buildCredentialCard(
                            title: '🎓 University Degree',
                            subtitle: 'Stanford University',
                            description:
                                'Bachelor of Science in Computer Science',
                            cardColor: Colors.blue.shade100,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '🎓 University Degree Credential tapped!',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Driver License (mDoc Credential)
                          _buildCredentialCard(
                            title: '🚗 Driver License',
                            subtitle: 'State of California',
                            description: 'Valid Driver License',
                            cardColor: Colors.green.shade100,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '🚗 Driver License credential tapped!',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Professional Certificate
                          _buildCredentialCard(
                            title: '💼 Professional Certificate',
                            subtitle: 'AWS Solutions Architect',
                            description: 'Cloud Computing Certification',
                            cardColor: Colors.orange.shade100,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '💼 Professional Certificate tapped!',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 40),

                          // View Expired Passes button
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('📄 View 13 Expired Passes'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Text(
                              'View 13 Expired Passes',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),

                          const SizedBox(height: 100), // Space for bottom FAB
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Scan button at bottom center (keeping from original layout)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📷 QR Scanner opened'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.qr_code_scanner),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // Helper method to build credential cards
  Widget _buildCredentialCard({
    required String title,
    required String subtitle,
    required String description,
    required Color cardColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  title.split(' ')[0], // Extract emoji
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.substring(
                      title.indexOf(' ') + 1,
                    ), // Extract title without emoji
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}
