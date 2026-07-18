import 'package:flutter/material.dart';

class PresentationRequestView extends StatefulWidget {
  final Map<String, dynamic> requestDetails;
  final List<Map<String, dynamic>> matchingCredentials;
  final Function(Map<String, dynamic> selection) onApprove;
  final VoidCallback onReject;

  const PresentationRequestView({
    super.key,
    required this.requestDetails,
    required this.matchingCredentials,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<PresentationRequestView> createState() =>
      _PresentationRequestViewState();
}

class _PresentationRequestViewState extends State<PresentationRequestView> {
  String? _selectedCredentialId;
  final Map<String, bool> _selectedFields = {};

  @override
  void initState() {
    super.initState();
    if (widget.matchingCredentials.isNotEmpty) {
      _selectCredential(widget.matchingCredentials.first);
    }
  }

  void _selectCredential(Map<String, dynamic> credential) {
    setState(() {
      _selectedCredentialId = credential['id'];
      _selectedFields.clear();

      // Initialize all fields as selected by default
      final fields =
          credential['requestedFields'] as Map<String, dynamic>? ?? {};
      fields.forEach((namespace, fieldList) {
        if (fieldList is List) {
          for (var field in fieldList) {
            _selectedFields['$namespace/$field'] = true;
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCredential = widget.matchingCredentials.firstWhere(
      (c) => c['id'] == _selectedCredentialId,
      orElse: () => widget.matchingCredentials.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentation Request'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onReject,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request from: ${widget.requestDetails['verifier'] ?? 'Unknown Verifier'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Purpose: ${widget.requestDetails['purpose'] ?? 'Verification'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Divider(),
          if (widget.matchingCredentials.length > 1) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCredentialId,
                decoration: const InputDecoration(
                  labelText: 'Select Credential',
                ),
                items: widget.matchingCredentials.map<DropdownMenuItem<String>>(
                  (c) {
                    return DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Text(
                        c['type']?.toString() ?? 'Unknown Credential',
                      ),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  if (value != null) {
                    final cred = widget.matchingCredentials.firstWhere(
                      (c) => c['id'] == value,
                    );
                    _selectCredential(cred);
                  }
                },
              ),
            ),
            const Divider(),
          ],
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Information to Share',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ..._buildFieldList(selectedCredential),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (_selectedCredentialId == null) return;

                      // Construct selection result
                      final selection = {
                        'credentialId': _selectedCredentialId,
                        'selectedFields': _selectedFields.entries
                            .where((e) => e.value)
                            .map((e) => e.key)
                            .toList(),
                      };
                      widget.onApprove(selection);
                    },
                    child: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFieldList(Map<String, dynamic> credential) {
    final fields = credential['requestedFields'] as Map<String, dynamic>? ?? {};
    final widgets = <Widget>[];

    fields.forEach((namespace, fieldList) {
      if (fieldList is List) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              namespace,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        );

        for (var field in fieldList) {
          final key = '$namespace/$field';
          widgets.add(
            CheckboxListTile(
              title: Text(field.toString()),
              value: _selectedFields[key] ?? false,
              onChanged: (bool? value) {
                setState(() {
                  _selectedFields[key] = value ?? false;
                });
              },
            ),
          );
        }
      }
    });

    return widgets;
  }
}
