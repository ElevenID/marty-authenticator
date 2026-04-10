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

/// Advanced credential selection widget with selective disclosure capabilities
///
/// This widget leverages the SDK-enhanced services to provide:
/// - Interactive credential selection with privacy controls
/// - Granular attribute disclosure options
/// - Real-time privacy impact assessment
/// - Hardware-backed security indicators
/// - Compliance with data minimization principles
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/spruce_sdk_services.dart';
import '../utils/logger.dart';
import '../models/selectable_credential.dart';

/// Advanced credential selection widget
class SpruceCredentialSelectionWidget extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> availableCredentials;
  final List<String> requestedAttributes;
  final String? presentationRequest;
  final Function(List<SelectableCredential>, Map<String, List<String>>)
  onSelectionChanged;
  final Function(List<SelectableCredential>, Map<String, List<String>>)
  onPresentationCreate;

  const SpruceCredentialSelectionWidget({
    super.key,
    required this.availableCredentials,
    required this.requestedAttributes,
    this.presentationRequest,
    required this.onSelectionChanged,
    required this.onPresentationCreate,
  });

  @override
  ConsumerState<SpruceCredentialSelectionWidget> createState() =>
      _SpruceCredentialSelectionWidgetState();
}

class _SpruceCredentialSelectionWidgetState
    extends ConsumerState<SpruceCredentialSelectionWidget> {
  List<SelectableCredential> _credentials = [];
  bool _isLoading = false;
  String? _error;
  PrivacyAssessment? _privacyAssessment;

  @override
  void initState() {
    super.initState();
    _initializeCredentials();
  }

  @override
  void didUpdateWidget(SpruceCredentialSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableCredentials != widget.availableCredentials ||
        oldWidget.requestedAttributes != widget.requestedAttributes) {
      _initializeCredentials();
    }
  }

  void _initializeCredentials() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _credentials = widget.availableCredentials.map((credential) {
        final claims = Map<String, dynamic>.from(
          credential['credentialSubject'] ?? {},
        );
        final attributeSelections = <String, bool>{};

        // Initialize attribute selections based on request
        for (final attribute in claims.keys) {
          final isRequired = widget.requestedAttributes.contains(attribute);
          attributeSelections[attribute] = isRequired;
        }

        // Determine required vs optional attributes
        final requiredAttributes = claims.keys
            .where((attr) => widget.requestedAttributes.contains(attr))
            .toList();
        final optionalAttributes = claims.keys
            .where((attr) => !widget.requestedAttributes.contains(attr))
            .toList();

        return SelectableCredential(
          id: credential['id'] ?? '',
          name:
              credential['name'] ??
              credential['type']?.toString() ??
              'Unknown Credential',
          type: credential['type']?.toString() ?? '',
          issuer: credential['issuer'] ?? 'Unknown Issuer',
          claims: claims,
          attributeSelections: attributeSelections,
          isSelected: requiredAttributes.isNotEmpty,
          privacyLevel: _calculatePrivacyLevel(attributeSelections),
          requiredAttributes: requiredAttributes,
          optionalAttributes: optionalAttributes,
        );
      }).toList();

      _updatePrivacyAssessment();
      _notifySelectionChanged();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize credentials: $e';
        _isLoading = false;
      });
      Logger.error('Credential initialization failed', error: e);
    }
  }

  PrivacyLevel _calculatePrivacyLevel(Map<String, bool> attributeSelections) {
    final disclosedCount = attributeSelections.values.where((v) => v).length;
    final totalCount = attributeSelections.length;

    if (totalCount == 0) return PrivacyLevel.minimal;

    final ratio = disclosedCount / totalCount;
    if (ratio <= 0.3) return PrivacyLevel.minimal;
    if (ratio <= 0.7) return PrivacyLevel.moderate;
    return PrivacyLevel.full;
  }

  void _updatePrivacyAssessment() {
    final selectedCredentials = _credentials
        .where((c) => c.isSelected)
        .toList();
    final totalAttributes = selectedCredentials.fold<int>(
      0,
      (sum, cred) => sum + cred.claims.length,
    );
    final disclosedAttributes = selectedCredentials.fold<int>(
      0,
      (sum, cred) => sum + cred.disclosedAttributes.length,
    );

    _privacyAssessment = PrivacyAssessment(
      totalCredentials: selectedCredentials.length,
      totalAttributes: totalAttributes,
      disclosedAttributes: disclosedAttributes,
      privacyScore: totalAttributes > 0
          ? 1.0 - (disclosedAttributes / totalAttributes)
          : 1.0,
      recommendations: _generatePrivacyRecommendations(selectedCredentials),
    );
  }

  List<String> _generatePrivacyRecommendations(
    List<SelectableCredential> credentials,
  ) {
    final recommendations = <String>[];

    for (final credential in credentials) {
      if (credential.privacyLevel == PrivacyLevel.full) {
        recommendations.add(
          'Consider reducing disclosure for ${credential.name}',
        );
      }

      final unnecessaryDisclosures = credential.disclosedAttributes
          .where((attr) => !credential.requiredAttributes.contains(attr))
          .toList();

      if (unnecessaryDisclosures.isNotEmpty) {
        recommendations.add(
          'Optional attributes disclosed in ${credential.name}: ${unnecessaryDisclosures.join(', ')}',
        );
      }
    }

    return recommendations;
  }

  void _notifySelectionChanged() {
    final selectedCredentials = _credentials
        .where((c) => c.isSelected)
        .toList();
    final selectiveDisclosure = <String, List<String>>{};

    for (final credential in selectedCredentials) {
      selectiveDisclosure[credential.id] = credential.disclosedAttributes;
    }

    widget.onSelectionChanged(selectedCredentials, selectiveDisclosure);
  }

  void _updateCredentialSelection(int index, bool isSelected) {
    setState(() {
      _credentials[index] = _credentials[index].copyWith(
        isSelected: isSelected,
      );
      _updatePrivacyAssessment();
      _notifySelectionChanged();
    });
  }

  void _updateAttributeSelection(
    int credentialIndex,
    String attribute,
    bool isSelected,
  ) {
    setState(() {
      final credential = _credentials[credentialIndex];
      final newSelections = Map<String, bool>.from(
        credential.attributeSelections,
      );
      newSelections[attribute] = isSelected;

      _credentials[credentialIndex] = credential.copyWith(
        attributeSelections: newSelections,
        privacyLevel: _calculatePrivacyLevel(newSelections),
      );

      _updatePrivacyAssessment();
      _notifySelectionChanged();
    });
  }

  Future<void> _createPresentation() async {
    if (_credentials.where((c) => c.isSelected).isEmpty) {
      _showError('Please select at least one credential');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedCredentials = _credentials
          .where((c) => c.isSelected)
          .toList();
      final selectiveDisclosure = <String, List<String>>{};

      for (final credential in selectedCredentials) {
        selectiveDisclosure[credential.id] = credential.disclosedAttributes;
      }

      await widget.onPresentationCreate(
        selectedCredentials,
        selectiveDisclosure,
      );
    } catch (e) {
      _showError('Failed to create presentation: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        if (_privacyAssessment != null) _buildPrivacyAssessment(),
        const SizedBox(height: 16),
        if (_error != null) _buildErrorWidget(),
        if (_isLoading) _buildLoadingWidget(),
        if (!_isLoading && _error == null) _buildCredentialsList(),
        const SizedBox(height: 24),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credential Selection',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose credentials and attributes to share',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyAssessment() {
    if (_privacyAssessment == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getPrivacyColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getPrivacyColor().withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getPrivacyIcon(), color: _getPrivacyColor()),
              const SizedBox(width: 8),
              Text(
                'Privacy Assessment',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildPrivacyScore(),
            ],
          ),
          const SizedBox(height: 12),
          _buildPrivacyDetails(),
          if (_privacyAssessment!.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPrivacyRecommendations(),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyScore() {
    final score = _privacyAssessment!.privacyScore;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getPrivacyColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${(score * 100).round()}% Private',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPrivacyDetails() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildPrivacyMetric(
          'Credentials',
          _privacyAssessment!.totalCredentials.toString(),
        ),
        _buildPrivacyMetric(
          'Total Attributes',
          _privacyAssessment!.totalAttributes.toString(),
        ),
        _buildPrivacyMetric(
          'Disclosed',
          _privacyAssessment!.disclosedAttributes.toString(),
        ),
      ],
    );
  }

  Widget _buildPrivacyMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: _getPrivacyColor(),
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildPrivacyRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Privacy Recommendations:',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...(_privacyAssessment!.recommendations.map(
          (rec) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rec,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Color _getPrivacyColor() {
    final score = _privacyAssessment?.privacyScore ?? 1.0;
    if (score > 0.7) return Colors.green;
    if (score > 0.4) return Colors.orange;
    return Colors.red;
  }

  IconData _getPrivacyIcon() {
    final score = _privacyAssessment?.privacyScore ?? 1.0;
    if (score > 0.7) return Icons.shield;
    if (score > 0.4) return Icons.verified_user;
    return Icons.warning;
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildCredentialsList() {
    if (_credentials.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: const Center(child: Text('No credentials available')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _credentials.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildCredentialCard(index);
      },
    );
  }

  Widget _buildCredentialCard(int index) {
    final credential = _credentials[index];

    return Card(
      elevation: credential.isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: credential.isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.withOpacity(0.3),
          width: credential.isSelected ? 2 : 1,
        ),
      ),
      child: ExpansionTile(
        leading: Checkbox(
          value: credential.isSelected,
          onChanged: (value) =>
              _updateCredentialSelection(index, value ?? false),
        ),
        title: Text(
          credential.name,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${credential.type}'),
            Text('Issuer: ${credential.issuer}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  credential.privacyLevel.icon,
                  size: 16,
                  color: credential.privacyLevel.color,
                ),
                const SizedBox(width: 4),
                Text(
                  credential.privacyLevel.description,
                  style: TextStyle(
                    color: credential.privacyLevel.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [if (credential.isSelected) _buildAttributeSelection(index)],
      ),
    );
  }

  Widget _buildAttributeSelection(int credentialIndex) {
    final credential = _credentials[credentialIndex];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select attributes to share:',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...credential.claims.entries.map((entry) {
            final isRequired = credential.requiredAttributes.contains(
              entry.key,
            );
            final isSelected =
                credential.attributeSelections[entry.key] ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: isRequired
                        ? null
                        : (value) => _updateAttributeSelection(
                            credentialIndex,
                            entry.key,
                            value ?? false,
                          ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.key,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (isRequired) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: const Text(
                                  'Required',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          entry.value.toString(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasSelection = _credentials.any((c) => c.isSelected);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: hasSelection && !_isLoading ? _createPresentation : null,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Presentation'),
          ),
        ),
      ],
    );
  }
}

/// Privacy assessment data class
class PrivacyAssessment {
  final int totalCredentials;
  final int totalAttributes;
  final int disclosedAttributes;
  final double privacyScore;
  final List<String> recommendations;

  const PrivacyAssessment({
    required this.totalCredentials,
    required this.totalAttributes,
    required this.disclosedAttributes,
    required this.privacyScore,
    required this.recommendations,
  });
}
