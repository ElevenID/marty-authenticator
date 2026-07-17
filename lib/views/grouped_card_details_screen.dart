import 'package:flutter/material.dart';
import 'package:marty_authenticator/widgets/card_details_header.dart';
import '../models/card_data.dart';

class GroupedCardDetailsScreen extends StatefulWidget {
  final CardGroup cardGroup;
  final int initialIndex;

  const GroupedCardDetailsScreen({
    super.key,
    required this.cardGroup,
    this.initialIndex = 0,
  });

  @override
  State<GroupedCardDetailsScreen> createState() =>
      _GroupedCardDetailsScreenState();
}

class _GroupedCardDetailsScreenState extends State<GroupedCardDetailsScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CardDetailsHeader(title: 'Done'),
      body: Column(
        children: [
          // Page indicator for multiple cards
          if (widget.cardGroup.cards.length > 1) _buildPageIndicator(),

          // Main content with page view
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.cardGroup.cards.length,
              itemBuilder: (context, index) {
                return _buildCardDetailsPage(widget.cardGroup.cards[index]);
              },
            ),
          ),

          // Navigation hint for multiple cards
          if (widget.cardGroup.cards.length > 1) _buildNavigationHint(),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Group title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Text(
              widget.cardGroup.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Page dots
          Row(
            children: List.generate(
              widget.cardGroup.cards.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Card counter
          Text(
            '${_currentIndex + 1} of ${widget.cardGroup.cards.length}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDetailsPage(CardData cardData) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with logo and card type
          Row(
            children: [
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: cardData.gradient),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(cardData.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardData.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      cardData.subtitle,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Text(
                'PDP PLUS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Employee/Card holder information
          const Text(
            'CARD HOLDER NAME',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adam Burdett',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 32),

          // Additional details in rows
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ISSUER NAME',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cardData.title,
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CARD ID',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${cardData.title.hashCode.abs().toString().substring(0, 6)}',
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Additional information
          const Text(
            'ADDITIONAL DETAILS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cardData.subtitle,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),

          // Group information for grouped cards
          if (widget.cardGroup.cards.length > 1) ...[
            const SizedBox(height: 32),
            const Text(
              'GROUP INFORMATION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Part of "${widget.cardGroup.title}" group with ${widget.cardGroup.cards.length} cards',
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationHint() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe, color: Colors.grey[600], size: 16),
          const SizedBox(width: 8),
          Text(
            'Swipe to view other cards in this group',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
