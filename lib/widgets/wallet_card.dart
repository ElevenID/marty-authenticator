import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:getwidget/getwidget.dart';
import '../models/card_data.dart';
import '../providers/card_state_provider.dart';
import '../views/card_details_screen.dart';
import '../utils/layout_constants.dart';

class WalletCard extends ConsumerWidget {
  final CardData cardData;
  final bool isDragging;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const WalletCard({
    super.key,
    required this.cardData,
    this.isDragging = false,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardContent = _buildCardContent(context);

    return LongPressDraggable<CardData>(
      data: cardData,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.05, child: cardContent),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
      onDragStarted: () {
        ref.read(draggingCardProvider.notifier).state = cardData;
        onLongPress?.call();
      },
      onDraggableCanceled: (_, __) {
        ref.read(draggingCardProvider.notifier).state = null;
      },
      onDragCompleted: () {
        ref.read(draggingCardProvider.notifier).state = null;
      },
      child: GestureDetector(
        onTap: onTap ?? () => _navigateToCardDetails(context),
        child: cardContent,
      ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    return Container(
      height: LayoutConstants.cardHeight,
      width: LayoutConstants.cardWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LayoutConstants.cardBorderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardData.gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(),
              const SizedBox(height: 20),
              _buildCardTitle(),
              const SizedBox(height: 4),
              _buildCardSubtitle(),
              const Spacer(),
              _buildCardIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader() {
    return Row(
      children: [
        GFAvatar(
          backgroundColor: Colors.white.withOpacity(0.2),
          size: GFSize.MEDIUM,
          child: Icon(cardData.icon, color: Colors.white, size: 24),
        ),
        const Spacer(),
        GFIconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
          type: GFButtonType.transparent,
          size: GFSize.SMALL,
        ),
      ],
    );
  }

  Widget _buildCardTitle() {
    return Text(
      cardData.title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCardSubtitle() {
    return Text(
      cardData.subtitle,
      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
    );
  }

  Widget _buildCardIndicator() {
    return Container(
      height: 2,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  void _navigateToCardDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardDetailsScreen(cardData: cardData.toMap()),
      ),
    );
  }
}
