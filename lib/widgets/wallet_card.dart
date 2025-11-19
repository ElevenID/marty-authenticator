import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import '../models/card_data.dart';
import '../views/card_details_screen.dart';

class WalletCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _navigateToCardDetails(context),
      onLongPress: onLongPress,
      child: Container(
        height: 220,
        width: 480,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cardData.gradient,
          ),
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
