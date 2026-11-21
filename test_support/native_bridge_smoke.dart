import 'dart:convert';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/api.dart';
import 'package:marty_authenticator/rust/marty_bridge.dart/frb_generated.dart';

/// Loads the real native bridge and checks FFI serialization, without a backend.
/// Offer parsing is display input only; this does not verify or issue a credential.
Future<void> main() async {
  await RustLib.init().timeout(const Duration(seconds: 30));
  try {
    final offer = jsonEncode({
      'credential_issuer': 'https://issuer.example',
      'credential_configuration_ids': ['ExampleCredential'],
      'grants': {
        'authorization_code': {'issuer_state': 'synthetic-bridge-smoke'},
      },
    });
    final parsed = await walletParseCredentialOffer(
      offerUri:
          'openid-credential-offer://?credential_offer=${Uri.encodeQueryComponent(offer)}',
    );
    if (parsed.credentialIssuer != 'https://issuer.example' ||
        parsed.credentialConfigurationIds.length != 1 ||
        parsed.credentialConfigurationIds.single != 'ExampleCredential') {
      throw StateError('Native offer serialization mismatch');
    }
    var malformedRejected = false;
    try {
      await credentialFromJson(json: '{}');
    } on AnyhowException {
      malformedRejected = true;
    }
    if (!malformedRejected) {
      throw StateError('Malformed native credential was accepted');
    }
    stdout.writeln(
      jsonEncode({
        'nativeInitialized': true,
        'offerRoundTrip': true,
        'malformedCredentialRejected': true,
        'scope': 'native bridge load/serialization, not wallet acceptance',
      }),
    );
  } finally {
    RustLib.dispose();
  }
}
