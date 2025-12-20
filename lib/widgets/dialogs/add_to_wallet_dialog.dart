import 'package:flutter/material.dart';
import 'package:privacyidea_authenticator/widgets/dialogs/previous_cards_dialog.dart';
import 'package:privacyidea_authenticator/widgets/dialogs/transit_card_dialog.dart';
import 'package:privacyidea_authenticator/widgets/dialogs/driver_license_dialog.dart';

class AddToWalletDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          backgroundColor: const Color(0xFF1C1C1E),
          child: Scaffold(
            backgroundColor: const Color(0xFF1C1C1E),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1C1C1E),
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16.0, top: 8.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFF48484A),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    color: Colors.white,
                    padding: const EdgeInsets.all(8.0),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Documents',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Keep all the cards, keys, and passes you use every day all in one place.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Available Cards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCardOption(
                    context,
                    icon: Icons.credit_card,
                    iconColor: const Color(0xFF8E8E93),
                    title: 'Previous Cards',
                    subtitle: 'None',
                    onTap: () {
                      PreviousCardsDialog.show(context);
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildCardOption(
                    context,
                    icon: Icons.train,
                    iconColor: Colors.green,
                    title: 'Transit Card',
                    onTap: () {
                      TransitCardDialog.show(context);
                    },
                    showArrow: true,
                  ),
                  const SizedBox(height: 16),
                  _buildCardOption(
                    context,
                    icon: Icons.badge,
                    iconColor: Colors.red,
                    title: 'Driver\'s License and ID Cards',
                    onTap: () {
                      DriverLicenseDialog.show(context);
                    },
                    showArrow: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildCardOption(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool showArrow = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            if (showArrow)
              const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          ],
        ),
      ),
    );
  }
}
