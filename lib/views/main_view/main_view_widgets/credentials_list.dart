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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card_widgets/verifiable_credential_card.dart';
import 'card_widgets/mdoc_credential_card.dart';
import '../../credential_detail_view.dart';

/// Provider for managing the list of credentials
final credentialsProvider =
    StateNotifierProvider<CredentialsNotifier, CredentialsState>((ref) {
      return CredentialsNotifier();
    });

/// State class for credentials
class CredentialsState {
  final List<VerifiableCredential> verifiableCredentials;
  final List<MDocCredential> mDocCredentials;
  final bool isLoading;
  final String? error;

  CredentialsState({
    this.verifiableCredentials = const [],
    this.mDocCredentials = const [],
    this.isLoading = false,
    this.error,
  });

  CredentialsState copyWith({
    List<VerifiableCredential>? verifiableCredentials,
    List<MDocCredential>? mDocCredentials,
    bool? isLoading,
    String? error,
  }) {
    return CredentialsState(
      verifiableCredentials:
          verifiableCredentials ?? this.verifiableCredentials,
      mDocCredentials: mDocCredentials ?? this.mDocCredentials,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get hasCredentials =>
      verifiableCredentials.isNotEmpty || mDocCredentials.isNotEmpty;
  int get totalCredentials =>
      verifiableCredentials.length + mDocCredentials.length;
}

/// Notifier for managing credentials state
class CredentialsNotifier extends StateNotifier<CredentialsState> {
  CredentialsNotifier() : super(CredentialsState()) {
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // TODO: Load real credentials from SpruceID wallet
      // For now, add some sample credentials for demonstration
      await Future.delayed(const Duration(milliseconds: 500));

      final sampleVC = VerifiableCredential(
        id: 'urn:uuid:sample-degree-1',
        type: ['VerifiableCredential', 'UniversityDegreeCredential'],
        issuer: {'id': 'did:web:university.edu', 'name': 'Example University'},
        credentialSubject: {
          'id': 'did:key:holder123',
          'name': 'John Smith',
          'degree': 'Bachelor of Computer Science',
        },
        issuanceDate: '2023-05-15T10:30:00Z',
        expirationDate: '2028-05-15T10:30:00Z',
        proof: {
          'type': 'Ed25519Signature2018',
          'verificationMethod': 'did:web:university.edu#key-1',
        },
      );

      final sampleMDoc = MDocCredential(
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
            ],
          },
        },
        deviceSigned: {},
        issueDate: DateTime(2023, 6, 1),
        expiryDate: DateTime(2028, 6, 1),
      );

      state = state.copyWith(
        verifiableCredentials: [sampleVC],
        mDocCredentials: [sampleMDoc],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load credentials: $e',
      );
    }
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
}

/// Widget that displays the list of credentials as cards
class CredentialsList extends ConsumerStatefulWidget {
  const CredentialsList({super.key});

  @override
  ConsumerState<CredentialsList> createState() => _CredentialsListState();
}

class _CredentialsListState extends ConsumerState<CredentialsList> {
  String? _expandedCredentialId;

  @override
  Widget build(BuildContext context) {
    final credentialsState = ref.watch(credentialsProvider);

    if (credentialsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (credentialsState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading credentials',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              credentialsState.error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(credentialsProvider.notifier).refreshCredentials(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!credentialsState.hasCredentials) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(credentialsProvider.notifier).refreshCredentials(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Credentials',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${credentialsState.totalCredentials} items',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          // Verifiable Credentials
          if (credentialsState.verifiableCredentials.isNotEmpty) ...[
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final credential =
                    credentialsState.verifiableCredentials[index];
                return VerifiableCredentialCard(
                  credential: credential,
                  isExpanded: _expandedCredentialId == credential.id,
                  onTap: () => _showCredentialDetail(credential),
                  onShare: () => _shareCredential(credential),
                  onVerify: () => _verifyCredential(credential),
                );
              }, childCount: credentialsState.verifiableCredentials.length),
            ),
          ],

          // mDoc Credentials
          if (credentialsState.mDocCredentials.isNotEmpty) ...[
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final credential = credentialsState.mDocCredentials[index];
                final credentialId = 'mdoc_$index'; // Create unique ID
                return MDocCredentialCard(
                  credential: credential,
                  isExpanded: _expandedCredentialId == credentialId,
                  onTap: () => _showCredentialDetail(credential),
                  onPresent: () => _presentMDoc(credential),
                  onAgeVerify: (age) => _performAgeVerification(credential),
                );
              }, childCount: credentialsState.mDocCredentials.length),
            ),
          ],

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      slivers: [
        // Empty state message
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.credit_card_outlined,
                    size: 96,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Other Credentials',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add digital credentials to get started.\nYour verifiable credentials, digital IDs, and certificates will appear here.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _addCredential(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Credential'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleExpanded(String credentialId) {
    setState(() {
      _expandedCredentialId = _expandedCredentialId == credentialId
          ? null
          : credentialId;
    });
  }

  void _showCredentialDetail(dynamic credential) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CredentialDetailView(credential: credential),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        barrierDismissible: true,
        opaque: false,
      ),
    );
  }

  void _shareCredential(VerifiableCredential credential) {
    // TODO: Implement credential sharing using SpruceID
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing ${credential.credentialType}...')),
    );
  }

  void _verifyCredential(VerifiableCredential credential) {
    // TODO: Implement credential verification using SpruceID
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Verifying ${credential.credentialType}...')),
    );
  }

  void _presentMDoc(MDocCredential credential) {
    // TODO: Implement mDoc presentation using SpruceID
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Presenting ${credential.documentType}...')),
    );
  }

  void _performAgeVerification(MDocCredential credential) {
    // TODO: Implement age verification using SpruceID
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting age verification...')),
    );
  }

  void _addCredential() {
    // TODO: Navigate to add credential flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add credential flow coming soon...')),
    );
  }
}
