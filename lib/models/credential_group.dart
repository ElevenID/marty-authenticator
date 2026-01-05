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

import '../model/promotional_credential.dart';
import 'verifiable_credential.dart';
import 'mdoc_credential.dart';

/// Grouping of credentials by issuer for stacked display.
///
/// Used by the UI to show credentials from the same issuer
/// as a collapsible stack with horizontal scrolling.
class CredentialGroup {
  /// Issuer name (display name)
  final String issuerName;

  /// W3C Verifiable Credentials from this issuer
  final List<VerifiableCredential> verifiableCredentials;

  /// mDoc credentials from this issuer
  final List<MDocCredential> mDocCredentials;

  /// Promotional/demo credentials
  final List<PromotionalCredential> promotionalCredentials;

  /// Whether this group contains promotional credentials
  final bool isPromotional;

  /// Optional issuer logo URL
  final String? logoUrl;

  const CredentialGroup({
    required this.issuerName,
    this.verifiableCredentials = const [],
    this.mDocCredentials = const [],
    this.promotionalCredentials = const [],
    this.isPromotional = false,
    this.logoUrl,
  });

  /// Total number of credentials in this group
  int get totalCount =>
      verifiableCredentials.length +
      mDocCredentials.length +
      promotionalCredentials.length;

  /// Whether this group contains exactly one credential
  bool get hasSingle => totalCount == 1;

  /// Whether this group contains multiple credentials
  bool get hasMultiple => totalCount > 1;

  /// Whether this group is empty
  bool get isEmpty => totalCount == 0;

  /// Get all credentials as a mixed list for iteration
  List<dynamic> get allCredentials => [
    ...promotionalCredentials,
    ...verifiableCredentials,
    ...mDocCredentials,
  ];

  /// Get the primary (first) credential for stack preview
  dynamic get primaryCredential {
    if (promotionalCredentials.isNotEmpty) {
      return promotionalCredentials.first;
    }
    if (verifiableCredentials.isNotEmpty) {
      return verifiableCredentials.first;
    }
    if (mDocCredentials.isNotEmpty) {
      return mDocCredentials.first;
    }
    return null;
  }

  /// Whether this group contains holder documents (mDL, mID, mPassport)
  bool get hasHolderDocuments {
    return mDocCredentials.any(
      (mdoc) =>
          mdoc.docType == 'org.iso.18013.5.1.mDL' ||
          mdoc.docType == 'org.iso.18013.5.1.mID' ||
          mdoc.docType == 'org.iso.18013.5.1.mPassport',
    );
  }

  /// Create a copy with additional credentials
  CredentialGroup copyWith({
    String? issuerName,
    List<VerifiableCredential>? verifiableCredentials,
    List<MDocCredential>? mDocCredentials,
    List<PromotionalCredential>? promotionalCredentials,
    bool? isPromotional,
    String? logoUrl,
  }) {
    return CredentialGroup(
      issuerName: issuerName ?? this.issuerName,
      verifiableCredentials:
          verifiableCredentials ?? this.verifiableCredentials,
      mDocCredentials: mDocCredentials ?? this.mDocCredentials,
      promotionalCredentials:
          promotionalCredentials ?? this.promotionalCredentials,
      isPromotional: isPromotional ?? this.isPromotional,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}
