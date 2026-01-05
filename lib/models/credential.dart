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

/// Base interface for all credential types in Marty.
///
/// This is the canonical credential abstraction that all credential types
/// implement. All credential logic is owned by Marty, not MMF.
abstract class Credential {
  /// Unique identifier for this credential
  String get id;

  /// The credential type(s) (e.g., ["VerifiableCredential", "UniversityDegree"])
  List<String> get types;

  /// Display name for this credential
  String get displayName;

  /// Issuer identifier (DID or URL)
  String get issuerId;

  /// Human-readable issuer name
  String get issuerName;

  /// When the credential was issued (ISO 8601)
  String get issuanceDate;

  /// When the credential expires (ISO 8601), if applicable
  String? get expirationDate;

  /// Whether this credential has expired
  bool get isExpired;

  /// Whether this credential is currently valid (not expired, properly signed)
  bool get isValid;

  /// Current status of the credential
  CredentialStatus get status;

  /// Convert to JSON for storage/transport
  Map<String, dynamic> toJson();

  /// Get all claims/attributes as key-value pairs
  Map<String, dynamic> get claims;
}

/// Credential validation status
enum CredentialStatus {
  /// Credential is valid and verified
  valid,

  /// Credential has expired
  expired,

  /// Credential signature is invalid
  invalid,

  /// Credential has been revoked
  revoked,

  /// Credential status is unknown (not yet verified)
  unknown,
}

/// Trust chain verification information
class TrustInfo {
  /// Whether the trust chain is valid
  final bool isValid;

  /// Trust anchor used (e.g., IACA jurisdiction, CSCA country)
  final String? trustAnchor;

  /// Status message describing the verification result
  final String? statusMessage;

  /// Certificate chain (PEM encoded)
  final List<String> certificateChain;

  const TrustInfo({
    required this.isValid,
    this.trustAnchor,
    this.statusMessage,
    this.certificateChain = const [],
  });

  factory TrustInfo.fromJson(Map<String, dynamic> json) {
    return TrustInfo(
      isValid: json['is_valid'] as bool? ?? false,
      trustAnchor: json['trust_anchor'] as String?,
      statusMessage: json['status_message'] as String?,
      certificateChain:
          (json['certificate_chain'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'is_valid': isValid,
    'trust_anchor': trustAnchor,
    'status_message': statusMessage,
    'certificate_chain': certificateChain,
  };
}
