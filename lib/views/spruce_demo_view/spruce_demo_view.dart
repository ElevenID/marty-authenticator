import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../spruce_client.dart';

class SpruceIdDemoView extends ConsumerStatefulWidget {
  static const String routeName = '/spruce_demo';

  const SpruceIdDemoView({super.key});

  @override
  ConsumerState<SpruceIdDemoView> createState() => _SpruceIdDemoViewState();
}

class _SpruceIdDemoViewState extends ConsumerState<SpruceIdDemoView> {
  String _status = 'Ready to test SpruceID integration';
  bool _isInitialized = false;
  String? _currentDid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpruceID Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_status, style: const TextStyle(fontSize: 14)),
                    if (_currentDid != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Current DID:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(_currentDid!, style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Core Operations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isInitialized ? null : _initializeSpruceId,
              child: Text(
                _isInitialized ? 'SpruceID Initialized' : 'Initialize SpruceID',
              ),
            ),
            ElevatedButton(
              onPressed: _isInitialized ? _createDid : null,
              child: const Text('Create DID'),
            ),
            ElevatedButton(
              onPressed: _currentDid != null ? _resolveDid : null,
              child: const Text('Resolve DID'),
            ),
            const SizedBox(height: 16),
            const Text(
              'mDoc/MDL Operations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isInitialized ? _testMdocOperations : null,
              child: const Text('Test mDoc Operations'),
            ),
            const SizedBox(height: 16),
            const Text(
              'OID4VC Operations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isInitialized ? _testOid4vcOperations : null,
              child: const Text('Test OID4VC Operations'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Wallet Operations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isInitialized ? _testWalletOperations : null,
              child: const Text('Test Wallet Operations'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeSpruceId() async {
    setState(() {
      _status = 'Initializing SpruceID...';
    });

    try {
      final client = SpruceIdClient();
      await client.initialize();
      setState(() {
        _isInitialized = true;
        _status = 'SpruceID initialized successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to initialize SpruceID: $e';
      });
    }
  }

  Future<void> _createDid() async {
    setState(() {
      _status = 'Creating DID...';
    });

    try {
      final client = SpruceIdClient();
      final did = await client.createDid(method: 'key');
      setState(() {
        _currentDid = did;
        _status = 'DID created successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to create DID: $e';
      });
    }
  }

  Future<void> _resolveDid() async {
    if (_currentDid == null) return;

    setState(() {
      _status = 'Resolving DID and verifying credential...';
    });

    try {
      // Create a test credential for verification
      final testCredential = {
        '@context': ['https://www.w3.org/2018/credentials/v1'],
        'type': ['VerifiableCredential'],
        'issuer': _currentDid!,
        'issuanceDate': DateTime.now().toIso8601String(),
        'credentialSubject': {'id': _currentDid!, 'name': 'Test User'},
        'proof': {
          'type': 'Ed25519Signature2018',
          'created': DateTime.now().toIso8601String(),
          'verificationMethod': '$_currentDid!#key1',
          'proofPurpose': 'assertionMethod',
          'proofValue': 'test-signature-value',
        },
      };

      final client = SpruceIdClient();
      final result = await client.verifyCredential(testCredential);
      setState(() {
        _status =
            'Credential verification: ${result['valid'] ?? false}. Status: ${result['status'] ?? 'unknown'}';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to verify credential: $e';
      });
    }
  }

  Future<void> _testMdocOperations() async {
    setState(() {
      _status = 'Testing mDoc operations...';
    });

    try {
      final mdocManager = SpruceIdMdocManager();
      await mdocManager.initializeMdl({'docType': 'driving_license'});

      final ageVerification = await mdocManager.presentForAgeVerification(
        minimumAge: 21,
      );

      setState(() {
        _status =
            'mDoc operations successful! Age verification: ${ageVerification['verified']}';
      });
    } catch (e) {
      setState(() {
        _status = 'mDoc operations failed: $e';
      });
    }
  }

  Future<void> _testOid4vcOperations() async {
    setState(() {
      _status = 'Testing OID4VC operations...';
    });

    try {
      final sdJwtManager = SpruceIdSdJwtManager();
      final sdJwt = await sdJwtManager.createSdJwt(
        issuer: 'https://example.com/issuer',
        claims: {'name': 'Test User', 'age': 25},
        selectivelyDisclosableClaims: ['age'],
      );

      setState(() {
        _status =
            'OID4VC operations successful! SD-JWT created: ${sdJwt['token']?.toString().substring(0, 50) ?? 'success'}...';
      });
    } catch (e) {
      setState(() {
        _status = 'OID4VC operations failed: $e';
      });
    }
  }

  Future<void> _testWalletOperations() async {
    setState(() {
      _status = 'Testing wallet operations...';
    });

    try {
      final walletManager = SpruceIdWalletManager();
      await walletManager.storeCredential({
        'type': 'test_credential',
        'data': {'test': true},
      });

      final credentials = await walletManager.getAllCredentials();

      setState(() {
        _status =
            'Wallet operations successful! Found ${credentials.length} credentials';
      });
    } catch (e) {
      setState(() {
        _status = 'Wallet operations failed: $e';
      });
    }
  }
}
