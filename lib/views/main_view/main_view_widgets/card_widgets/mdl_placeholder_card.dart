/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';
import '../../../../models/document_verification_config.dart';
import '../../../document_verification/document_scanning_view.dart';
import 'document_placeholder_card.dart';

class MdlPlaceholderCard extends StatelessWidget {
  const MdlPlaceholderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentPlaceholderCard(
      title: "Mobile Driver's License",
      description: "Add your driver's license to Wallet",
      documentType: "Driver's License",
      issuer: 'Department of Motor Vehicles',
      color: Colors.deepPurple,
      icon: Icons.credit_card,
      onScan: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DocumentScanningView(
            config: DocumentVerificationConfig.driverLicense,
          ),
        ),
      ),
      extraMenuItem: (sheetContext) => ListTile(
        leading: const Icon(Icons.featured_play_list, color: Colors.blue),
        title: const Text(
          'Drivers License and ID cards',
          style: TextStyle(color: Colors.blue),
        ),
        onTap: () {
          Navigator.pop(sheetContext);
          _navigateToDriversLicensePage(sheetContext);
        },
      ),
    );
  }

  static void _navigateToDriversLicensePage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: const Text(
              'Drivers License and ID cards',
              style: TextStyle(color: Colors.white),
            ),
            leading: const BackButton(color: Colors.white),
          ),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card, size: 80, color: Colors.white54),
                  SizedBox(height: 20),
                  Text(
                    'Drivers License and ID cards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'This page will contain information and management options for driver\'s licenses and ID cards.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
