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
import 'card_widgets/grouped_credential_stack.dart';
import 'placeholders/credential_placeholders.dart';
import 'add_credential/add_credential_handler.dart';
import '../../credential_detail_view.dart';
import '../../../utils/riverpod/providers/credentials_provider.dart';

/// Widget that displays the list of credentials as cards
class CredentialsList extends ConsumerStatefulWidget {
  const CredentialsList({super.key});

  @override
  ConsumerState<CredentialsList> createState() => _CredentialsListState();
}

class _CredentialsListState extends ConsumerState<CredentialsList> {

  @override
  Widget build(BuildContext context) {
    final credentialsState = ref.watch(credentialsProvider);

    if (credentialsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (credentialsState.error != null) {
      return _buildErrorState(credentialsState.error!);
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
          // Promotional Cards (first in the list)
          if (credentialsState.groupedCredentials.isNotEmpty) ...[
            ...credentialsState.groupedCredentials
                .where((group) => group.isPromotional)
                .map((group) => SliverToBoxAdapter(
                      child: GroupedCredentialStack(
                        group: group,
                        onCredentialTap: _showCredentialDetail,
                        onShare: _shareCredential,
                        onVerify: _verifyCredential,
                        onPresent: _presentMDoc,
                        onAgeVerify: _performAgeVerification,
                      ),
                    )),
          ],

          // MDL Placeholder (right after promotional cards)
          SliverToBoxAdapter(
            child: MdlPlaceholder(
              onTap: () => AddCredentialHandler.showAddMdlBottomSheet(context),
            ),
          ),

          // Passport Placeholder (right after MDL placeholder)
          SliverToBoxAdapter(
            child: PassportPlaceholder(
              onTap: () =>
                  AddCredentialHandler.showAddPassportBottomSheet(context),
            ),
          ),

          // Other Credentials (holder cards and regular credentials)
          if (credentialsState.groupedCredentials.isNotEmpty) ...[
            ...credentialsState.groupedCredentials
                .where((group) => !group.isPromotional)
                .map((group) => SliverToBoxAdapter(
                      child: GroupedCredentialStack(
                        group: group,
                        onCredentialTap: _showCredentialDetail,
                        onShare: _shareCredential,
                        onVerify: _verifyCredential,
                        onPresent: _presentMDoc,
                        onAgeVerify: _performAgeVerification,
                      ),
                    )),
          ],

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
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
            error,
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

  void _performAgeVerification(MDocCredential credential, int age) {
    // TODO: Implement age verification using SpruceID
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting age verification for $age years...')),
    );
  }

  void _addCredential() {
    // TODO: Navigate to add credential flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add credential flow coming soon...')),
    );
  }
}