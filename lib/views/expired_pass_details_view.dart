import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_data.dart';
import '../providers/card_state_provider.dart';
import 'pass_configuration_view.dart';
import '../widgets/common/back_button.dart' as common;

class ExpiredPassDetailsView extends ConsumerWidget {
  final CardData cardData;

  const ExpiredPassDetailsView({super.key, required this.cardData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: common.CustomBackButton(
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.blue),
            onPressed: () {
              // Share functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.blue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PassConfigurationView(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildCardPreview(context),
                ],
              ),
            ),
          ),
          _buildBottomButtons(context, ref),
        ],
      ),
    );
  }

  Widget _buildCardPreview(BuildContext context) {
    return Center(
      child: Container(
        width: 300,
        height: 450,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cardData.gradient,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(cardData.icon, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cardData.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Icon(Icons.qr_code, size: 150, color: Colors.black),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              ref.read(cardStateProvider.notifier).deleteCard(cardData);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(cardStateProvider.notifier).toggleCardExpired(cardData);
              Navigator.pop(context);
            },
            child: const Text(
              'Unhide',
              style: TextStyle(color: Colors.blue, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
