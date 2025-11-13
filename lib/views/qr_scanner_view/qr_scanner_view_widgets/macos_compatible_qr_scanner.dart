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
import 'package:privacyidea_authenticator/l10n/app_localizations.dart';

/// A QR scanner widget that is compatible with macOS and other desktop platforms.
/// Uses the flutter_zxing ReaderWidget which provides both camera and gallery functionality.
class MacOSCompatibleQRScanner extends StatefulWidget {
  const MacOSCompatibleQRScanner({super.key});

  @override
  State<MacOSCompatibleQRScanner> createState() =>
      _MacOSCompatibleQRScannerState();
}

class _MacOSCompatibleQRScannerState extends State<MacOSCompatibleQRScanner> {
  bool isInitialized = false;

  @override
  Widget build(BuildContext context) {
    // Use flutter_zxing ReaderWidget for all platforms
    // The ReaderWidget already handles gallery/file picker functionality
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
          showFlashlight: !kIsWeb && (Platform.isIOS || Platform.isAndroid),
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
