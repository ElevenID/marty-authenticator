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

/// Advanced selective disclosure sheet for fine-grained privacy control
///
/// This widget provides detailed control over attribute disclosure with:
/// - Visual privacy impact indicators
/// - Compliance recommendations
/// - Advanced disclosure patterns
/// - Hardware security status
/// - Data minimization guidance
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/selectable_credential.dart';
import '../utils/logger.dart';

/// Selective disclosure configuration for a single attribute
class AttributeDisclosureConfig {
  final String attributeName;
  final dynamic attributeValue;
  final bool isRequired;
  final bool isDisclosed;
  final DisclosureRisk riskLevel;
  final List<String> usageRestrictions;
  final String? dataCategory;

  const AttributeDisclosureConfig({
    required this.attributeName,
    required this.attributeValue,
    required this.isRequired,
    required this.isDisclosed,
    required this.riskLevel,
    required this.usageRestrictions,
    this.dataCategory,
  });

  AttributeDisclosureConfig copyWith({
    bool? isDisclosed,
    DisclosureRisk? riskLevel,
  }) {
    return AttributeDisclosureConfig(
      attributeName: attributeName,
      attributeValue: attributeValue,
      isRequired: isRequired,
      isDisclosed: isDisclosed ?? this.isDisclosed,
      riskLevel: riskLevel ?? this.riskLevel,
      usageRestrictions: usageRestrictions,
      dataCategory: dataCategory,
    );
  }
}

/// Risk levels for attribute disclosure
enum DisclosureRisk {
  low(Icons.check_circle, Colors.green, 'Low risk'),
  medium(Icons.warning, Colors.orange, 'Medium risk'),
  high(Icons.error, Colors.red, 'High risk'),
  critical(Icons.dangerous, Colors.purple, 'Critical risk');

  const DisclosureRisk(this.icon, this.color, this.description);
  final IconData icon;
  final Color color;
  final String description;
}

/// Selective disclosure sheet widget
class SelectiveDisclosureSheet extends ConsumerStatefulWidget {
  final SelectableCredential credential;
  final Map<String, dynamic> presentationRequest;
  final Function(Map<String, bool>) onDisclosureChanged;

  const SelectiveDisclosureSheet({
    super.key,
    required this.credential,
    required this.presentationRequest,
    required this.onDisclosureChanged,
  });

  @override
  ConsumerState<SelectiveDisclosureSheet> createState() =>
      _SelectiveDisclosureSheetState();

  /// Show the selective disclosure sheet
  static Future<Map<String, bool>?> show({
    required BuildContext context,
    required SelectableCredential credential,
    required Map<String, dynamic> presentationRequest,
  }) async {
    Map<String, bool>? result;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectiveDisclosureSheet(
        credential: credential,
        presentationRequest: presentationRequest,
        onDisclosureChanged: (disclosure) {
          result = disclosure;
        },
      ),
    );

    return result;
  }
}

class _SelectiveDisclosureSheetState
    extends ConsumerState<SelectiveDisclosureSheet> {
  List<AttributeDisclosureConfig> _attributeConfigs = [];
  bool _isLoading = false;
  String? _error;
  Map<String, bool> _currentDisclosure = {};
  PrivacyMode _privacyMode = PrivacyMode.balanced;

  @override
  void initState() {
    super.initState();
    _initializeDisclosureConfigs();
  }

  void _initializeDisclosureConfigs() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _attributeConfigs = widget.credential.claims.entries.map((entry) {
        final isRequired = widget.credential.requiredAttributes.contains(
          entry.key,
        );
        final isCurrentlyDisclosed =
            widget.credential.attributeSelections[entry.key] ?? false;

        return AttributeDisclosureConfig(
          attributeName: entry.key,
          attributeValue: entry.value,
          isRequired: isRequired,
          isDisclosed: isCurrentlyDisclosed,
          riskLevel: _assessDisclosureRisk(entry.key, entry.value),
          usageRestrictions: _getUsageRestrictions(entry.key),
          dataCategory: _categorizeData(entry.key, entry.value),
        );
      }).toList();

      _updateCurrentDisclosure();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize disclosure configs: $e';
        _isLoading = false;
      });
      Logger.error('Selective disclosure initialization failed', error: e);
    }
  }

  DisclosureRisk _assessDisclosureRisk(String attributeName, dynamic value) {
    // Assess risk based on attribute sensitivity
    final sensitiveAttributes = {
      'ssn': DisclosureRisk.critical,
      'social_security_number': DisclosureRisk.critical,
      'tax_id': DisclosureRisk.critical,
      'passport_number': DisclosureRisk.critical,
      'driver_license': DisclosureRisk.high,
      'date_of_birth': DisclosureRisk.high,
      'dob': DisclosureRisk.high,
      'birth_date': DisclosureRisk.high,
      'phone': DisclosureRisk.medium,
      'email': DisclosureRisk.medium,
      'address': DisclosureRisk.medium,
      'home_address': DisclosureRisk.high,
      'name': DisclosureRisk.medium,
      'first_name': DisclosureRisk.low,
      'last_name': DisclosureRisk.medium,
      'age': DisclosureRisk.low,
      'country': DisclosureRisk.low,
    };

    final lowerKey = attributeName.toLowerCase();
    return sensitiveAttributes[lowerKey] ?? DisclosureRisk.low;
  }

  List<String> _getUsageRestrictions(String attributeName) {
    // Define usage restrictions based on attribute type
    final restrictionsMap = {
      'ssn': ['Identity verification only', 'No storage beyond session'],
      'date_of_birth': ['Age verification only', 'No precise date retention'],
      'address': ['Location verification only', 'No third-party sharing'],
      'phone': ['Contact verification only', 'No marketing use'],
      'email': ['Communication only', 'No third-party sharing'],
    };

    final lowerKey = attributeName.toLowerCase();
    return restrictionsMap[lowerKey] ?? ['Standard data protection applies'];
  }

  String? _categorizeData(String attributeName, dynamic value) {
    final categories = {
      'ssn': 'Sensitive Personal Data',
      'date_of_birth': 'Biometric/Age Data',
      'address': 'Location Data',
      'phone': 'Contact Information',
      'email': 'Contact Information',
      'name': 'Identity Information',
      'degree': 'Educational Data',
      'university': 'Educational Data',
    };

    final lowerKey = attributeName.toLowerCase();
    return categories[lowerKey];
  }

  void _updateCurrentDisclosure() {
    _currentDisclosure = {
      for (final config in _attributeConfigs)
        config.attributeName: config.isDisclosed,
    };
  }

  void _updateAttributeDisclosure(int index, bool isDisclosed) {
    setState(() {
      _attributeConfigs[index] = _attributeConfigs[index].copyWith(
        isDisclosed: isDisclosed,
      );
      _updateCurrentDisclosure();
    });
  }

  void _applyPrivacyMode(PrivacyMode mode) {
    setState(() {
      _privacyMode = mode;

      for (int i = 0; i < _attributeConfigs.length; i++) {
        final config = _attributeConfigs[i];
        bool shouldDisclose = false;

        switch (mode) {
          case PrivacyMode.minimal:
            shouldDisclose = config.isRequired;
            break;
          case PrivacyMode.balanced:
            shouldDisclose =
                config.isRequired || config.riskLevel == DisclosureRisk.low;
            break;
          case PrivacyMode.permissive:
            shouldDisclose = config.riskLevel != DisclosureRisk.critical;
            break;
          case PrivacyMode.full:
            shouldDisclose = true;
            break;
        }

        _attributeConfigs[i] = config.copyWith(isDisclosed: shouldDisclose);
      }

      _updateCurrentDisclosure();
    });
  }

  void _confirmSelection() {
    widget.onDisclosureChanged(_currentDisclosure);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (_error != null) _buildErrorWidget(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPrivacyModeSelector(),
                    const SizedBox(height: 24),
                    _buildPrivacyOverview(),
                    const SizedBox(height: 24),
                    _buildAttributesList(),
                  ],
                ),
              ),
            ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.tune, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selective Disclosure',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Choose exactly what to share from ${widget.credential.name}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
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

  Widget _buildPrivacyModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Privacy Mode',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: PrivacyMode.values.map((mode) {
              final isSelected = _privacyMode == mode;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  selected: isSelected,
                  label: Text(mode.label),
                  avatar: Icon(
                    mode.icon,
                    size: 16,
                    color: isSelected ? Colors.white : mode.color,
                  ),
                  selectedColor: mode.color,
                  onSelected: (selected) {
                    if (selected) _applyPrivacyMode(mode);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _privacyMode.description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildPrivacyOverview() {
    final totalAttributes = _attributeConfigs.length;
    final disclosedAttributes = _attributeConfigs
        .where((c) => c.isDisclosed)
        .length;
    final privacyScore = totalAttributes > 0
        ? (totalAttributes - disclosedAttributes) / totalAttributes
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getPrivacyScoreColor(privacyScore).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getPrivacyScoreColor(privacyScore).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Privacy Impact',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getPrivacyScoreColor(privacyScore),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${(privacyScore * 100).round()}% Private',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPrivacyMetric(
                  'Total',
                  totalAttributes.toString(),
                  Icons.list,
                ),
              ),
              Expanded(
                child: _buildPrivacyMetric(
                  'Disclosed',
                  disclosedAttributes.toString(),
                  Icons.visibility,
                ),
              ),
              Expanded(
                child: _buildPrivacyMetric(
                  'Protected',
                  (totalAttributes - disclosedAttributes).toString(),
                  Icons.shield,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAttributesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attributes',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...List.generate(_attributeConfigs.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAttributeCard(index),
          );
        }),
      ],
    );
  }

  Widget _buildAttributeCard(int index) {
    final config = _attributeConfigs[index];

    return Card(
      elevation: config.isDisclosed ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: config.isDisclosed
              ? config.riskLevel.color.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
          width: config.isDisclosed ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: config.isDisclosed,
                  onChanged: config.isRequired
                      ? null
                      : (value) =>
                            _updateAttributeDisclosure(index, value ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            config.attributeName,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          if (config.isRequired)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
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
                          const Spacer(),
                          Icon(
                            config.riskLevel.icon,
                            size: 16,
                            color: config.riskLevel.color,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.attributeValue.toString(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (config.dataCategory != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  config.dataCategory!,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  config.riskLevel.icon,
                  size: 14,
                  color: config.riskLevel.color,
                ),
                const SizedBox(width: 4),
                Text(
                  config.riskLevel.description,
                  style: TextStyle(
                    color: config.riskLevel.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (config.usageRestrictions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...config.usageRestrictions.map(
                (restriction) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          restriction,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
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
              onPressed: _confirmSelection,
              child: const Text('Apply Selection'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPrivacyScoreColor(double score) {
    if (score > 0.7) return Colors.green;
    if (score > 0.4) return Colors.orange;
    return Colors.red;
  }
}

/// Privacy modes for automated disclosure configuration
enum PrivacyMode {
  minimal(
    Icons.shield,
    Colors.green,
    'Minimal',
    'Share only required attributes for maximum privacy',
  ),
  balanced(
    Icons.balance,
    Colors.blue,
    'Balanced',
    'Share required attributes and low-risk optional ones',
  ),
  permissive(
    Icons.handshake,
    Colors.orange,
    'Permissive',
    'Share most attributes except highly sensitive ones',
  ),
  full(
    Icons.lock_open,
    Colors.red,
    'Full Disclosure',
    'Share all available attributes (not recommended)',
  );

  const PrivacyMode(this.icon, this.color, this.label, this.description);
  final IconData icon;
  final Color color;
  final String label;
  final String description;
}
