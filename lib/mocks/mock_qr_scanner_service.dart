/// Mock QR scanner service for testing
/// Intercepts QR scanner navigation and returns fixture data when enabled
library;

import 'package:flutter/material.dart';
import '../fixtures/qr_code_fixtures.dart';

/// Configuration for mock QR scanner
class MockQrScannerConfig {
  /// Whether QR mocking is enabled (set via build-time constant)
  static const bool enabled = bool.fromEnvironment('MOCK_QR_SCANNER');

  /// Current QR code to return when scanner is opened
  String? currentQrCode;

  /// Queue of QR codes to return in sequence
  final List<String> qrQueue = [];

  /// Whether to show a selection dialog when multiple QR codes are available
  final bool showSelectionDialog;

  /// Delay before returning QR code (milliseconds)
  final int delayMs;

  MockQrScannerConfig({
    this.showSelectionDialog = true,
    this.delayMs = 500,
    this.currentQrCode,
  });

  /// Create config with a single QR code
  factory MockQrScannerConfig.withCode(String qrCode) {
    return MockQrScannerConfig(currentQrCode: qrCode);
  }

  /// Create config with a queue of QR codes
  factory MockQrScannerConfig.withQueue(List<String> qrCodes) {
    final config = MockQrScannerConfig();
    config.qrQueue.addAll(qrCodes);
    return config;
  }

  /// Create config with all fixture QR codes for selection
  factory MockQrScannerConfig.withAllFixtures() {
    return MockQrScannerConfig(showSelectionDialog: true);
  }

  /// Get the next QR code to return
  String? getNextQrCode() {
    if (qrQueue.isNotEmpty) {
      return qrQueue.removeAt(0);
    }
    return currentQrCode;
  }

  /// Reset the config
  void reset() {
    currentQrCode = null;
    qrQueue.clear();
  }
}

/// Global mock QR scanner configuration
/// Only active when MOCK_QR_SCANNER build constant is true
MockQrScannerConfig? _globalMockQrScannerConfig;

/// Get the current mock QR scanner configuration
MockQrScannerConfig? getMockQrScannerConfig() => _globalMockQrScannerConfig;

/// Set the mock QR scanner configuration
void setMockQrScannerConfig(MockQrScannerConfig? config) {
  _globalMockQrScannerConfig = config;
}

/// Mock QR scanner navigator observer
/// Intercepts navigation to QR scanner route and returns mock data
class MockQrScannerNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    // Only intercept if mocking is enabled and config is set
    if (!MockQrScannerConfig.enabled || _globalMockQrScannerConfig == null) {
      return;
    }

    // Check if this is the QR scanner route
    if (route.settings.name == '/qr_scanner') {
      _handleMockQrScan(route);
    }
  }

  void _handleMockQrScan(Route<dynamic> route) {
    final config = _globalMockQrScannerConfig!;

    // Delay to simulate camera initialization
    Future.delayed(Duration(milliseconds: config.delayMs), () {
      String? qrCode;

      if (config.showSelectionDialog && navigator != null) {
        // Show selection dialog with available QR codes
        _showQrSelectionDialog(route, config);
      } else {
        // Return the next QR code directly
        qrCode = config.getNextQrCode();
        if (qrCode != null) {
          navigator?.pop(qrCode);
        }
      }
    });
  }

  void _showQrSelectionDialog(
    Route<dynamic> route,
    MockQrScannerConfig config,
  ) {
    final context = navigator?.context;
    if (context == null || !context.mounted) return;

    final scenarios = SpruceQrFixtures.testScenarios();

    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mock QR Scanner - Select QR Code'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              // Show queued QR codes
              if (config.qrQueue.isNotEmpty) ...[
                const ListTile(
                  title: Text(
                    'Queued QR Codes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...config.qrQueue.asMap().entries.map((entry) {
                  return ListTile(
                    leading: CircleAvatar(child: Text('${entry.key + 1}')),
                    title: Text('Queued #${entry.key + 1}'),
                    subtitle: Text(
                      entry.value.length > 50
                          ? '${entry.value.substring(0, 47)}...'
                          : entry.value,
                      style: const TextStyle(fontSize: 10),
                    ),
                    onTap: () {
                      Navigator.pop(context, entry.value);
                    },
                  );
                }),
                const Divider(),
              ],

              // Show current QR code
              if (config.currentQrCode != null) ...[
                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text('Current QR Code'),
                  subtitle: Text(
                    config.currentQrCode!.length > 50
                        ? '${config.currentQrCode!.substring(0, 47)}...'
                        : config.currentQrCode!,
                    style: const TextStyle(fontSize: 10),
                  ),
                  onTap: () {
                    Navigator.pop(context, config.currentQrCode);
                  },
                ),
                const Divider(),
              ],

              // Show test scenarios
              const ListTile(
                title: Text(
                  'Test Scenarios',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ...scenarios.entries.map((entry) {
                return ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: Text(_formatScenarioName(entry.key)),
                  subtitle: Text(
                    entry.value.length > 50
                        ? '${entry.value.substring(0, 47)}...'
                        : entry.value,
                    style: const TextStyle(fontSize: 10),
                  ),
                  onTap: () {
                    Navigator.pop(context, entry.value);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ).then((selectedQr) {
      if (selectedQr != null) {
        navigator?.pop(selectedQr);
      } else {
        navigator?.pop();
      }
    });
  }

  String _formatScenarioName(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Helper function to create a navigator with mock QR scanner support
/// Use this in tests to enable QR scanner mocking
NavigatorObserver createMockQrScannerObserver([MockQrScannerConfig? config]) {
  if (config != null) {
    setMockQrScannerConfig(config);
  }
  return MockQrScannerNavigatorObserver();
}

/// Convenience functions for test setup
extension MockQrScannerTestHelpers on MockQrScannerConfig {
  /// Load a specific credential offer scenario
  void loadCredentialOfferScenario(String type) {
    switch (type) {
      case 'university_degree':
        currentQrCode = Oid4VcQrFixtures.universityDegreeOffer();
        break;
      case 'driver_license':
        currentQrCode = Oid4VcQrFixtures.driverLicenseOffer();
        break;
      case 'identity':
        currentQrCode = Oid4VcQrFixtures.identityOffer();
        break;
      case 'certificate':
        currentQrCode = Oid4VcQrFixtures.certificateOffer();
        break;
      case 'membership':
        currentQrCode = Oid4VcQrFixtures.membershipOffer();
        break;
      case 'employment':
        currentQrCode = Oid4VcQrFixtures.employmentOffer();
        break;
      case 'mdoc':
        currentQrCode = Oid4VcQrFixtures.mdocOffer();
        break;
      case 'sd_jwt':
        currentQrCode = Oid4VcQrFixtures.sdJwtOffer();
        break;
      default:
        currentQrCode = Oid4VcQrFixtures.universityDegreeOffer();
    }
  }

  /// Load a presentation request scenario
  void loadPresentationRequestScenario(String type) {
    switch (type) {
      case 'basic':
        currentQrCode = W3cPresentationQrFixtures.basicRequest();
        break;
      case 'driver_license':
        currentQrCode = W3cPresentationQrFixtures.driverLicenseRequest();
        break;
      case 'selective_disclosure':
        currentQrCode = W3cPresentationQrFixtures.selectiveDisclosureRequest();
        break;
      case 'multi_credential':
        currentQrCode = W3cPresentationQrFixtures.multiCredentialRequest();
        break;
      case 'mdoc_mdl':
        currentQrCode = MDocPresentationQrFixtures.mdlRequest();
        break;
      case 'mdoc_mid':
        currentQrCode = MDocPresentationQrFixtures.midRequest();
        break;
      case 'mdoc_passport':
        currentQrCode = MDocPresentationQrFixtures.passportRequest();
        break;
      case 'age_verification':
        currentQrCode = MDocPresentationQrFixtures.ageVerificationRequest();
        break;
      default:
        currentQrCode = W3cPresentationQrFixtures.basicRequest();
    }
  }

  /// Load a TOTP/HOTP scenario
  void loadTotpHotpScenario(String type) {
    switch (type) {
      case 'totp_basic':
        currentQrCode = TotpHotpQrFixtures.totpBasic();
        break;
      case 'totp_custom':
        currentQrCode = TotpHotpQrFixtures.totpCustom();
        break;
      case 'hotp':
        currentQrCode = TotpHotpQrFixtures.hotpBasic();
        break;
      case 'steam':
        currentQrCode = TotpHotpQrFixtures.steamGuard();
        break;
      default:
        currentQrCode = TotpHotpQrFixtures.totpBasic();
    }
  }

  /// Queue multiple credential offers for sequential scanning
  void queueCredentialOffers(List<String> types) {
    for (final type in types) {
      final config = MockQrScannerConfig();
      config.loadCredentialOfferScenario(type);
      if (config.currentQrCode != null) {
        qrQueue.add(config.currentQrCode!);
      }
    }
  }
}

/// Example usage in tests:
///
/// ```dart
/// void main() {
///   testWidgets('Test credential acceptance flow', (tester) async {
///     // Enable QR mocking with a university degree offer
///     final mockConfig = MockQrScannerConfig()
///       ..loadCredentialOfferScenario('university_degree');
///     setMockQrScannerConfig(mockConfig);
///
///     await tester.pumpWidget(
///       MaterialApp(
///         navigatorObservers: [createMockQrScannerObserver()],
///         home: MyApp(),
///       ),
///     );
///
///     // Tap QR scanner button
///     await tester.tap(find.byIcon(Icons.qr_code_scanner));
///     await tester.pumpAndSettle();
///
///     // Mock will automatically return the QR code
///     // Test can verify the credential was processed
///   });
/// }
/// ```
