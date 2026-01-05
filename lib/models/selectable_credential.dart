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

import 'package:flutter/material.dart';

import 'verifiable_credential.dart';
import 'mdoc_credential.dart';

/// Credential with selection state for presentation.
///
/// Used in OID4VP flows where the user selects which credentials
/// and claims to disclose.
class SelectableCredential {
  /// Unique identifier
  final String id;

  /// Display name for the credential
  final String name;

  /// Credential type
  final String type;

  /// Issuer name
  final String issuer;

  /// All claims available in this credential
  final Map<String, dynamic> claims;

  /// Which attributes are currently selected for disclosure
  final Map<String, bool> attributeSelections;

  /// Whether this credential is selected for presentation
  final bool isSelected;

  /// Current privacy level setting
  final PrivacyLevel privacyLevel;

  /// Attributes required by the verifier
  final List<String> requiredAttributes;

  /// Optional attributes the user can choose to disclose
  final List<String> optionalAttributes;

  const SelectableCredential({
    required this.id,
    required this.name,
    required this.type,
    required this.issuer,
    required this.claims,
    required this.attributeSelections,
    required this.isSelected,
    required this.privacyLevel,
    required this.requiredAttributes,
    required this.optionalAttributes,
  });

  /// Create from a VerifiableCredential
  factory SelectableCredential.fromVerifiableCredential(
    VerifiableCredential vc, {
    List<String> requiredAttributes = const [],
    List<String> optionalAttributes = const [],
  }) {
    final allClaims = vc.claims;
    final initialSelections = <String, bool>{};

    // Pre-select required attributes
    for (final attr in requiredAttributes) {
      if (allClaims.containsKey(attr)) {
        initialSelections[attr] = true;
      }
    }

    return SelectableCredential(
      id: vc.id,
      name: vc.displayName,
      type: vc.credentialType,
      issuer: vc.issuerName,
      claims: allClaims,
      attributeSelections: initialSelections,
      isSelected: false,
      privacyLevel: PrivacyLevel.minimal,
      requiredAttributes: requiredAttributes,
      optionalAttributes: optionalAttributes,
    );
  }

  /// Create from an MDocCredential
  factory SelectableCredential.fromMDocCredential(
    MDocCredential mdoc, {
    List<String> requiredAttributes = const [],
    List<String> optionalAttributes = const [],
  }) {
    final allClaims = mdoc.claims;
    final initialSelections = <String, bool>{};

    // Pre-select required attributes
    for (final attr in requiredAttributes) {
      if (allClaims.containsKey(attr)) {
        initialSelections[attr] = true;
      }
    }

    return SelectableCredential(
      id: mdoc.id,
      name: mdoc.displayName,
      type: mdoc.docType,
      issuer: mdoc.issuerName,
      claims: allClaims,
      attributeSelections: initialSelections,
      isSelected: false,
      privacyLevel: PrivacyLevel.minimal,
      requiredAttributes: requiredAttributes,
      optionalAttributes: optionalAttributes,
    );
  }

  /// Create a copy with updated state
  SelectableCredential copyWith({
    bool? isSelected,
    Map<String, bool>? attributeSelections,
    PrivacyLevel? privacyLevel,
  }) {
    return SelectableCredential(
      id: id,
      name: name,
      type: type,
      issuer: issuer,
      claims: claims,
      attributeSelections: attributeSelections ?? this.attributeSelections,
      isSelected: isSelected ?? this.isSelected,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      requiredAttributes: requiredAttributes,
      optionalAttributes: optionalAttributes,
    );
  }

  /// Calculate privacy score (0.0 = full disclosure, 1.0 = minimal disclosure)
  double get privacyScore {
    final totalAttributes = claims.length;
    final disclosedAttributes = attributeSelections.values
        .where((v) => v)
        .length;
    return totalAttributes > 0
        ? 1.0 - (disclosedAttributes / totalAttributes)
        : 1.0;
  }

  /// Get list of attribute names that will be disclosed
  List<String> get disclosedAttributes {
    return attributeSelections.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get list of attribute names that will NOT be disclosed
  List<String> get hiddenAttributes {
    return attributeSelections.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Whether all required attributes are selected
  bool get hasAllRequiredAttributes {
    return requiredAttributes.every(
      (attr) => attributeSelections[attr] == true,
    );
  }
}

/// Privacy levels for credential disclosure.
enum PrivacyLevel {
  /// Disclose only the minimum required attributes
  minimal(Icons.shield, 'Minimal disclosure'),

  /// Disclose required plus some optional attributes
  moderate(Icons.verified_user, 'Moderate disclosure'),

  /// Disclose all available attributes
  full(Icons.warning, 'Full disclosure');

  const PrivacyLevel(this.icon, this.description);

  /// Icon to display for this privacy level
  final IconData icon;

  /// Human-readable description
  final String description;

  /// Color associated with this privacy level
  Color get color {
    switch (this) {
      case PrivacyLevel.minimal:
        return Colors.green;
      case PrivacyLevel.moderate:
        return Colors.orange;
      case PrivacyLevel.full:
        return Colors.red;
    }
  }
}
