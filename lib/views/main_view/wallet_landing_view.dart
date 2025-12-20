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
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:privacyidea_authenticator/l10n/app_localizations.dart';

import 'main_view_widgets/credentials_list.dart';
// import 'main_view_widgets/card_widgets/mdl_placeholder_card.dart'; // No longer needed
// import 'main_view_widgets/wallet_components/mdl_placeholder_section.dart'; // Temporarily commented out
import '../../utils/utils.dart';
import '../../utils/view_utils.dart';
import '../../widgets/dialog_widgets/default_dialog.dart';
import '../qr_scanner_view/qr_scanner_view.dart';
import '../../model/processor_result.dart';
import '../../utils/riverpod/riverpod_providers/generated_providers/token_container_notifier.dart';
import '../../utils/riverpod/riverpod_providers/generated_providers/token_notifier.dart';

export 'wallet_landing_view.dart';

/// Wallet-style landing view that mimics iOS Wallet app
class WalletLandingView extends ConsumerStatefulWidget {
  static const routeName = '/walletLandingView';

  final Widget? backgroundImage;
  final String appName;

  const WalletLandingView({
    this.backgroundImage,
    this.appName = 'Marty Authenticator',
    super.key,
  });

  @override
  ConsumerState<WalletLandingView> createState() => _WalletLandingViewState();
}

class _WalletLandingViewState extends ConsumerState<WalletLandingView> {
  @override
  Widget build(BuildContext context) {
    // Wallet-style landing view with black background and iOS design
    return Container(
      color: Colors.black, // Wallet app uses black background
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              // Custom wallet-style header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Wallet title in upper left
                    const Text(
                      'Documents',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Stack toggle button - will be passed to CredentialsList
                    IconButton(
                      onPressed: () {
                        // This will be handled by the CredentialsList widget
                        setState(() {});
                      },
                      icon: const Icon(
                        Icons.layers,
                        color: Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Toggle stacking style',
                    ),
                    IconButton(
                      onPressed: () async {
                        // Use the same QR scanning logic as the floating button
                        try {
                          if (await Permission.camera.isPermanentlyDenied) {
                            showAsyncDialog(
                              builder: (_) => DefaultDialog(
                                title: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.grantCameraPermissionDialogTitle,
                                ),
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.grantCameraPermissionDialogPermanentlyDenied,
                                ),
                              ),
                            );
                            return;
                          }
                        } catch (e) {
                          // Handle platform-specific permission issues
                        }
                        if (!context.mounted) return;

                        final qrCode = await Navigator.pushNamed(
                          context,
                          QRScannerView.routeName,
                        );
                        final resultHandlers = <ResultHandler>[
                          ref.read(tokenProvider.notifier),
                          ref.read(tokenContainerProvider.notifier),
                        ];
                        if (qrCode == null || !context.mounted) return;
                        final handled = await scanQrCode(
                          context: context,
                          resultHandlerList: resultHandlers,
                          qrCode: qrCode,
                        );
                        if (!handled) {
                          showErrorStatusMessage(
                            message: (l) => l.invalidQrScan,
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ), // Reduced from 28
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {}, // Placeholder for more actions
                      icon: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 24,
                      ), // Reduced from 28
                    ),
                  ],
                ),
              ),

              // Scrollable content (flexible constraints)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const CredentialsList(),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigationArea(),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationArea() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(
        left: 40,
        right: 40,
        bottom: 4, // Further reduced to eliminate 49px overflow
        top: 1, // Reduced top padding
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Token Management Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/legacyMainView');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.list_alt, color: Color(0xFF007AFF), size: 18),
                    Text(
                      'Tokens',
                      style: TextStyle(
                        color: Color(0xFF007AFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // QR Scanner Button
          Semantics(
            label: AppLocalizations.of(context)!.a11yScanQrCodeButton,
            child: Container(
              height: 40, // Even smaller FAB
              width: 40,
              child: FloatingActionButton(
                onPressed: () async {
                  try {
                    if (await Permission.camera.isPermanentlyDenied) {
                      showAsyncDialog(
                        builder: (_) => DefaultDialog(
                          title: Text(
                            AppLocalizations.of(
                              context,
                            )!.grantCameraPermissionDialogTitle,
                          ),
                          content: Text(
                            AppLocalizations.of(
                              context,
                            )!.grantCameraPermissionDialogPermanentlyDenied,
                          ),
                        ),
                      );
                      return;
                    }
                  } catch (e) {
                    // Handle platform-specific permission issues (e.g., macOS during development)
                    // Continue to QR scanner as the camera permissions will be handled by the scanner itself
                  }
                  if (!context.mounted) return;

                  /// Open the QR-code scanner and call `handleQrCode`, with the scanned code as the argument.
                  final qrCode = await Navigator.pushNamed(
                    context,
                    QRScannerView.routeName,
                  );
                  final resultHandlers = <ResultHandler>[
                    ref.read(tokenProvider.notifier),
                    ref.read(tokenContainerProvider.notifier),
                  ];
                  if (qrCode == null || !context.mounted) return;
                  final handled = await scanQrCode(
                    context: context,
                    resultHandlerList: resultHandlers,
                    qrCode: qrCode,
                  );
                  if (!handled) {
                    showErrorStatusMessage(message: (l) => l.invalidQrScan);
                  }
                },
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 8,
                child: const Icon(Icons.qr_code_scanner_outlined, size: 20),
              ),
            ),
          ),

          // Empty space to balance the layout
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
