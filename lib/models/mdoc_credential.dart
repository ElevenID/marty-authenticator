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

import 'credential.dart';

/// ISO 18013-5 mDoc credential (Mobile Driving License, mID, mPassport).
///
/// This is Marty's canonical representation of mDoc credentials.
/// All CBOR parsing and trust chain verification happens in the Marty Rust layer.
class MDocCredential implements Credential {
  /// Document type (e.g., "org.iso.18013.5.1.mDL")
  final String docType;

  /// Issuer-signed data containing namespaces and claims
  final Map<String, dynamic> issuerSigned;

  /// Device-signed data for holder binding
  final Map<String, dynamic> deviceSigned;

  /// Portrait image (base64 encoded)
  final String? portrait;

  /// Signature/mark image (base64 encoded)
  final String? signatureImage;

  /// Issue date
  final DateTime? issueDate;

  /// Expiry date
  final DateTime? expiryDate;

  /// Trust chain verification info
  final TrustInfo? trustInfo;

  /// Internal unique identifier
  final String _id;

  MDocCredential({
    String? id,
    required this.docType,
    required this.issuerSigned,
    required this.deviceSigned,
    this.portrait,
    this.signatureImage,
    this.issueDate,
    this.expiryDate,
    this.trustInfo,
  }) : _id = id ?? _generateId();

  static String _generateId() {
    return 'mdoc_${DateTime.now().millisecondsSinceEpoch}';
  }

  factory MDocCredential.fromCbor(Map<String, dynamic> cborData) {
    return MDocCredential(
      id: cborData['id'],
      docType: cborData['docType'] ?? 'org.iso.18013.5.1.mDL',
      issuerSigned: Map<String, dynamic>.from(cborData['issuerSigned'] ?? {}),
      deviceSigned: Map<String, dynamic>.from(cborData['deviceSigned'] ?? {}),
      portrait: cborData['portrait'],
      signatureImage: cborData['signature_usual_mark'],
      issueDate: cborData['issue_date'] != null
          ? DateTime.tryParse(cborData['issue_date'])
          : null,
      expiryDate: cborData['expiry_date'] != null
          ? DateTime.tryParse(cborData['expiry_date'])
          : null,
      trustInfo: cborData['trustInfo'] != null
          ? TrustInfo.fromJson(cborData['trustInfo'])
          : null,
    );
  }

  factory MDocCredential.fromJson(Map<String, dynamic> json) {
    return MDocCredential.fromCbor(json);
  }

  @override
  String get id => _id;

  @override
  List<String> get types => [docType];

  @override
  String get displayName => documentType;

  /// Human-readable document type name
  String get documentType {
    switch (docType) {
      case 'org.iso.18013.5.1.mDL':
        return 'Mobile Driving License';
      case 'org.iso.18013.5.1.mID':
        return 'Mobile ID';
      case 'org.iso.18013.5.1.mPassport':
        return 'Mobile Passport';
      default:
        return 'Mobile Document';
    }
  }

  @override
  String get issuerId => issuingAuthority;

  @override
  String get issuerName => issuingAuthority;

  /// Get the issuing authority from namespace claims
  String get issuingAuthority {
    return _getClaimFromNamespace('org.iso.18013.5.1', 'issuing_authority') ??
        'Issuing Authority';
  }

  /// Get the issuing country (ISO 3166-1 alpha-2)
  String get issuingCountry {
    return _getClaimFromNamespace('org.iso.18013.5.1', 'issuing_country') ??
        'Unknown';
  }

  /// Get the holder's full name
  String get holderName {
    final givenName = _getClaimFromNamespace('org.iso.18013.5.1', 'given_name');
    final familyName = _getClaimFromNamespace(
      'org.iso.18013.5.1',
      'family_name',
    );

    if (givenName != null && familyName != null) {
      return '$givenName $familyName';
    }
    return givenName ?? familyName ?? 'Document Holder';
  }

  /// Get the document number
  String get documentNumber {
    return _getClaimFromNamespace('org.iso.18013.5.1', 'document_number') ??
        '••••••••';
  }

  /// Calculate holder's age from birth date
  int? get age {
    final birthDateStr = _getClaimFromNamespace(
      'org.iso.18013.5.1',
      'birth_date',
    );
    if (birthDateStr == null) return null;

    try {
      final birthDate = DateTime.parse(birthDateStr);
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  /// Check age over threshold claims
  bool? isAgeOver(int threshold) {
    final claimName = 'age_over_$threshold';
    final value = _getClaimFromNamespace('org.iso.18013.5.1', claimName);
    if (value == null) return null;
    return value == 'true';
  }

  @override
  String get issuanceDate {
    return issueDate?.toIso8601String() ?? '';
  }

  @override
  String? get expirationDate {
    return expiryDate?.toIso8601String();
  }

  @override
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  @override
  bool get isValid => !isExpired && (trustInfo?.isValid ?? true);

  @override
  CredentialStatus get status {
    if (isExpired) return CredentialStatus.expired;
    if (trustInfo != null && !trustInfo!.isValid) {
      return CredentialStatus.invalid;
    }
    return CredentialStatus.valid;
  }

  @override
  Map<String, dynamic> get claims {
    final allClaims = <String, dynamic>{};
    final nameSpaces = issuerSigned['nameSpaces'] as Map<String, dynamic>?;
    if (nameSpaces == null) return allClaims;

    for (final namespace in nameSpaces.entries) {
      final nsData = namespace.value;
      if (nsData is List) {
        for (final item in nsData) {
          if (item is Map<String, dynamic>) {
            final identifier = item['elementIdentifier'];
            final value = item['elementValue'];
            if (identifier != null) {
              allClaims[identifier] = value;
            }
          }
        }
      } else if (nsData is Map<String, dynamic>) {
        allClaims.addAll(nsData);
      }
    }
    return allClaims;
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'docType': docType,
    'issuerSigned': issuerSigned,
    'deviceSigned': deviceSigned,
    if (portrait != null) 'portrait': portrait,
    if (signatureImage != null) 'signature_usual_mark': signatureImage,
    if (issueDate != null) 'issue_date': issueDate!.toIso8601String(),
    if (expiryDate != null) 'expiry_date': expiryDate!.toIso8601String(),
    if (trustInfo != null) 'trustInfo': trustInfo!.toJson(),
  };

  /// Get a claim value from a specific namespace
  String? _getClaimFromNamespace(String namespace, String claimName) {
    final nameSpaces = issuerSigned['nameSpaces'] as Map<String, dynamic>?;
    if (nameSpaces == null) return null;

    final nsData = nameSpaces[namespace];
    if (nsData == null) return null;

    // Handle list-based structure (array of claim items)
    if (nsData is List) {
      for (final item in nsData) {
        if (item is Map<String, dynamic> &&
            item['elementIdentifier'] == claimName) {
          final value = item['elementValue'];
          return value?.toString();
        }
      }
    }

    // Handle map-based structure
    if (nsData is Map<String, dynamic>) {
      final value = nsData[claimName];
      return value?.toString();
    }

    return null;
  }

  /// Create a copy with updated trust info
  MDocCredential copyWithTrustInfo(TrustInfo trustInfo) {
    return MDocCredential(
      id: id,
      docType: docType,
      issuerSigned: issuerSigned,
      deviceSigned: deviceSigned,
      portrait: portrait,
      signatureImage: signatureImage,
      issueDate: issueDate,
      expiryDate: expiryDate,
      trustInfo: trustInfo,
    );
  }
}
