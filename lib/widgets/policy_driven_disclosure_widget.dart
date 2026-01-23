import 'package:flutter/material.dart';
import 'package:privacyidea_authenticator/services/policy_service.dart';

/// Widget to display policy-driven disclosure requirements.
///
/// Shows:
/// - Required claims (must disclose for verification to succeed)
/// - Optional claims (can disclose for additional context)
/// - Issuer trust status based on policy constraints
/// - Clear warning when declining required claims
class PolicyDrivenDisclosureWidget extends StatefulWidget {
  final PresentationPolicy policy;
  final dynamic credential;
  final Map<String, bool> initialSelection;
  final Function(Map<String, bool> selection, bool willFail) onSelectionChanged;

  const PolicyDrivenDisclosureWidget({
    Key? key,
    required this.policy,
    required this.credential,
    required this.initialSelection,
    required this.onSelectionChanged,
  }) : super(key: key);

  @override
  State<PolicyDrivenDisclosureWidget> createState() =>
      _PolicyDrivenDisclosureWidgetState();
}

class _PolicyDrivenDisclosureWidgetState
    extends State<PolicyDrivenDisclosureWidget> {
  late Map<String, bool> _selection;
  List<String> _requiredClaims = [];
  List<String> _optionalClaims = [];
  bool _showWarning = false;

  @override
  void initState() {
    super.initState();
    _selection = Map.from(widget.initialSelection);
    _categorizeClaimsState();
  }

  void _categorizeClaimsState() {
    // Get required claims from policy
    final required = widget.policy.requiredClaims
        .map((rc) => rc.claimName)
        .toSet();

    // Check for derived attribute preferences
    final derivedPrefs = widget.policy.derivedAttributePreferences;

    // Categorize available claims
    for (final claimName in _selection.keys) {
      // Check if this claim or its derived form is required
      final isDerived = derivedPrefs.values.contains(claimName);
      final rawClaim = isDerived
          ? derivedPrefs.entries
                .firstWhere(
                  (e) => e.value == claimName,
                  orElse: () => const MapEntry('', ''),
                )
                .key
          : '';

      if (required.contains(claimName) ||
          (isDerived && required.contains(rawClaim))) {
        _requiredClaims.add(claimName);
      } else {
        _optionalClaims.add(claimName);
      }
    }

    _checkForWarning();
  }

  void _checkForWarning() {
    // Show warning if any required claim is not selected
    final hasDeclinedRequired = _requiredClaims.any(
      (claim) => _selection[claim] == false,
    );

    setState(() {
      _showWarning = hasDeclinedRequired;
    });

    widget.onSelectionChanged(_selection, hasDeclinedRequired);
  }

  void _toggleClaim(String claimName, bool value) {
    setState(() {
      _selection[claimName] = value;
      _checkForWarning();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Policy info header
        _buildPolicyHeader(),

        const SizedBox(height: 16),

        // Warning banner if required claims declined
        if (_showWarning) _buildWarningBanner(),

        // Required claims section
        if (_requiredClaims.isNotEmpty) ...[
          _buildSectionHeader(
            'Required Claims',
            Icons.check_circle,
            Colors.red,
          ),
          const SizedBox(height: 8),
          ..._requiredClaims.map(
            (claim) => _buildClaimTile(
              claim,
              isRequired: true,
              isSelected: _selection[claim] ?? false,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Optional claims section
        if (_optionalClaims.isNotEmpty) ...[
          _buildSectionHeader(
            'Optional Claims',
            Icons.info_outline,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          ..._optionalClaims.map(
            (claim) => _buildClaimTile(
              claim,
              isRequired: false,
              isSelected: _selection[claim] ?? false,
            ),
          ),
        ],

        // Data minimization hint
        const SizedBox(height: 16),
        _buildDataMinimizationHint(),
      ],
    );
  }

  Widget _buildPolicyHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.policy.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.policy.purpose,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            if (widget.policy.preferPredicates) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.privacy_tip, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Privacy-enhanced: Uses derived attributes when possible',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[700]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Warning: Declining required claims will cause verification to fail. '
              'The verifier will reject your presentation.',
              style: TextStyle(color: Colors.orange[900], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildClaimTile(
    String claimName, {
    required bool isRequired,
    required bool isSelected,
  }) {
    // Check if this is a derived attribute
    final derivedFrom = widget.policy.derivedAttributePreferences.entries
        .firstWhere(
          (e) => e.value == claimName,
          orElse: () => const MapEntry('', ''),
        )
        .key;

    final isDerived = derivedFrom.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isRequired ? 2 : 1,
      child: CheckboxListTile(
        title: Text(
          claimName,
          style: TextStyle(
            fontWeight: isRequired ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: isDerived
            ? Text(
                'Derived from: $derivedFrom (privacy-preserving)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green[700],
                  fontStyle: FontStyle.italic,
                ),
              )
            : null,
        value: isSelected,
        onChanged: (value) {
          if (value != null) {
            _toggleClaim(claimName, value);
          }
        },
        secondary: Icon(
          isRequired ? Icons.lock : Icons.lock_open,
          color: isRequired ? Colors.red : Colors.grey,
        ),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  Widget _buildDataMinimizationHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Only the selected claims will be disclosed to the verifier. '
              'Minimize disclosure to protect your privacy.',
              style: TextStyle(fontSize: 12, color: Colors.blue[900]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Extension to show policy-driven disclosure sheet.
extension PolicyDisclosureSheet on SelectiveDisclosureSheet {
  static Future<Map<String, bool>?> showWithPolicy({
    required BuildContext context,
    required PresentationPolicy policy,
    required dynamic credential,
    required List<String> availableClaims,
  }) async {
    final initialSelection = <String, bool>{};
    for (final claim in availableClaims) {
      // Default to true for required claims, false for optional
      final isRequired = policy.requiredClaims.any(
        (rc) => rc.claimName == claim,
      );
      initialSelection[claim] = isRequired;
    }

    bool willFail = false;

    return showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Select Claims to Disclose',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: PolicyDrivenDisclosureWidget(
                    policy: policy,
                    credential: credential,
                    initialSelection: initialSelection,
                    onSelectionChanged: (selection, fail) {
                      initialSelection.clear();
                      initialSelection.addAll(selection);
                      willFail = fail;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: willFail
                        ? null // Disable if will fail, but allow user to proceed
                        : () => Navigator.pop(context, initialSelection),
                    child: Text(
                      willFail
                          ? 'Continue Anyway (Will Fail)'
                          : 'Confirm Selection',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
