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
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Static data for promotional cards
const List<PromotionalCardData> _promotionalCardData = [
  PromotionalCardData(
    id: 'welcome',
    title: 'Welcome to Your',
    subtitle: 'Digital Wallet',
    description:
        'Store your digital credentials securely and access them anywhere.',
    icon: Icons.wallet_outlined,
    gradientColors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
  ),
  PromotionalCardData(
    id: 'security',
    title: 'Enhanced Security',
    subtitle: 'End-to-End Encryption',
    description:
        'Your data is protected with military-grade encryption and biometric authentication.',
    icon: Icons.security_outlined,
    gradientColors: [Color(0xFF50C878), Color(0xFF3A9B5C)],
  ),
  PromotionalCardData(
    id: 'features',
    title: 'New Features',
    subtitle: 'Mobile Driver\'s License',
    description:
        'Add your driver\'s license and use it for quick verification at participating locations.',
    icon: Icons.credit_card_outlined,
    gradientColors: [Color(0xFFFF6B6B), Color(0xFFE55A5A)],
  ),
];

// Provider to manage dismissed and expired promotional cards
final promotionalCardsProvider =
    StateNotifierProvider<PromotionalCardsNotifier, PromotionalCardsState>(
      (ref) => PromotionalCardsNotifier(),
    );

class PromotionalCardsState {
  final List<String> dismissedCards;
  final List<PromotionalCardData> expiredCards;
  final bool showExpiredCards;

  const PromotionalCardsState({
    this.dismissedCards = const [],
    this.expiredCards = const [],
    this.showExpiredCards = false,
  });

  PromotionalCardsState copyWith({
    List<String>? dismissedCards,
    List<PromotionalCardData>? expiredCards,
    bool? showExpiredCards,
  }) {
    return PromotionalCardsState(
      dismissedCards: dismissedCards ?? this.dismissedCards,
      expiredCards: expiredCards ?? this.expiredCards,
      showExpiredCards: showExpiredCards ?? this.showExpiredCards,
    );
  }
}

class PromotionalCardData {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;

  const PromotionalCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradientColors,
  });
}

class PromotionalCardsNotifier extends StateNotifier<PromotionalCardsState> {
  PromotionalCardsNotifier() : super(const PromotionalCardsState());

  void dismissCard(String cardId) {
    // Add card to expired list for later viewing
    final cardData = _getCardData(cardId);
    if (cardData != null) {
      state = state.copyWith(
        dismissedCards: [...state.dismissedCards, cardId],
        expiredCards: [...state.expiredCards, cardData],
      );
    }
  }

  void toggleExpiredCardsView() {
    state = state.copyWith(showExpiredCards: !state.showExpiredCards);
  }

  void restoreCard(String cardId) {
    state = state.copyWith(
      dismissedCards: state.dismissedCards.where((id) => id != cardId).toList(),
      expiredCards: state.expiredCards
          .where((card) => card.id != cardId)
          .toList(),
    );
  }

  PromotionalCardData? _getCardData(String cardId) {
    try {
      return _promotionalCardData.firstWhere((card) => card.id == cardId);
    } catch (e) {
      return null;
    }
  }
}

/// Promotional card carousel component with dismissal functionality
class PromotionalCarousel extends ConsumerStatefulWidget {
  const PromotionalCarousel({super.key});

  @override
  ConsumerState<PromotionalCarousel> createState() =>
      _PromotionalCarouselState();
}

class _PromotionalCarouselState extends ConsumerState<PromotionalCarousel>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  late AnimationController _collapseController;
  final Map<String, AnimationController> _dismissAnimations = {};
  final Map<String, Animation<double>> _heightAnimations = {};

  @override
  void initState() {
    super.initState();
    _collapseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize dismiss animations for each card
    final allCards = _getAllCardData();
    for (final card in allCards) {
      _dismissAnimations[card.id] = AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      );
      _heightAnimations[card.id] = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _dismissAnimations[card.id]!,
          curve: Curves.easeInOut,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _collapseController.dispose();
    for (final controller in _dismissAnimations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<PromotionalCardData> _getAllCardData() {
    return _promotionalCardData;
  }

  @override
  Widget build(BuildContext context) {
    final cardsState = ref.watch(promotionalCardsProvider);
    final allCards = _getAllCardData();
    final activeCards = allCards
        .where((card) => !cardsState.dismissedCards.contains(card.id))
        .toList();

    // If showing expired cards, show those instead
    if (cardsState.showExpiredCards) {
      return _buildExpiredCardsView(cardsState.expiredCards);
    }

    // If no active cards, return empty widget instead of showing placeholder
    if (activeCards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Carousel
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: activeCards.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _heightAnimations[activeCards[index].id]!,
                builder: (context, child) {
                  final heightFactor =
                      _heightAnimations[activeCards[index].id]!.value;
                  return Transform.scale(
                    scaleY:
                        1.0 -
                        (1.0 - heightFactor) * 0.8, // Scale down to a line
                    child: Opacity(
                      opacity:
                          0.3 +
                          (0.7 * heightFactor), // Fade out as it collapses
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildPromotionalCard(activeCards[index]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Page indicators (only show if multiple active cards)
        if (activeCards.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              activeCards.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                ),
              ),
            ),
          ),

        // Removed expired cards button and scan QR button from promotional carousel
      ],
    );
  }

  // Methods _buildScanQrButton and _buildExpiredCardsButton removed
  // These features are now handled elsewhere in the app

  Widget _buildPromotionalCard(PromotionalCardData cardData) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardData.gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: cardData.gradientColors.first.withOpacity(0.3),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -30,
            top: -30,
            child: Icon(
              cardData.icon,
              size: 80, // Reduced from 120
              color: Colors.white.withOpacity(0.1),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      cardData.icon,
                      color: Colors.white,
                      size: 24, // Reduced from 32
                    ),

                    const Spacer(),

                    GestureDetector(
                      onTap: () => _dismissCard(cardData.id),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.8),
                          size: 14, // Reduced from 16
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Text(
                  cardData.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                Text(
                  cardData.subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  cardData.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const Spacer(),

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
            ),
          ),
        ],
      ),
    );
  }

  // _buildExpiredCardsButton removed - now handled in MDL section

  Widget _buildExpiredCardsView(List<PromotionalCardData> expiredCards) {
    return Column(
      children: [
        // Header
        Row(
          children: [
            IconButton(
              onPressed: () => ref
                  .read(promotionalCardsProvider.notifier)
                  .toggleExpiredCardsView(),
              icon: const Icon(Icons.arrow_back),
            ),
            const Text(
              'Dismissed Cards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Expired cards list
        ...expiredCards
            .map(
              (card) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(card.icon, color: Colors.grey.shade600, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            card.subtitle,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref
                          .read(promotionalCardsProvider.notifier)
                          .restoreCard(card.id),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.restore,
                          color: Colors.blue.shade600,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  void _dismissCard(String cardId) async {
    // Start the dismiss animation
    await _dismissAnimations[cardId]?.forward();

    // Then update the state
    if (mounted) {
      ref.read(promotionalCardsProvider.notifier).dismissCard(cardId);
    }

    // Reset the animation for next time
    _dismissAnimations[cardId]?.reset();
  }
}
