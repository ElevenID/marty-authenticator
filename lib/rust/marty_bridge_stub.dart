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

/// Marty Rust Bridge - Stub Implementation
///
/// This file provides stub implementations until flutter_rust_bridge codegen
/// generates the actual FFI bindings. Run:
///
///   flutter_rust_bridge_codegen generate
///
/// to generate the real bindings from rust/src/api.rs.
library;

import 'dart:convert' show JsonDecoder;

import 'dart:typed_data';

import '../models/credentials.dart';

// ============================================================================
// Credential Parsing Stubs
// ============================================================================

/// Parse a raw JSON string into a VerifiableCredential.
///
/// TODO: Replace with generated flutter_rust_bridge binding.
Future<VerifiableCredential> rustParseVerifiableCredential(String json) async {
  // Stub: use Dart JSON parsing until Rust bridge is ready
  final data = _parseJson(json);
  return VerifiableCredential.fromJson(data);
}

/// Parse CBOR bytes into an MDocCredential.
///
/// TODO: Replace with generated flutter_rust_bridge binding.
Future<MDocCredential> rustParseMDocCredential(Uint8List cborBytes) async {
  // Stub: CBOR parsing requires Rust, throw for now
  throw UnimplementedError(
    'CBOR parsing requires Rust bridge. Run flutter_rust_bridge_codegen generate.',
  );
}

/// Parse SD-JWT string into an SdJwtCredential model.
///
/// TODO: Replace with generated flutter_rust_bridge binding.
Future<Map<String, dynamic>> rustParseSdJwtCredential(String sdJwt) async {
  // Stub: SD-JWT parsing requires Rust
  throw UnimplementedError(
    'SD-JWT parsing requires Rust bridge. Run flutter_rust_bridge_codegen generate.',
  );
}

// ============================================================================
// Trust Chain Verification Stubs
// ============================================================================

/// Verify mDoc trust chain from X.509 certificate chain.
///
/// TODO: Replace with generated flutter_rust_bridge binding.
Future<TrustInfo> rustVerifyMDocTrustChain(List<Uint8List> x5chain) async {
  // Stub: return unknown trust status until Rust bridge is ready
  return const TrustInfo(
    isValid: false,
    statusMessage: 'Trust verification requires Rust bridge',
  );
}

/// Verify Verifiable Credential signature.
///
/// TODO: Replace with generated flutter_rust_bridge binding.
Future<bool> rustVerifyVcSignature(String vcJson) async {
  // Stub: signature verification requires Rust
  return false;
}

// ============================================================================
// Credential Grouping Stubs
// ============================================================================

/// Group credentials by issuer.
///
/// This can be done in Dart but Rust version is more efficient.
/// TODO: Replace with generated flutter_rust_bridge binding.
List<CredentialGroup> rustGroupCredentialsByIssuer(List<dynamic> credentials) {
  final groups = <String, CredentialGroup>{};

  for (final cred in credentials) {
    String issuerName;
    if (cred is VerifiableCredential) {
      issuerName = cred.issuerName;
    } else if (cred is MDocCredential) {
      issuerName = cred.issuerName;
    } else {
      continue;
    }

    if (!groups.containsKey(issuerName)) {
      groups[issuerName] = CredentialGroup(issuerName: issuerName);
    }

    final existing = groups[issuerName]!;
    if (cred is VerifiableCredential) {
      groups[issuerName] = existing.copyWith(
        verifiableCredentials: [...existing.verifiableCredentials, cred],
      );
    } else if (cred is MDocCredential) {
      groups[issuerName] = existing.copyWith(
        mDocCredentials: [...existing.mDocCredentials, cred],
      );
    }
  }

  return groups.values.toList();
}

// ============================================================================
// Helper Functions
// ============================================================================

Map<String, dynamic> _parseJson(String json) {
  // Simple JSON parsing - production code should use Rust
  try {
    final decoded = _jsonDecode(json);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw FormatException('Expected JSON object, got ${decoded.runtimeType}');
  } catch (e) {
    throw FormatException('Invalid JSON: $e');
  }
}

dynamic _jsonDecode(String json) {
  // Use dart:convert
  return const _JsonDecoder().convert(json);
}

class _JsonDecoder {
  const _JsonDecoder();

  dynamic convert(String json) {
    // Delegate to dart:convert
    return _dartConvertJsonDecode(json);
  }
}

// Import dart:convert inline to avoid circular dependencies
dynamic _dartConvertJsonDecode(String json) {
  // ignore: depend_on_referenced_packages
  return (const JsonDecoder()).convert(json);
}
