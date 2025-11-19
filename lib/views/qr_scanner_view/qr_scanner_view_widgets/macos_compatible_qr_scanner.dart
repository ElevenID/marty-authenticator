/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *          Frank Merkel <frank.merkel@netknights.it>
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

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:privacyidea_authenticator/l10n/app_localizations.dart';

/// A QR scanner widget that is compatible with macOS and other desktop platforms.
/// On web, shows only an image uploader. On other platforms, uses camera with gallery functionality.
class MacOSCompatibleQRScanner extends StatefulWidget {
  const MacOSCompatibleQRScanner({super.key});

  @override
  State<MacOSCompatibleQRScanner> createState() =>
      _MacOSCompatibleQRScannerState();
}

class _MacOSCompatibleQRScannerState extends State<MacOSCompatibleQRScanner> {
  bool isInitialized = false;

  Widget _buildWebImageUploader() {
    return Material(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 120,
              color: Colors.white70,
            ),
            const SizedBox(height: 32),
            Text(
              'Select QR Code Image',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose an image containing a QR code to scan',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _pickAndProcessImage,
              icon: Icon(Icons.upload_file),
              label: Text('Upload Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(20),
                textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndProcessImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        // For web, we'll use an alternative approach that doesn't rely on readBarcodeImagePath
        // Since that function is not implemented on web, we'll show an error message
        // explaining that the web platform doesn't support QR scanning from images
        if (!mounted) return;
        _showErrorDialog(
          'QR code scanning from images is not supported in the web version. '
          'Please use a mobile device or desktop application for this feature.'
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error selecting image: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // For web/Chrome, show only the image uploader
    if (kIsWeb) {
      return _buildWebImageUploader();
    }

    // For other platforms, use the camera scanner with gallery functionality
    return Material(
      color: Colors.black,
      child: Semantics(
        label: isInitialized
            ? AppLocalizations.of(context)!.a11yScanQrCodeViewActive
            : AppLocalizations.of(context)!.a11yScanQrCodeViewInactive,
        child: ReaderWidget(
          onControllerCreated: (controller, _) {
            if (!mounted) return;
            setState(() => isInitialized = controller != null);
          },
          actionButtonsAlignment: Alignment.bottomRight,
          showFlashlight: Platform.isIOS || Platform.isAndroid,
          flashOnIcon: Semantics(
            label: AppLocalizations.of(context)!.a11yScanQrCodeViewFlashlightOn,
            child: const Icon(Icons.flash_on),
          ),
          flashOffIcon: Semantics(
            label: AppLocalizations.of(
              context,
            )!.a11yScanQrCodeViewFlashlightOff,
            child: const Icon(Icons.flash_off),
          ),
          showGallery: true,
          galleryIcon: Semantics(
            label: AppLocalizations.of(context)!.a11yScanQrCodeViewGallery,
            child: const Icon(Icons.image),
          ),
          onScan: (result) {
            if (!mounted) return;
            Navigator.of(context).pop(result.text);
          },
        ),
      ),
    );
  }
}
