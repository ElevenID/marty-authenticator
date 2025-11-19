import 'package:flutter/material.dart';
import '../models/card_data.dart';
import '../widgets/wallet_card.dart';

class CascadingCardList extends StatelessWidget {
  final List<CardGroup> cardGroups;
  final bool isDragging;
  final Function(CardData)? onCardTap;
  final Function(CardData)? onCardLongPress;

  const CascadingCardList({
    super.key,
    required this.cardGroups,
    this.isDragging = false,
    this.onCardTap,
    this.onCardLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 2,
        child: Stack(children: _buildCascadingCards()),
      ),
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
        child: _buildCardGroupWidget(cardGroup),
      );
    }).toList();
  }

  Widget _buildCardGroupWidget(CardGroup cardGroup) {
    // Show the primary card of each group for cascading effect
    final primaryCard = cardGroup.cards.first;

    return Container(
      height: 200.0,
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Center(
        child: WalletCard(
          cardData: primaryCard,
          isDragging: isDragging,
          onTap: () => onCardTap?.call(primaryCard),
          onLongPress: () => onCardLongPress?.call(primaryCard),
        ),
      ),
    );
  }
}
