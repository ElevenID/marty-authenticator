import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SeparatedSpruceIdDemoView extends ConsumerStatefulWidget {
  static const String routeName = '/separated_spruce_demo';

  const SeparatedSpruceIdDemoView({super.key});

  @override
  ConsumerState<SeparatedSpruceIdDemoView> createState() =>
      _SeparatedSpruceIdDemoViewState();
}

class _SeparatedSpruceIdDemoViewState
    extends ConsumerState<SeparatedSpruceIdDemoView> {
  String _status = 'Ready to test separated SpruceID technologies';
  String? _currentDid;
  String? _currentJwt;
  String? _currentCertificateId;

  // Platform channels for different technologies
  final _w3cChannel = const MethodChannel(
    'com.netknights.authenticator/spruce_w3c',
  );
  final _pkiChannel = const MethodChannel(
    'com.netknights.authenticator/spruce_pki',
  );
  final _jwtChannel = const MethodChannel(
    'com.netknights.authenticator/spruce_jwt',
  );
  final _mdocChannel = const MethodChannel(
    'com.netknights.authenticator/spruce_mdoc',
  );
  final _walletChannel = const MethodChannel(
    'com.netknights.authenticator/spruce_wallet',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpruceID - Separated Technologies'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
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

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PKI/X.509 Section (Recommended for most use cases)
                    _buildTechnologySection(
                      'PKI/X.509 Operations',
                      'Traditional certificate-based security - Recommended for enterprise use',
                      Colors.green,
                      [
                        _buildTechButton('Generate Key Pair', _generateKeyPair),
                        _buildTechButton(
                          'Create Certificate Signing Request',
                          _createCSR,
                        ),
                        _buildTechButton(
                          'Sign with X.509 Certificate',
                          _signWithCertificate,
                        ),
                        _buildTechButton(
                          'Verify Certificate Chain',
                          _verifyCertificateChain,
                        ),
                      ],
                    ),

                    // JWT/SD-JWT Section (URL-based issuers)
                    _buildTechnologySection(
                      'JWT/SD-JWT Operations',
                      'JSON Web Tokens with URL-based issuers - Standard for API authentication',
                      Colors.blue,
                      [
                        _buildTechButton('Create JWT (URL Issuer)', _createJWT),
                        _buildTechButton(
                          'Create SD-JWT (Selective Disclosure)',
                          _createSdJwt,
                        ),
                        _buildTechButton('Verify JWT', _verifyJWT),
                        _buildTechButton('Verify SD-JWT', _verifySdJwt),
                      ],
                    ),

                    // mDoc Section (X.509-based mobile documents)
                    _buildTechnologySection(
                      'mDoc/MDL Operations',
                      'ISO 18013-5 mobile driver\'s licenses with X.509 certificates',
                      Colors.orange,
                      [
                        _buildTechButton(
                          'Initialize Mobile Document',
                          _initializeMdl,
                        ),
                        _buildTechButton(
                          'Age Verification (21+)',
                          _ageVerification21,
                        ),
                        _buildTechButton(
                          'Create mDoc Response',
                          _createMdocResponse,
                        ),
                        _buildTechButton('Verify with X.509', _verifyWithX509),
                      ],
                    ),

                    // Wallet Section (Technology Agnostic)
                    _buildTechnologySection(
                      'Wallet Storage',
                      'Store and manage credentials of any format',
                      Colors.purple,
                      [
                        _buildTechButton(
                          'Store Test Credential',
                          _storeCredential,
                        ),
                        _buildTechButton(
                          'Get All Credentials',
                          _getAllCredentials,
                        ),
                        _buildTechButton(
                          'Get Credentials by Type',
                          _getCredentialsByType,
                        ),
                        _buildTechButton(
                          'Delete Credential',
                          _deleteCredential,
                        ),
                      ],
                    ),

                    // W3C Section (DID-based - only when required)
                    _buildTechnologySection(
                      'W3C Verifiable Credentials',
                      '⚠️ DID-based credentials - Only use when W3C compliance required',
                      Colors.red,
                      [
                        _buildTechButton(
                          'Initialize W3C (DID-based)',
                          _initializeW3C,
                        ),
                        _buildTechButton('Create DID', _createDid),
                        _buildTechButton('Resolve DID', _resolveDid),
                        _buildTechButton(
                          'Sign W3C VC',
                          _signVerifiableCredential,
                        ),
                        _buildTechButton(
                          'Verify W3C VC',
                          _verifyVerifiableCredential,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnologySection(
    String title,
    String description,
    Color color,
    List<Widget> buttons,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 24, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            ...buttons.map(
              (button) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: button,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onPressed, child: Text(text)),
    );
  }

  // PKI/X.509 Operations
  Future<void> _generateKeyPair() async {
    try {
      setState(
        () => _status = 'Generating RSA key pair for X.509 operations...',
      );
      final result = await _pkiChannel.invokeMethod('generateKeyPair', {
        'keyType': 'RSA',
        'keySize': 2048,
      });
      _currentCertificateId = result['keyId'];
      setState(
        () => _status =
            'PKI: Generated RSA key pair for X.509 certificate operations',
      );
    } catch (e) {
      setState(() => _status = 'PKI key generation failed: $e');
    }
  }

  Future<void> _createCSR() async {
    try {
      setState(() => _status = 'Creating Certificate Signing Request...');
      await _pkiChannel.invokeMethod('createCSR', {
        'subject': 'CN=Test User,O=Example Corp,C=US',
        'keyId': _currentCertificateId ?? 'default-key',
      });
      setState(
        () => _status =
            'PKI: Created Certificate Signing Request for traditional CA',
      );
    } catch (e) {
      setState(() => _status = 'CSR creation failed: $e');
    }
  }

  Future<void> _signWithCertificate() async {
    try {
      setState(() => _status = 'Signing document with X.509 certificate...');
      final testDoc = {
        'message': 'Hello World',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _pkiChannel.invokeMethod('signWithCertificate', {
        'document': testDoc,
        'certificateId': _currentCertificateId ?? 'default-cert',
      });
      setState(
        () => _status =
            'PKI: Document signed with X.509 certificate (traditional PKI)',
      );
    } catch (e) {
      setState(() => _status = 'Certificate signing failed: $e');
    }
  }

  Future<void> _verifyCertificateChain() async {
    try {
      setState(() => _status = 'Verifying X.509 certificate chain...');
      await _pkiChannel.invokeMethod('verifyCertificateChain', {
        'certificateChain': ['cert1', 'cert2', 'root'],
      });
      setState(
        () =>
            _status = 'PKI: Certificate chain verified against trusted root CA',
      );
    } catch (e) {
      setState(() => _status = 'Certificate verification failed: $e');
    }
  }

  // JWT Operations (URL-based issuers)
  Future<void> _createJWT() async {
    try {
      setState(() => _status = 'Creating JWT with URL issuer...');
      final result = await _jwtChannel.invokeMethod('createJWT', {
        'issuer': 'https://auth.example.com',
        'claims': {
          'sub': 'user123',
          'name': 'John Doe',
          'admin': true,
          'exp': (DateTime.now().millisecondsSinceEpoch / 1000 + 3600).round(),
        },
      });
      _currentJwt = result['jwt'];
      setState(
        () => _status =
            'JWT: Created with URL issuer (https://auth.example.com) - No DIDs',
      );
    } catch (e) {
      setState(() => _status = 'JWT creation failed: $e');
    }
  }

  Future<void> _createSdJwt() async {
    try {
      setState(() => _status = 'Creating SD-JWT with selective disclosure...');
      await _jwtChannel.invokeMethod('createSdJwt', {
        'issuer': 'https://university.edu',
        'claims': {
          'name': 'Alice Smith',
          'degree': 'Computer Science',
          'gpa': '3.8',
          'graduation_date': '2023-05-15',
          'student_id': 'hidden_field',
        },
        'selectivelyDisclosableClaims': ['gpa', 'student_id'],
      });
      setState(
        () => _status =
            'SD-JWT: Created with URL issuer - can selectively disclose claims',
      );
    } catch (e) {
      setState(() => _status = 'SD-JWT creation failed: $e');
    }
  }

  Future<void> _verifyJWT() async {
    try {
      setState(() => _status = 'Verifying JWT with URL issuer...');
      await _jwtChannel.invokeMethod('verifyJWT', {
        'jwt': _currentJwt ?? 'sample.jwt.token',
        'issuer': 'https://auth.example.com',
      });
      setState(() => _status = 'JWT: Verified against URL issuer public key');
    } catch (e) {
      setState(() => _status = 'JWT verification failed: $e');
    }
  }

  Future<void> _verifySdJwt() async {
    try {
      setState(() => _status = 'Verifying SD-JWT selective disclosure...');
      await _jwtChannel.invokeMethod('verifySdJwt', {
        'sdJwt': 'eyJ0eXAiOiJzZC1qd3QiLCJhbGciOiJSUzI1NiJ9.claims~disclosure1',
        'requiredClaims': ['name', 'degree'],
      });
      setState(
        () => _status = 'SD-JWT: Verified - only disclosed required claims',
      );
    } catch (e) {
      setState(() => _status = 'SD-JWT verification failed: $e');
    }
  }

  // mDoc Operations (X.509-based)
  Future<void> _initializeMdl() async {
    try {
      setState(
        () => _status = 'Initializing mobile driver\'s license with X.509...',
      );
      await _mdocChannel.invokeMethod('initializeMdl', {
        'mdlData': {
          'document_type': 'driving_license',
          'issuer_authority': 'CA Department of Motor Vehicles',
          'certificate_chain': 'x509_chain_data',
        },
      });
      setState(
        () => _status =
            'mDoc: Initialized with X.509 certificate from DMV (no DIDs)',
      );
    } catch (e) {
      setState(() => _status = 'mDoc initialization failed: $e');
    }
  }

  Future<void> _ageVerification21() async {
    try {
      setState(
        () => _status = 'Performing age verification (21+) using mDoc...',
      );
      await _mdocChannel.invokeMethod('presentForAgeVerification', {
        'minimumAge': 21,
      });
      setState(
        () => _status =
            'mDoc: Age verified (21+) using X.509-signed mobile document',
      );
    } catch (e) {
      setState(() => _status = 'Age verification failed: $e');
    }
  }

  Future<void> _createMdocResponse() async {
    try {
      setState(
        () => _status = 'Creating mDoc response with selective disclosure...',
      );
      await _mdocChannel.invokeMethod('createMdocResponse', {
        'requestedAttributes': ['age_over_21'],
        'hiddenAttributes': ['full_name', 'address', 'license_number'],
      });
      setState(
        () => _status =
            'mDoc: Created response with X.509 signature (minimal disclosure)',
      );
    } catch (e) {
      setState(() => _status = 'mDoc response creation failed: $e');
    }
  }

  Future<void> _verifyWithX509() async {
    try {
      setState(
        () => _status = 'Verifying mDoc with X.509 certificate chain...',
      );
      await _mdocChannel.invokeMethod('verifyWithX509', {
        'mdocData': 'signed_mobile_document',
        'trustedRoots': ['dmv_root_ca'],
      });
      setState(
        () => _status = 'mDoc: Verified against trusted X.509 root certificate',
      );
    } catch (e) {
      setState(() => _status = 'X.509 verification failed: $e');
    }
  }

  // Wallet Operations (Technology Agnostic)
  Future<void> _storeCredential() async {
    try {
      setState(() => _status = 'Storing test credential in wallet...');
      final testCredential = {
        'type': 'UniversityDegree',
        'format': 'jwt', // Could be 'jwt', 'mdoc', 'x509', or 'w3c-vc'
        'issuer': 'https://university.edu',
        'data': 'credential_content',
      };
      await _walletChannel.invokeMethod('storeCredential', {
        'credential': testCredential,
      });
      setState(
        () => _status = 'Wallet: Stored credential (format-agnostic storage)',
      );
    } catch (e) {
      setState(() => _status = 'Credential storage failed: $e');
    }
  }

  Future<void> _getAllCredentials() async {
    try {
      setState(() => _status = 'Retrieving all credentials from wallet...');
      final result = await _walletChannel.invokeMethod('getStoredCredentials');
      final credentials = result as List;
      setState(
        () => _status =
            'Wallet: Found ${credentials.length} credentials of mixed formats',
      );
    } catch (e) {
      setState(() => _status = 'Credential retrieval failed: $e');
    }
  }

  Future<void> _getCredentialsByType() async {
    try {
      setState(() => _status = 'Getting credentials by type...');
      final result = await _walletChannel.invokeMethod('getCredentialsByType', {
        'type': 'mDoc',
      });
      final credentials = result as List;
      setState(
        () => _status = 'Wallet: Found ${credentials.length} mDoc credentials',
      );
    } catch (e) {
      setState(() => _status = 'Type-based retrieval failed: $e');
    }
  }

  Future<void> _deleteCredential() async {
    try {
      setState(() => _status = 'Deleting test credential...');
      await _walletChannel.invokeMethod('deleteCredential', {
        'id': 'test-credential-1',
      });
      setState(() => _status = 'Wallet: Deleted credential from storage');
    } catch (e) {
      setState(() => _status = 'Credential deletion failed: $e');
    }
  }

  // W3C Operations (DID-based - use sparingly)
  Future<void> _initializeW3C() async {
    try {
      setState(
        () =>
            _status = 'Initializing W3C Verifiable Credentials (DID-based)...',
      );
      await _w3cChannel.invokeMethod('initialize');
      setState(
        () => _status =
            'W3C: Initialized DID-based credential system (use only when required)',
      );
    } catch (e) {
      setState(() => _status = 'W3C initialization failed: $e');
    }
  }

  Future<void> _createDid() async {
    try {
      setState(
        () => _status = 'Creating DID for W3C Verifiable Credentials...',
      );
      final result = await _w3cChannel.invokeMethod('createDid', {
        'method': 'key',
      });
      _currentDid = result['did'];
      setState(
        () => _status =
            'W3C: Created DID for W3C VC compliance (${result['did']})',
      );
    } catch (e) {
      setState(() => _status = 'DID creation failed: $e');
    }
  }

  Future<void> _resolveDid() async {
    if (_currentDid == null) {
      setState(() => _status = 'Please create a DID first');
      return;
    }
    try {
      setState(() => _status = 'Resolving DID to get public key...');
      await _w3cChannel.invokeMethod('resolveDid', {'did': _currentDid});
      setState(
        () => _status = 'W3C: DID resolved to DID Document for verification',
      );
    } catch (e) {
      setState(() => _status = 'DID resolution failed: $e');
    }
  }

  Future<void> _signVerifiableCredential() async {
    try {
      setState(() => _status = 'Signing W3C Verifiable Credential with DID...');
      final credential = {
        '@context': ['https://www.w3.org/2018/credentials/v1'],
        'type': ['VerifiableCredential', 'UniversityDegreeCredential'],
        'issuer': _currentDid ?? 'did:key:placeholder',
        'credentialSubject': {
          'id': 'did:key:student123',
          'degree': 'Bachelor of Science',
          'degreeType': 'Computer Science',
        },
      };
      await _w3cChannel.invokeMethod('signVerifiableCredential', {
        'credential': credential,
        'keyId': 'signing-key-1',
      });
      setState(
        () =>
            _status = 'W3C: Signed Verifiable Credential with DID-based proof',
      );
    } catch (e) {
      setState(() => _status = 'W3C VC signing failed: $e');
    }
  }

  Future<void> _verifyVerifiableCredential() async {
    try {
      setState(() => _status = 'Verifying W3C Verifiable Credential...');
      final testVC = {
        '@context': ['https://www.w3.org/2018/credentials/v1'],
        'type': ['VerifiableCredential'],
        'issuer': _currentDid ?? 'did:key:issuer',
        'proof': {'type': 'Ed25519Signature2018'},
      };
      await _w3cChannel.invokeMethod('verifyVerifiableCredential', {
        'credential': testVC,
      });
      setState(() => _status = 'W3C: Verified credential using DID resolution');
    } catch (e) {
      setState(() => _status = 'W3C VC verification failed: $e');
    }
  }
}
