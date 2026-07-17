import 'package:flutter/material.dart';
import '../models/card_data.dart';
import '../widgets/stacked_wallet_card.dart';

class CascadingCardList extends StatelessWidget {
  final List<CardGroup> cardGroups;
  final bool isDragging;
  final Function(CardData)? onCardTap;
  final Function(CardData)? onCardLongPress;
  final Function(int oldIndex, int newIndex)? onReorder;

  const CascadingCardList({
    super.key,
    required this.cardGroups,
    this.isDragging = false,
    this.onCardTap,
    this.onCardLongPress,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    double totalHeight = (cardGroups.length * 60.0) + 200.0 + 100.0;

    return SizedBox(
      height: totalHeight,
      child: Stack(children: _buildCascadingCards()),
    );
  }

  List<Widget> _buildCascadingCards() {
    return cardGroups.asMap().entries.map((entry) {
      int index = entry.key;
      CardGroup cardGroup = entry.value;
      double verticalOffset = index * 60.0;

      return Positioned(
        left: 0,
        top: verticalOffset,
        right: 0,
        child: DragTarget<CardData>(
          onWillAcceptWithDetails: (details) {
            // Don't accept if it's the same card
            return details.data != cardGroup.cards.first;
          },
          onAcceptWithDetails: (details) {
            // Find source index
            int sourceIndex = -1;
            for (int i = 0; i < cardGroups.length; i++) {
              if (cardGroups[i].cards.first.title == details.data.title) {
                // Compare by title or equality
                sourceIndex = i;
                break;
              }
            }
            if (sourceIndex != -1 && sourceIndex != index) {
              onReorder?.call(sourceIndex, index);
            }
          },
          builder: (context, candidateData, rejectedData) {
            final isCandidate = candidateData.isNotEmpty;
            return Opacity(
              opacity: isCandidate ? 0.7 : 1.0,
              child: _buildCardGroupWidget(cardGroup),
            );
          },
        ),
      );
    }).toList();
  }

  Widget _buildCardGroupWidget(CardGroup cardGroup) {
    // Use stacked wallet card for groups or single wallet card for individual cards
    return Container(
      height: 200.0,
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Center(
        child: StackedWalletCard(
          cardGroup: cardGroup,
          isDragging: isDragging,
          onTap: () => onCardTap?.call(cardGroup.cards.first),
          onLongPress: () => onCardLongPress?.call(cardGroup.cards.first),
        ),
      ),
    );
  }
}
