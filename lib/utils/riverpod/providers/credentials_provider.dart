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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../interfaces/spruce_interfaces.dart';
import '../../../model/promotional_credential.dart';
import '../../../views/main_view/main_view_widgets/card_widgets/verifiable_credential_card.dart';
import '../../../views/main_view/main_view_widgets/card_widgets/mdoc_credential_card.dart';
import '../../../views/main_view/main_view_widgets/card_widgets/grouped_credential_stack.dart';
import 'spruce_providers.dart';

/// Provider for managing the list of credentials
final credentialsProvider =
    StateNotifierProvider<CredentialsNotifier, CredentialsState>((ref) {
      return CredentialsNotifier(ref);
    });

/// State class for credentials
class CredentialsState {
  final List<VerifiableCredential> verifiableCredentials;
  final List<MDocCredential> mDocCredentials;
  final List<PromotionalCredential> promotionalCredentials;
  final bool isLoading;
  final String? error;

  CredentialsState({
    this.verifiableCredentials = const [],
    this.mDocCredentials = const [],
    this.promotionalCredentials = const [],
    this.isLoading = false,
    this.error,
  });

  CredentialsState copyWith({
    List<VerifiableCredential>? verifiableCredentials,
    List<MDocCredential>? mDocCredentials,
    List<PromotionalCredential>? promotionalCredentials,
    bool? isLoading,
    String? error,
  }) {
    return CredentialsState(
      verifiableCredentials:
          verifiableCredentials ?? this.verifiableCredentials,
      mDocCredentials: mDocCredentials ?? this.mDocCredentials,
      promotionalCredentials: promotionalCredentials ?? this.promotionalCredentials,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get hasCredentials =>
      verifiableCredentials.isNotEmpty || mDocCredentials.isNotEmpty || promotionalCredentials.isNotEmpty;
  int get totalCredentials =>
      verifiableCredentials.length + mDocCredentials.length + promotionalCredentials.length;

  /// Get active (non-expired) credentials grouped by issuer
  List<CredentialGroup> get groupedCredentials {
    final Map<String, CredentialGroup> groups = {};
    final List<CredentialGroup> result = [];

    // Add promotional credentials group at the top if any are active
    final activePromotionalCredentials = promotionalCredentials
        .where((promo) => promo.isActive)
        .toList();
    
    if (activePromotionalCredentials.isNotEmpty) {
      result.add(CredentialGroup(
        issuerName: activePromotionalCredentials.first.issuerName,
        promotionalCredentials: activePromotionalCredentials,
        isPromotional: true,
      ));
    }

    // Group active verifiable credentials by issuer
    for (final vc in verifiableCredentials) {
      if (!vc.isExpired) {
        final issuerName = vc.issuerName;
        if (!groups.containsKey(issuerName)) {
          groups[issuerName] = CredentialGroup(issuerName: issuerName);
        }
        groups[issuerName] = CredentialGroup(
          issuerName: issuerName,
          verifiableCredentials: [
            ...groups[issuerName]!.verifiableCredentials,
            vc,
          ],
          mDocCredentials: groups[issuerName]!.mDocCredentials,
        );
      }
    }

    // Group active mDoc credentials by issuing authority
    for (final mdoc in mDocCredentials) {
      if (!_isMDocExpired(mdoc)) {
        final issuerName = mdoc.issuingAuthority;
        if (!groups.containsKey(issuerName)) {
          groups[issuerName] = CredentialGroup(issuerName: issuerName);
        }
        groups[issuerName] = CredentialGroup(
          issuerName: issuerName,
          verifiableCredentials: groups[issuerName]!.verifiableCredentials,
          mDocCredentials: [
            ...groups[issuerName]!.mDocCredentials,
            mdoc,
          ],
        );
      }
    }

    // Separate holder cards (mDL/passport) from other credentials
    final holderCards = <CredentialGroup>[];
    final otherCards = <CredentialGroup>[];
    
    for (final group in groups.values) {
      // Check if this group contains holder documents (mDL or passport)
      final hasHolderDocs = group.mDocCredentials.any((mdoc) => 
          mdoc.docType == 'org.iso.18013.5.1.mDL' || 
          mdoc.docType == 'org.iso.18013.5.1.mID' ||
          mdoc.docType == 'org.iso.18013.5.1.mPassport');
      
      if (hasHolderDocs) {
        holderCards.add(group);
      } else {
        otherCards.add(group);
      }
    }
    
    // Sort each category separately
    holderCards.sort((a, b) => a.issuerName.compareTo(b.issuerName));
    otherCards.sort((a, b) => a.issuerName.compareTo(b.issuerName));
    
    // Add holder cards first, then other cards
    result.addAll(holderCards);
    result.addAll(otherCards);

    return result;
  }

  /// Check if an mDoc credential is expired
  bool _isMDocExpired(MDocCredential mdoc) {
    if (mdoc.expiryDate == null) return false;
    return mdoc.expiryDate!.isBefore(DateTime.now());
  }
}

/// Notifier for managing credentials state
class CredentialsNotifier extends StateNotifier<CredentialsState> {
  late final ISpruceIdWalletManager _walletManager;
  final Ref _ref;

  CredentialsNotifier(this._ref) : super(CredentialsState()) {
    _walletManager = _ref.read(spruceIdWalletManagerProvider);
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('CredentialsNotifier: Loading credentials from SpruceID wallet...');
      
      // Load real credentials from SpruceID wallet
      final walletCredentials = await _walletManager.getAllCredentials();
      print('CredentialsNotifier: Received ${walletCredentials.length} credentials from wallet');
      
      List<VerifiableCredential> verifiableCredentials = [];
      List<MDocCredential> mDocCredentials = [];
      
      // Parse and categorize credentials from wallet
      for (final credData in walletCredentials) {
        try {
          if (_isVerifiableCredential(credData)) {
            final vc = _parseVerifiableCredential(credData);
            if (vc != null) {
              print('CredentialsNotifier: Parsed VerifiableCredential: ${vc.id}');
              verifiableCredentials.add(vc);
            }
          } else if (_isMDocCredential(credData)) {
            final mdoc = _parseMDocCredential(credData);
            if (mdoc != null) {
              print('CredentialsNotifier: Parsed MDocCredential: ${mdoc.docType}');
              mDocCredentials.add(mdoc);
            }
          }
        } catch (e) {
          // Log error but continue processing other credentials
          print('Error parsing credential: $e');
        }
      }

      // Always add sample credentials for demo to show stacking feature
      print('CredentialsNotifier: Adding sample stacked credentials for demo');
      verifiableCredentials.addAll(_createSampleVCs());
      mDocCredentials.addAll(_createSampleMDocs());

      print('CredentialsNotifier: Final credential counts - VC: ${verifiableCredentials.length}, mDoc: ${mDocCredentials.length}');

      state = state.copyWith(
        verifiableCredentials: verifiableCredentials,
        mDocCredentials: mDocCredentials,
        promotionalCredentials: DefaultPromotionalCredentials.all,
        isLoading: false,
      );
    } catch (e) {
      // If wallet fails, fall back to sample credentials
      print('Failed to load from SpruceID wallet, using sample data: $e');
      state = state.copyWith(
        verifiableCredentials: _createSampleVCs(),
        mDocCredentials: _createSampleMDocs(),
        promotionalCredentials: DefaultPromotionalCredentials.all,
        isLoading: false,
        error: 'Using demo credentials with stacked examples - SpruceID wallet: $e',
      );
    }
  }

  /// Check if credential data represents a W3C Verifiable Credential
  bool _isVerifiableCredential(Map<String, dynamic> credData) {
    return credData.containsKey('type') && 
           credData.containsKey('credentialSubject') &&
           credData.containsKey('@context') ||
           credData.containsKey('context') ||
           (credData['type'] is List && (credData['type'] as List).contains('VerifiableCredential'));
  }

  /// Check if credential data represents an mDoc credential
  bool _isMDocCredential(Map<String, dynamic> credData) {
    return credData.containsKey('docType') ||
           credData.containsKey('issuerSigned') ||
           credData.containsKey('deviceSigned') ||
           credData['docType']?.toString().contains('.mDL') == true ||
           credData['docType']?.toString().contains('18013') == true;
  }

  /// Parse SpruceID wallet data into VerifiableCredential
  VerifiableCredential? _parseVerifiableCredential(Map<String, dynamic> credData) {
    try {
      return VerifiableCredential(
        id: credData['id']?.toString() ?? 'urn:uuid:${DateTime.now().millisecondsSinceEpoch}',
        type: _parseCredentialTypes(credData['type']),
        issuer: _parseIssuer(credData['issuer']),
        credentialSubject: Map<String, dynamic>.from(credData['credentialSubject'] ?? {}),
        issuanceDate: credData['issuanceDate']?.toString() ?? DateTime.now().toIso8601String(),
        expirationDate: credData['expirationDate']?.toString(),
        proof: credData['proof'] != null ? Map<String, dynamic>.from(credData['proof']) : null,
      );
    } catch (e) {
      print('Error parsing verifiable credential: $e');
      return null;
    }
  }

  /// Parse SpruceID wallet data into MDocCredential  
  MDocCredential? _parseMDocCredential(Map<String, dynamic> credData) {
    try {
      return MDocCredential(
        docType: credData['docType']?.toString() ?? 'org.iso.18013.5.1.mDL',
        issuerSigned: Map<String, dynamic>.from(credData['issuerSigned'] ?? {}),
        deviceSigned: Map<String, dynamic>.from(credData['deviceSigned'] ?? {}),
        portrait: credData['portrait']?.toString(),
        issueDate: _parseDateTime(credData['issueDate']),
        expiryDate: _parseDateTime(credData['expiryDate']),
      );
    } catch (e) {
      print('Error parsing mDoc credential: $e'); 
      return null;
    }
  }

  /// Parse credential types from various formats
  List<String> _parseCredentialTypes(dynamic typeData) {
    if (typeData is String) return [typeData];
    if (typeData is List) return typeData.cast<String>();
    return ['VerifiableCredential'];
  }

  /// Parse issuer data from various formats
  Map<String, dynamic> _parseIssuer(dynamic issuerData) {
    if (issuerData is String) return {'id': issuerData};
    if (issuerData is Map) return Map<String, dynamic>.from(issuerData);
    return {'id': 'unknown:issuer'};
  }

  /// Parse datetime from various formats
  DateTime? _parseDateTime(dynamic dateData) {
    if (dateData == null) return null;
    if (dateData is DateTime) return dateData;
    if (dateData is String) {
      try {
        return DateTime.parse(dateData);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Create multiple sample VerifiableCredentials for demo (including stacked examples)
  List<VerifiableCredential> _createSampleVCs() {
    return [
      // University credentials (2 from same issuer - will be stacked)
      VerifiableCredential(
        id: 'urn:uuid:sample-degree-1',
        type: ['VerifiableCredential', 'UniversityDegreeCredential'],
        issuer: {'id': 'did:web:stanford.edu', 'name': 'Stanford University'},
        credentialSubject: {
          'id': 'did:key:holder123',
          'name': 'John Smith',
          'degree': 'Bachelor of Computer Science',
          'graduationDate': '2023-05-15',
        },
        issuanceDate: '2023-05-15T10:30:00Z',
        expirationDate: '2028-05-15T10:30:00Z',
        proof: {
          'type': 'Ed25519Signature2018',
          'verificationMethod': 'did:web:stanford.edu#key-1',
        },
      ),
      VerifiableCredential(
        id: 'urn:uuid:sample-certificate-1',
        type: ['VerifiableCredential', 'ProfessionalCertificate'],
        issuer: {'id': 'did:web:stanford.edu', 'name': 'Stanford University'},
        credentialSubject: {
          'id': 'did:key:holder123',
          'name': 'John Smith',
          'certification': 'Advanced Machine Learning',
          'completionDate': '2024-01-20',
        },
        issuanceDate: '2024-01-20T14:00:00Z',
        expirationDate: '2027-01-20T14:00:00Z',
        proof: {
          'type': 'Ed25519Signature2018',
          'verificationMethod': 'did:web:stanford.edu#key-2',
        },
      ),
      
      // Corporate credentials (3 from same issuer - will be stacked)
      VerifiableCredential(
        id: 'urn:uuid:employee-id-1',
        type: ['VerifiableCredential', 'EmployeeCredential'],
        issuer: {'id': 'did:web:techcorp.com', 'name': 'TechCorp Inc'},
        credentialSubject: {
          'id': 'did:key:holder123',
          'name': 'John Smith',
          'employeeId': 'EMP001',
          'department': 'Engineering',
          'position': 'Senior Developer',
        },
        issuanceDate: '2023-08-01T09:00:00Z',
        expirationDate: '2025-08-01T09:00:00Z',
        proof: {
          'type': 'Ed25519Signature2018',
          'verificationMethod': 'did:web:techcorp.com#hr-key',
        },
      ),
      VerifiableCredential(
        id: 'urn:uuid:access-badge-1',
        type: ['VerifiableCredential', 'AccessCredential'],
        issuer: {'id': 'did:web:techcorp.com', 'name': 'TechCorp Inc'},
        credentialSubject: {
          'id': 'did:key:holder123',
          'name': 'John Smith',
          'accessLevel': 'Level 3',
          'areas': ['Building A', 'Lab 1', 'Conference Rooms'],
        },
        issuanceDate: '2023-08-01T09:30:00Z',
        expirationDate: '2025-08-01T23:59:59Z',
        proof: {
          'type': 'Ed25519Signature2018',
          'verificationMethod': 'did:web:techcorp.com#security-key',
        },
      ),
      VerifiableCredential(
        id: 'urn:uuid:training-cert-1',
        type: ['VerifiableCredential', 'TrainingCertificate'],
        issuer: {'id': 'did:web:techcorp.com', 'name': 'TechCorp Inc'},
        credentialSubject: {
          'id': 'did:key:holder123',
          'name': 'John Smith',
          'training': 'Security Awareness',
          'completionDate': '2024-03-15',
          'score': '98%',
        },
        issuanceDate: '2024-03-15T16:45:00Z',
        expirationDate: '2025-03-15T16:45:00Z',
        proof: {
          'type': 'Ed25519Signature2018',
          'verificationMethod': 'did:web:techcorp.com#training-key',
        },
      ),
      
      // Single credential from different issuer
      VerifiableCredential(
        id: 'urn:uuid:health-card-1',
        type: ['VerifiableCredential', 'HealthCredential'],
        issuer: {'id': 'did:web:health.gov', 'name': 'Department of Health'},
        credentialSubject: {
          'id': 'did:key:holder123',
          'name': 'John Smith',
          'vaccination': 'COVID-19',
          'doses': 3,
          'lastDose': '2023-09-20',
        },
        issuanceDate: '2023-09-20T11:00:00Z',
        expirationDate: '2025-09-20T11:00:00Z',
        proof: {
          'type': 'Ed25519Signature2018',
          'verificationMethod': 'did:web:health.gov#vax-key',
        },
      ),
    ];
  }

  /// Create multiple sample MDocCredentials for demo (including stacked examples)
  List<MDocCredential> _createSampleMDocs() {
    return [
      // State DMV documents (2 from same issuer - will be stacked)
      MDocCredential(
        docType: 'org.iso.18013.5.1.mDL',
        issuerSigned: {
          'nameSpaces': {
            'org.iso.18013.5.1': [
              {'elementIdentifier': 'given_name', 'elementValue': 'John'},
              {'elementIdentifier': 'family_name', 'elementValue': 'Smith'},
              {'elementIdentifier': 'birth_date', 'elementValue': '1990-01-15'},
              {
                'elementIdentifier': 'document_number',
                'elementValue': 'DL123456789',
              },
              {
                'elementIdentifier': 'issuing_authority',
                'elementValue': 'State DMV',
              },
              {
                'elementIdentifier': 'issue_date',
                'elementValue': '2023-06-01',
              },
              {
                'elementIdentifier': 'expiry_date',
                'elementValue': '2028-06-01',
              },
            ],
          },
        },
        deviceSigned: {},
        issueDate: DateTime(2023, 6, 1),
        expiryDate: DateTime(2028, 6, 1),
      ),
      MDocCredential(
        docType: 'org.iso.18013.5.1.mID',
        issuerSigned: {
          'nameSpaces': {
            'org.iso.18013.5.1': [
              {'elementIdentifier': 'given_name', 'elementValue': 'John'},
              {'elementIdentifier': 'family_name', 'elementValue': 'Smith'},
              {'elementIdentifier': 'birth_date', 'elementValue': '1990-01-15'},
              {
                'elementIdentifier': 'document_number',
                'elementValue': 'ID987654321',
              },
              {
                'elementIdentifier': 'issuing_authority',
                'elementValue': 'State DMV',
              },
              {
                'elementIdentifier': 'issue_date',
                'elementValue': '2024-01-15',
              },
              {
                'elementIdentifier': 'expiry_date',
                'elementValue': '2029-01-15',
              },
            ],
          },
        },
        deviceSigned: {},
        issueDate: DateTime(2024, 1, 15),
        expiryDate: DateTime(2029, 1, 15),
      ),
      
      // Federal documents (single from different issuer)
      MDocCredential(
        docType: 'org.iso.18013.5.1.mPassport',
        issuerSigned: {
          'nameSpaces': {
            'org.iso.18013.5.1': [
              {'elementIdentifier': 'given_name', 'elementValue': 'John'},
              {'elementIdentifier': 'family_name', 'elementValue': 'Smith'},
              {'elementIdentifier': 'birth_date', 'elementValue': '1990-01-15'},
              {
                'elementIdentifier': 'document_number',
                'elementValue': 'P123456789',
              },
              {
                'elementIdentifier': 'issuing_authority',
                'elementValue': 'US State Department',
              },
              {
                'elementIdentifier': 'issue_date',
                'elementValue': '2023-03-10',
              },
              {
                'elementIdentifier': 'expiry_date',
                'elementValue': '2033-03-10',
              },
              {
                'elementIdentifier': 'nationality',
                'elementValue': 'US',
              },
            ],
          },
        },
        deviceSigned: {},
        issueDate: DateTime(2023, 3, 10),
        expiryDate: DateTime(2033, 3, 10),
      ),
    ];
  }

  Future<void> refreshCredentials() async {
    await _loadCredentials();
  }

  Future<void> addVerifiableCredential(VerifiableCredential credential) async {
    final currentVCs = List<VerifiableCredential>.from(
      state.verifiableCredentials,
    );
    currentVCs.add(credential);
    state = state.copyWith(verifiableCredentials: currentVCs);
  }

  Future<void> addMDocCredential(MDocCredential credential) async {
    final currentMDocs = List<MDocCredential>.from(state.mDocCredentials);
    currentMDocs.add(credential);
    state = state.copyWith(mDocCredentials: currentMDocs);
  }

  Future<void> removeVerifiableCredential(String credentialId) async {
    final currentVCs = List<VerifiableCredential>.from(
      state.verifiableCredentials,
    );
    currentVCs.removeWhere((vc) => vc.id == credentialId);
    state = state.copyWith(verifiableCredentials: currentVCs);
  }

  /// Dismiss a promotional credential by marking it as dismissed
  void dismissPromotionalCard(String cardId) {
    final currentPromotionalCredentials = List<PromotionalCredential>.from(
      state.promotionalCredentials,
    );
    
    // Find and update the promotional credential to mark it as dismissed
    for (int i = 0; i < currentPromotionalCredentials.length; i++) {
      if (currentPromotionalCredentials[i].id == cardId) {
        currentPromotionalCredentials[i] = currentPromotionalCredentials[i].copyWith(
          isDismissed: true,
        );
        break;
      }
    }
    
    state = state.copyWith(promotionalCredentials: currentPromotionalCredentials);
  }
}