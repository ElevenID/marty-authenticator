import 'package:flutter/material.dart';
import 'package:privacyidea_authenticator/widgets/common/back_button.dart'
    as common;

class TransitCardDialog {
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
              leading: common.CustomBackButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              leadingWidth: 80,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transit Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Quickly pass through gates by holding your iPhone or Apple Watch near a reader.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'United States',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTransitOption(
                    context,
                    'Clipper',
                    'San Francisco Bay Area',
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildTransitOption(
                    context,
                    'SmarTrip',
                    'Washington, DC National Capital Region',
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildTransitOption(
                    context,
                    'TAP',
                    'Greater Los Angeles',
                    Colors.orange,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Canada',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTransitOption(
                    context,
                    'PRESTO',
                    'Greater Toronto Area',
                    Colors.green,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'China mainland',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTransitOption(
                    context,
                    'Beijing T-Union Transit Card',
                    'Beijing',
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildTransitOption(
                    context,
                    'Changsha Transit Card',
                    'Changsha',
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildTransitOption(
                    context,
                    'Changzhou Transit Card',
                    'Changzhou',
                    Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildTransitOption(
    BuildContext context,
    String title,
    String subtitle,
    Color iconColor,
  ) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$title selected')));
      },
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
              child: const Icon(
                Icons.credit_card,
                color: Colors.white,
                size: 20,
              ),
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          ],
        ),
      ),
    );
  }
}
