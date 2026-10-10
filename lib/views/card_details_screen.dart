import 'package:flutter/material.dart';
import 'package:marty_authenticator/models/card_data.dart';
import 'package:marty_authenticator/widgets/card_details_header.dart';
import 'package:marty_authenticator/widgets/verified_receipt_details.dart';

class CardDetailsScreen extends StatelessWidget {
  final CardData card;

  const CardDetailsScreen({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const CardDetailsHeader(title: 'Done'),
      body: VerifiedReceiptDetails(card: card),
    );
  }
}
