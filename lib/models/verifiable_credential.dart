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
import '../services/status_list_service.dart';

/// Cached status check result for a credential
class CachedStatusCheck {
  final StatusCheckResult result;
  final DateTime cachedAt;

  const CachedStatusCheck({required this.result, required this.cachedAt});

  /// Status checks are valid for 5 minutes (matching server cache TTL)
  bool get isExpired =>
      DateTime.now().difference(cachedAt) > const Duration(minutes: 5);
}

/// W3C Verifiable Credential model.
///
/// Represents a W3C VC Data Model 1.1/2.0 compliant credential.
/// This is Marty's canonical representation - all parsing and validation
/// happens in the Marty Rust layer.
class VerifiableCredential implements Credential {
  @override
  final String id;

  @override
  final List<String> types;

  final Map<String, dynamic> issuer;
  final Map<String, dynamic> credentialSubject;

  @override
  final String issuanceDate;

  @override
  final String? expirationDate;

  final Map<String, dynamic>? proof;
  final List<String>? context;
  final Map<String, dynamic>? credentialStatus;

  /// Trust chain verification info (populated after verification)
  final TrustInfo? trustInfo;

  /// Raw JSON for pass-through to platform layer
  final String? rawJson;

  /// Cached status check result
  CachedStatusCheck? _cachedStatusCheck;

  VerifiableCredential({
    required this.id,
    required this.types,
    required this.issuer,
    required this.credentialSubject,
    required this.issuanceDate,
    this.expirationDate,
    this.proof,
    this.context,
    this.credentialStatus,
    this.trustInfo,
    this.rawJson,
  });

  factory VerifiableCredential.fromJson(Map<String, dynamic> json) {
    return VerifiableCredential(
      id: json['id'] ?? '',
      types: List<String>.from(json['type'] ?? ['VerifiableCredential']),
      issuer: json['issuer'] is String
          ? {'id': json['issuer']}
          : Map<String, dynamic>.from(json['issuer'] ?? {}),
      credentialSubject: Map<String, dynamic>.from(
        json['credentialSubject'] ?? {},
      ),
      issuanceDate: json['issuanceDate'] ?? '',
      expirationDate: json['expirationDate'],
      proof: json['proof'] != null
          ? Map<String, dynamic>.from(json['proof'])
          : null,
      context: json['@context'] != null
          ? (json['@context'] is List
                ? List<String>.from(json['@context'])
                : [json['@context'].toString()])
          : null,
      credentialStatus: json['credentialStatus'] != null
          ? Map<String, dynamic>.from(json['credentialStatus'])
          : null,
      trustInfo: json['trustInfo'] != null
          ? TrustInfo.fromJson(json['trustInfo'])
          : null,
      rawJson: json['_rawJson'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': types,
    '@context': context,
    'issuer': issuer,
    'credentialSubject': credentialSubject,
    'issuanceDate': issuanceDate,
    if (expirationDate != null) 'expirationDate': expirationDate,
    if (proof != null) 'proof': proof,
    if (credentialStatus != null) 'credentialStatus': credentialStatus,
    if (trustInfo != null) 'trustInfo': trustInfo!.toJson(),
  };

  @override
  String get issuerId => issuer['id'] as String? ?? '';

  @override
  String get issuerName {
    if (issuer.containsKey('name')) {
      return issuer['name'] as String;
    }

    final issuerId = this.issuerId;
    if (issuerId.startsWith('did:web:')) {
      return issuerId.replaceFirst('did:web:', '').split('.').first;
    } else if (issuerId.startsWith('did:')) {
      return issuerId.split(':')[1];
    }

    return 'Unknown Issuer';
  }

  @override
  String get displayName {
    final subject = credentialSubject;
    return subject['name'] as String? ??
        subject['given_name'] as String? ??
        subject['id'] as String? ??
        credentialType;
  }

  /// Get the primary credential type (excluding "VerifiableCredential")
  String get credentialType {
    final typeValue =
        types.where((t) => t != 'VerifiableCredential').firstOrNull ??
        'Credential';
    final normalized = typeValue.toLowerCase();

    if (normalized == 'openbadgecredential' ||
        normalized == 'achievementcredential' ||
        normalized == 'openbadgeassertion') {
      return 'Open Badge';
    }

    return typeValue;
  }

  @override
  bool get isExpired {
    if (expirationDate == null) return false;
    try {
      return DateTime.parse(expirationDate!).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isValid => proof != null && !isExpired;

  @override
  CredentialStatus get status {
    if (isExpired) return CredentialStatus.expired;
    if (!isValid) return CredentialStatus.invalid;
    return CredentialStatus.valid;
  }

  @override
  Map<String, dynamic> get claims => credentialSubject;

  /// Create a copy with updated trust info
  VerifiableCredential copyWithTrustInfo(TrustInfo trustInfo) {
    return VerifiableCredential(
      id: id,
      types: types,
      issuer: issuer,
      credentialSubject: credentialSubject,
      issuanceDate: issuanceDate,
      expirationDate: expirationDate,
      proof: proof,
      context: context,
      credentialStatus: credentialStatus,
      trustInfo: trustInfo,
      rawJson: rawJson,
    );
  }

  /// Check if this credential has a status list entry
  bool get hasStatusEntry => credentialStatus != null;

  /// Check if this credential supports revocation
  bool get supportsRevocation {
    if (credentialStatus == null) return false;
    final purpose = credentialStatus!['statusPurpose'] as String?;
    return purpose == 'revocation' || _hasStatusPurposeInArray('revocation');
  }

  /// Check if this credential supports suspension
  bool get supportsSuspension {
    if (credentialStatus == null) return false;
    final purpose = credentialStatus!['statusPurpose'] as String?;
    return purpose == 'suspension' || _hasStatusPurposeInArray('suspension');
  }

  bool _hasStatusPurposeInArray(String purpose) {
    // If credentialStatus is an array-like structure with multiple entries
    // This handles the case where both revocation and suspension are present
    if (credentialStatus == null) return false;

    // Check for array format (would need to be parsed from raw JSON)
    // For now, check if there are multiple entries with different purposes
    return credentialStatus!['statusPurpose'] == purpose;
  }

  /// Check the revocation/suspension status of this credential
  ///
  /// Uses the StatusListService to fetch and check the status list.
  /// Results are cached for 5 minutes.
  Future<StatusCheckResult> checkStatus(StatusListService service) async {
    // Return cached result if still valid
    if (_cachedStatusCheck != null && !_cachedStatusCheck!.isExpired) {
      return _cachedStatusCheck!.result;
    }

    // Check status
    final result = await service.checkCredentialStatus(credentialStatus);

    // Cache the result
    _cachedStatusCheck = CachedStatusCheck(
      result: result,
      cachedAt: DateTime.now(),
    );

    return result;
  }

  /// Check revocation status only
  Future<bool?> checkRevocationStatus(StatusListService service) async {
    if (!hasStatusEntry) return null;
    return service.checkRevocationStatus(credentialStatus);
  }

  /// Check suspension status only
  Future<bool?> checkSuspensionStatus(StatusListService service) async {
    if (!hasStatusEntry) return null;
    return service.checkSuspensionStatus(credentialStatus);
  }

  /// Get the current status including revocation/suspension check
  ///
  /// If a cached status check indicates revocation, returns [CredentialStatus.revoked].
  /// If suspended, could return a suspended status (if added to enum).
  CredentialStatus getStatusWithRevocation() {
    if (isExpired) return CredentialStatus.expired;
    if (!isValid) return CredentialStatus.invalid;

    // Check cached status for revocation
    if (_cachedStatusCheck != null &&
        !_cachedStatusCheck!.isExpired &&
        _cachedStatusCheck!.result.success) {
      if (_cachedStatusCheck!.result.isRevoked == true) {
        return CredentialStatus.revoked;
      }
      // Note: Could add CredentialStatus.suspended if needed
    }

    return CredentialStatus.valid;
  }

  /// Clear the cached status check
  void clearStatusCache() {
    _cachedStatusCheck = null;
  }
}
