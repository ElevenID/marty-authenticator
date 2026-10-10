import 'package:flutter/material.dart';
import 'package:marty_authenticator/models/card_data.dart';

/// Displays only metadata attached to a verified wallet receipt.
class VerifiedReceiptDetails extends StatelessWidget {
  final CardData card;
  final String? groupTitle;
  final int groupSize;

  const VerifiedReceiptDetails({
    super.key,
    required this.card,
    this.groupTitle,
    this.groupSize = 1,
  });

  @override
  Widget build(BuildContext context) {
    final format = card.metadata?['format'];
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: card.gradient),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(card.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        card.subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _detail('ISSUER', card.issuer ?? card.subtitle),
            if (card.id != null) _detail('RECEIPT ID', card.id!),
            if (card.type != null) _detail('CREDENTIAL TYPE', card.type!),
            if (format is String) _detail('FORMAT', format),
            if (groupTitle != null && groupSize > 1)
              _detail('GROUP', '$groupTitle · $groupSize cards'),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
