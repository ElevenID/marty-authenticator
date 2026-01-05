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

import 'dart:convert';
import 'dart:typed_data';

import '../models/credentials.dart';
import '../interfaces/spruce_interfaces.dart';
import '../utils/logger.dart';
import 'credential_repository.dart';

// Import Rust bridge for parsing
import '../rust/rust_bridge.dart' as rust;

/// Implementation of CredentialRepository using Marty Rust layer + SpruceID transport.
///
/// This implementation:
/// - Uses the Marty Rust layer (via flutter_rust_bridge) for parsing and validation
/// - Uses SpruceID platform services for storage transport
/// - Keeps all credential logic in Marty, SpruceID is just transport
class MartyCredentialRepository implements CredentialRepository {
  final ISpruceIdWalletManager _walletManager;
  bool _rustInitialized = false;

  // Cached credentials for performance
  List<VerifiableCredential>? _vcCache;
  List<MDocCredential>? _mdocCache;

  MartyCredentialRepository({required ISpruceIdWalletManager walletManager})
    : _walletManager = walletManager;

  /// Ensure Rust bridge is initialized
  Future<void> _ensureRustInitialized() async {
    if (!_rustInitialized) {
      await rust.RustLib.init();
      _rustInitialized = true;
    }
  }

  @override
  Future<List<Credential>> getAllCredentials() async {
    final vcs = await getVerifiableCredentials();
    final mdocs = await getMDocCredentials();
    return [...vcs, ...mdocs];
  }

  @override
  Future<List<VerifiableCredential>> getVerifiableCredentials() async {
    if (_vcCache != null) return _vcCache!;

    try {
      final rawCredentials = await _walletManager.getAllCredentials();
      final vcs = <VerifiableCredential>[];

      for (final raw in rawCredentials) {
        if (_isVerifiableCredential(raw)) {
          try {
            final vc = await parseVerifiableCredential(jsonEncode(raw));
            vcs.add(vc);
          } catch (e) {
            Logger.warning('Failed to parse VC: $e');
          }
        }
      }

      _vcCache = vcs;
      return vcs;
    } catch (e) {
      Logger.error('Failed to get verifiable credentials', error: e);
      rethrow;
    }
  }

  @override
  Future<List<MDocCredential>> getMDocCredentials() async {
    if (_mdocCache != null) return _mdocCache!;

    try {
      final rawCredentials = await _walletManager.getAllCredentials();
      final mdocs = <MDocCredential>[];

      for (final raw in rawCredentials) {
        if (_isMDocCredential(raw)) {
          try {
            final mdoc = MDocCredential.fromCbor(raw);
            mdocs.add(mdoc);
          } catch (e) {
            Logger.warning('Failed to parse mDoc: $e');
          }
        }
      }

      _mdocCache = mdocs;
      return mdocs;
    } catch (e) {
      Logger.error('Failed to get mDoc credentials', error: e);
      rethrow;
    }
  }

  @override
  Future<Credential?> getCredentialById(String id) async {
    final all = await getAllCredentials();
    return all.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<void> storeCredential(Credential credential) async {
    try {
      await _walletManager.storeCredential(credential.toJson());
      _invalidateCache();
    } catch (e) {
      Logger.error('Failed to store credential', error: e);
      throw CredentialError(
        type: CredentialErrorType.storageError,
        message: 'Failed to store credential: $e',
        cause: e,
      );
    }
  }

  @override
  Future<void> deleteCredential(String id) async {
    try {
      await _walletManager.deleteCredential(id);
      _invalidateCache();
    } catch (e) {
      Logger.error('Failed to delete credential', error: e);
      throw CredentialError(
        type: CredentialErrorType.storageError,
        message: 'Failed to delete credential: $e',
        cause: e,
      );
    }
  }

  @override
  Future<VerifiableCredential> parseVerifiableCredential(String json) async {
    await _ensureRustInitialized();

    try {
      // Parse using Rust bridge
      final rustVc = await rust.parseVerifiableCredential(json: json);

      // Convert from Rust type to our domain model
      return _convertVcFromRust(rustVc);
    } catch (e) {
      throw CredentialError(
        type: CredentialErrorType.parseError,
        message: 'Failed to parse Verifiable Credential: $e',
        cause: e,
      );
    }
  }

  @override
  Future<MDocCredential> parseMDocCredential(Uint8List cbor) async {
    await _ensureRustInitialized();

    try {
      // Parse using Rust bridge
      final rustMdoc = await rust.parseMdocCredential(cborBytes: cbor.toList());

      // Convert from Rust type to our domain model
      return _convertMDocFromRust(rustMdoc);
    } catch (e) {
      throw CredentialError(
        type: CredentialErrorType.parseError,
        message: 'Failed to parse mDoc credential: $e',
        cause: e,
      );
    }
  }

  @override
  Future<TrustInfo> verifyMDocTrustChain(List<Uint8List> x5chain) async {
    await _ensureRustInitialized();

    try {
      // Verify using Rust bridge
      final rustTrust = await rust.verifyMdocTrustChain(x5Chain: x5chain);

      // Convert from Rust type to our domain model
      return _convertTrustInfoFromRust(rustTrust);
    } catch (e) {
      Logger.warning('Trust chain verification failed: $e');
      return const TrustInfo(
        isValid: false,
        statusMessage: 'Trust chain verification failed',
      );
    }
  }

  @override
  Future<Credential> verifyAndAttachTrust(
    Credential credential,
    List<Uint8List> x5chain,
  ) async {
    final trustInfo = await verifyMDocTrustChain(x5chain);

    if (credential is MDocCredential) {
      return credential.copyWithTrustInfo(trustInfo);
    } else if (credential is VerifiableCredential) {
      return credential.copyWithTrustInfo(trustInfo);
    }

    return credential;
  }

  @override
  Future<List<CredentialGroup>> groupByIssuer() async {
    final credentials = await getAllCredentials();
    final groups = <String, CredentialGroup>{};

    for (final credential in credentials) {
      final issuerName = credential.issuerName;

      if (!groups.containsKey(issuerName)) {
        groups[issuerName] = CredentialGroup(issuerName: issuerName);
      }

      final existing = groups[issuerName]!;

      if (credential is VerifiableCredential) {
        groups[issuerName] = existing.copyWith(
          verifiableCredentials: [
            ...existing.verifiableCredentials,
            credential,
          ],
        );
      } else if (credential is MDocCredential) {
        groups[issuerName] = existing.copyWith(
          mDocCredentials: [...existing.mDocCredentials, credential],
        );
      }
    }

    return groups.values.toList();
  }

  @override
  Future<List<Credential>> searchCredentials({
    String? type,
    String? issuer,
    bool includeExpired = false,
  }) async {
    var credentials = await getAllCredentials();

    if (!includeExpired) {
      credentials = credentials.where((c) => !c.isExpired).toList();
    }

    if (type != null) {
      credentials = credentials
          .where((c) => c.types.any((t) => t.contains(type)))
          .toList();
    }

    if (issuer != null) {
      credentials = credentials
          .where(
            (c) =>
                c.issuerName.toLowerCase().contains(issuer.toLowerCase()) ||
                c.issuerId.toLowerCase().contains(issuer.toLowerCase()),
          )
          .toList();
    }

    return credentials;
  }

  @override
  Future<List<SelectableCredential>> getMatchingCredentials({
    required List<String> requestedTypes,
    required List<String> requestedAttributes,
  }) async {
    final credentials = await getAllCredentials();
    final matching = <SelectableCredential>[];

    for (final credential in credentials) {
      // Check if credential type matches any requested type
      final typeMatches =
          requestedTypes.isEmpty ||
          requestedTypes.any(
            (rt) => credential.types.any(
              (ct) => ct.toLowerCase().contains(rt.toLowerCase()),
            ),
          );

      if (!typeMatches) continue;

      // Check which requested attributes this credential can satisfy
      final credentialClaims = credential.claims.keys.toSet();
      final matchedRequired = requestedAttributes
          .where((attr) => credentialClaims.contains(attr))
          .toList();
      final optionalAttrs = credentialClaims
          .difference(matchedRequired.toSet())
          .toList();

      // Only include if it can satisfy at least one requested attribute
      if (matchedRequired.isNotEmpty || requestedAttributes.isEmpty) {
        if (credential is VerifiableCredential) {
          matching.add(
            SelectableCredential.fromVerifiableCredential(
              credential,
              requiredAttributes: matchedRequired,
              optionalAttributes: optionalAttrs,
            ),
          );
        } else if (credential is MDocCredential) {
          matching.add(
            SelectableCredential.fromMDocCredential(
              credential,
              requiredAttributes: matchedRequired,
              optionalAttributes: optionalAttrs,
            ),
          );
        }
      }
    }

    return matching;
  }

  // ============================================================================
  // Private helpers
  // ============================================================================

  bool _isVerifiableCredential(Map<String, dynamic> data) {
    final type = data['type'];
    if (type is List) {
      return type.contains('VerifiableCredential');
    }
    if (type is String) {
      return type == 'VerifiableCredential';
    }
    // Check for W3C VC structure
    return data.containsKey('credentialSubject') && data.containsKey('issuer');
  }

  bool _isMDocCredential(Map<String, dynamic> data) {
    return data.containsKey('docType') &&
        (data['docType'] as String?)?.startsWith('org.iso.18013') == true;
  }

  void _invalidateCache() {
    _vcCache = null;
    _mdocCache = null;
  }

  // ============================================================================
  // Rust type conversion helpers
  // ============================================================================

  /// Convert Rust VerifiableCredential to our domain model
  VerifiableCredential _convertVcFromRust(rust.VerifiableCredential rustVc) {
    // Parse claims from JSON string
    Map<String, dynamic> claims = {};
    try {
      claims = Map<String, dynamic>.from(
        jsonDecode(rustVc.subject.claimsJson) as Map,
      );
    } catch (e) {
      // If parsing fails, use empty claims
    }

    return VerifiableCredential(
      id: rustVc.id,
      types: rustVc.types,
      issuer: {'id': rustVc.issuer}, // Wrap string issuer in map
      credentialSubject: {'id': rustVc.subject.id, ...claims},
      issuanceDate: rustVc.issuanceDate,
      expirationDate: rustVc.expirationDate,
      proof: rustVc.proof != null
          ? {
              'type': rustVc.proof!.proofType,
              'created': rustVc.proof!.created,
              'verificationMethod': rustVc.proof!.verificationMethod,
              'proofPurpose': rustVc.proof!.proofPurpose,
              'proofValue': rustVc.proof!.proofValue,
            }
          : null,
      rawJson: rustVc.rawJson,
    );
  }

  /// Convert Rust MDocCredential to our domain model
  MDocCredential _convertMDocFromRust(rust.MDocCredential rustMdoc) {
    // Parse namespaces from JSON string
    Map<String, dynamic> issuerSigned = {};
    try {
      final namespaces = jsonDecode(rustMdoc.namespacesJson) as Map;
      // Flatten namespaces into issuerSigned format
      for (final entry in namespaces.entries) {
        issuerSigned[entry.key as String] = entry.value;
      }
    } catch (e) {
      // If parsing fails, use empty namespaces
    }

    return MDocCredential(
      id: rustMdoc.id,
      docType: rustMdoc.docType,
      issuerSigned: issuerSigned,
      deviceSigned: {},
      portrait: rustMdoc.portrait,
      signatureImage: rustMdoc.signature,
      expiryDate: rustMdoc.expiryDate != null
          ? DateTime.tryParse(rustMdoc.expiryDate!)
          : null,
      trustInfo: rustMdoc.trustInfo != null
          ? _convertTrustInfoFromRust(rustMdoc.trustInfo!)
          : null,
    );
  }

  /// Convert Rust TrustInfo to our domain model
  TrustInfo _convertTrustInfoFromRust(rust.TrustInfo rustTrust) {
    return TrustInfo(
      isValid: rustTrust.isValid,
      trustAnchor: rustTrust.trustAnchor,
      statusMessage: rustTrust.statusMessage,
      certificateChain: rustTrust.certificateChain,
    );
  }
}
