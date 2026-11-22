import 'package:flutter/material.dart';
import '../../../../models/document_verification_config.dart';
import '../../../document_verification/document_scanning_view.dart';
import 'document_placeholder_card.dart';

class PassportPlaceholderCard extends StatelessWidget {
  const PassportPlaceholderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentPlaceholderCard(
      title: 'Digital ID (Passport)',
      description: 'Add your passport to Wallet',
      documentType: 'Identity Document',
      issuer: 'Government Authority',
      color: Colors.indigo,
      icon: Icons.book,
      onScan: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              DocumentScanningView(config: DocumentVerificationConfig.passport),
        ),
      ),
    );
  }
}
