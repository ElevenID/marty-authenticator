import 'package:flutter/material.dart';
import '../../models/document_verification_config.dart';
import '../../views/document_verification/document_scanning_view.dart';

class DriverLicenseDialog {
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
              leading: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.blue,
                  size: 20,
                ),
                label: const Text(
                  'Back',
                  style: TextStyle(color: Colors.blue, fontSize: 16),
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 8.0),
                ),
              ),
              leadingWidth: 80,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver\'s License and\nID Cards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Securely present your identity with your iPhone or Apple Watch.',
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
                  _buildStateOption(
                    context,
                    'Digital ID (Passport)',
                    Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentScanningView(
                            config: DocumentVerificationConfig.passport,
                          ),
                        ),
                      );
                    },
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
                  _buildStateOption(context, 'Arizona', Colors.orange),
                  const SizedBox(height: 16),
                  _buildStateOption(
                    context,
                    'California mDL Pilot',
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildStateOption(context, 'Colorado', Colors.purple),
                  const SizedBox(height: 16),
                  _buildStateOption(context, 'Georgia', Colors.red),
                  const SizedBox(height: 16),
                  _buildStateOption(context, 'Hawaii', Colors.green),
                  const SizedBox(height: 16),
                  _buildStateOption(context, 'Iowa', Colors.brown),
                  const SizedBox(height: 16),
                  _buildStateOption(context, 'Maryland', Colors.blue),
                  const SizedBox(height: 16),
                  _buildStateOption(context, 'Montana', Colors.blue),
                  const SizedBox(height: 16),
                  _buildStateOption(context, 'New Mexico', Colors.red),
                  const SizedBox(height: 16),
                  _buildStateOption(context, 'North Dakota', Colors.blue),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildStateOption(
    BuildContext context,
    String stateName,
    Color accentColor, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$stateName selected')));
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
              height: 30,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.credit_card,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                stateName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          ],
        ),
      ),
    );
  }
}
