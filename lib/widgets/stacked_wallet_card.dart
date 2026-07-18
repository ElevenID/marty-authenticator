import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_data.dart';
import '../providers/card_state_provider.dart';
import '../views/grouped_card_details_screen.dart';
import '../utils/layout_constants.dart';

class StackedWalletCard extends ConsumerWidget {
  final CardGroup cardGroup;
  final bool isDragging;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const StackedWalletCard({
    super.key,
    required this.cardGroup,
    this.isDragging = false,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If only one card, show regular card behavior
    if (cardGroup.cards.length == 1) {
      return _buildSingleCard(context, ref);
    }

    // Show stacked cards for groups with multiple cards
    return _buildStackedCards(context, ref);
  }

  Widget _buildSingleCard(BuildContext context, WidgetRef ref) {
    final primaryCard = cardGroup.cards.first;
    final cardContent = _buildCardContent(context, primaryCard, false);

    return LongPressDraggable<CardData>(
      data: primaryCard,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.05, child: cardContent),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
      onDragStarted: () {
        ref.read(draggingCardProvider.notifier).state = primaryCard;
        onLongPress?.call();
      },
      onDraggableCanceled: (_, _) {
        ref.read(draggingCardProvider.notifier).state = null;
      },
      onDragCompleted: () {
        ref.read(draggingCardProvider.notifier).state = null;
      },
      child: GestureDetector(
        onTap:
            onTap ?? () => _navigateToSingleCardDetails(context, primaryCard),
        child: cardContent,
      ),
    );
  }

  Widget _buildStackedCards(BuildContext context, WidgetRef ref) {
    final cards = cardGroup.cards;
    final primaryCard = cards.first;

    return LongPressDraggable<CardData>(
      data: primaryCard,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.05,
          child: SizedBox(
            height: LayoutConstants.cardHeight,
            width: LayoutConstants.cardWidth,
            child: Stack(
              children: [
                // Background cards (stack effect)
                for (int i = cards.length - 1; i >= 1; i--)
                  _buildStackedCardLayer(context, cards[i], i),

                // Primary card (front)
                _buildCardContent(context, primaryCard, true),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: SizedBox(
          height: LayoutConstants.cardHeight,
          width: LayoutConstants.cardWidth,
          child: Stack(
            children: [
              // Background cards (stack effect)
              for (int i = cards.length - 1; i >= 1; i--)
                _buildStackedCardLayer(context, cards[i], i),

              // Primary card (front)
              _buildCardContent(context, primaryCard, true),
            ],
          ),
        ),
      ),
      onDragStarted: () {
        // Update the dragging state provider
        ref.read(draggingCardProvider.notifier).state = primaryCard;
        onLongPress?.call();
      },
      onDraggableCanceled: (_, _) {
        ref.read(draggingCardProvider.notifier).state = null;
      },
      onDragCompleted: () {
        ref.read(draggingCardProvider.notifier).state = null;
      },
      child: GestureDetector(
        onTap: onTap ?? () => _navigateToGroupedCardDetails(context),
        child: SizedBox(
          height: LayoutConstants.cardHeight,
          width: LayoutConstants.cardWidth,
          child: Stack(
            children: [
              // Background cards (stack effect)
              for (int i = cards.length - 1; i >= 1; i--)
                _buildStackedCardLayer(context, cards[i], i),

              // Primary card (front)
              _buildCardContent(context, primaryCard, true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStackedCardLayer(
    BuildContext context,
    CardData card,
    int stackIndex,
  ) {
    // Create a subtle offset and scale for stacked effect
    final double offset = stackIndex * 4.0;
    final double scale = 1.0 - (stackIndex * 0.02);

    return Positioned(
      left: offset,
      top: offset,
      child: Transform.scale(
        scale: scale,
        child: Container(
          height: LayoutConstants.cardHeight,
          width: LayoutConstants.cardWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              LayoutConstants.cardBorderRadius,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: card.gradient
                  .map((color) => color.withValues(alpha: 0.8))
                  .toList(),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    CardData card,
    bool isStacked,
  ) {
    return Container(
      height: LayoutConstants.cardHeight,
      width: LayoutConstants.cardWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LayoutConstants.cardBorderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: card.gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(card),
                const SizedBox(height: 20),
                // _buildCardTitle(card), // Moved to header
                // const SizedBox(height: 4),
                // _buildCardSubtitle(card), // Moved to header
                if (card.metadata != null) ...[
                  const SizedBox(height: 12),
                  _buildCardMetadata(card),
                ],
                const Spacer(),
                _buildCardIndicator(),
              ],
            ),
          ),

          // Stack indicator for grouped cards
          if (isStacked && cardGroup.cards.length > 1)
            Positioned(top: 16, right: 16, child: _buildStackIndicator()),
        ],
      ),
    );
  }

  Widget _buildCardHeader(CardData card) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(card.icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.subtitle, // Issuer
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                card.title, // Credential Name
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  /*
  Widget _buildCardTitle(CardData card) {
    return Text(
      card.title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCardSubtitle(CardData card) {
    return Text(
      card.subtitle,
      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
    );
  }
  */

  Widget _buildCardMetadata(CardData card) {
    // Display up to 2 metadata fields
    final entries = card.metadata!.entries.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              Text(
                '${entry.key.toUpperCase()}: ',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                entry.value.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCardIndicator() {
    return Container(
      height: 2,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildStackIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${cardGroup.cards.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navigateToSingleCardDetails(BuildContext context, CardData card) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GroupedCardDetailsScreen(cardGroup: cardGroup, initialIndex: 0),
      ),
    );
  }

  void _navigateToGroupedCardDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GroupedCardDetailsScreen(cardGroup: cardGroup, initialIndex: 0),
      ),
    );
  }
}
