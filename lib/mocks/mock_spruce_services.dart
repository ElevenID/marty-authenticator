/// Mock implementations of SpruceID interfaces for testing
/// Provides configurable mock behavior with in-memory storage
library;

import 'dart:async';
import 'dart:convert';
import 'package:privacyidea_authenticator/interfaces/spruce_interfaces.dart';
import '../fixtures/spruce_credentials_fixtures.dart';
import '../utils/logger.dart';

/// Configuration for mock SpruceID services
class MockSpruceIdConfig {
  /// Simulated network delay for operations (milliseconds)
  final int responseDelayMs;

  /// Failure rate (0.0 to 1.0) for simulating errors
  final double failureRate;

  /// Whether to simulate slow network conditions
  final bool slowNetwork;

  /// Delay for slow network (milliseconds)
  final int slowNetworkDelayMs;

  /// Whether to enable verbose logging
  final bool verboseLogging;

  /// Callbacks for state changes
  final Map<String, Function(dynamic)> stateCallbacks;

  MockSpruceIdConfig({
    this.responseDelayMs = 100,
    this.failureRate = 0.0,
    this.slowNetwork = false,
    this.slowNetworkDelayMs = 3000,
    this.verboseLogging = false,
    Map<String, Function(dynamic)>? stateCallbacks,
  }) : stateCallbacks = stateCallbacks ?? {};

  /// Create a config for fast testing (no delays)
  factory MockSpruceIdConfig.fast() {
    return MockSpruceIdConfig(
      responseDelayMs: 0,
      failureRate: 0.0,
      slowNetwork: false,
    );
  }

  /// Create a config for realistic testing (with delays)
  factory MockSpruceIdConfig.realistic() {
    return MockSpruceIdConfig(
      responseDelayMs: 500,
      failureRate: 0.0,
      slowNetwork: false,
    );
  }

  /// Create a config for error testing
  factory MockSpruceIdConfig.errorProne() {
    return MockSpruceIdConfig(
      responseDelayMs: 100,
      failureRate: 0.3,
      slowNetwork: false,
    );
  }

  /// Create a config for slow network testing
  factory MockSpruceIdConfig.slowNetwork() {
    return MockSpruceIdConfig(
      responseDelayMs: 100,
      failureRate: 0.0,
      slowNetwork: true,
      slowNetworkDelayMs: 5000,
    );
  }
}

/// Base class for mock services with common functionality
abstract class MockServiceBase {
  final MockSpruceIdConfig config;
  final _random = DateTime.now().millisecondsSinceEpoch;

  MockServiceBase(this.config);

  /// Simulate network delay
  Future<void> _simulateDelay() async {
    if (config.slowNetwork) {
      await Future.delayed(Duration(milliseconds: config.slowNetworkDelayMs));
    } else if (config.responseDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: config.responseDelayMs));
    }
  }

  /// Check if operation should fail based on failure rate
  bool _shouldFail() {
    if (config.failureRate <= 0.0) return false;
    final random = _random % 100 / 100;
    return random < config.failureRate;
  }

  /// Execute operation with delay and failure simulation
  Future<T> execute<T>(
    String operationName,
    Future<T> Function() operation, {
    String? errorMessage,
  }) async {
    if (config.verboseLogging) {
      Logger.info('[MockSpruceId] Executing: $operationName');
    }

    await _simulateDelay();

    if (_shouldFail()) {
      final error = errorMessage ?? 'Mock error in $operationName';
      if (config.verboseLogging) {
        Logger.error('[MockSpruceId] Failed: $operationName - $error');
      }
      throw Exception(error);
    }

    try {
      final result = await operation();
      if (config.verboseLogging) {
        Logger.info('[MockSpruceId] Success: $operationName');
      }
      return result;
    } catch (e) {
      if (config.verboseLogging) {
        Logger.error('[MockSpruceId] Error: $operationName - $e');
      }
      rethrow;
    }
  }

  /// Notify state change
  void notifyStateChange(String event, dynamic data) {
    if (config.stateCallbacks.containsKey(event)) {
      config.stateCallbacks[event]!(data);
    }
  }
}

/// Mock implementation of ISpruceIdPlatformService
class MockSpruceIdPlatformService extends MockServiceBase
    implements ISpruceIdPlatformService {
  // In-memory storage
  final Map<String, Map<String, dynamic>> _credentials = {};
  final Map<String, String> _dids = {};
  bool _w3cInitialized = false;

  MockSpruceIdPlatformService([MockSpruceIdConfig? config])
    : super(config ?? MockSpruceIdConfig()) {
    Logger.debug('DEBUG: MockSpruceIdPlatformService constructor called');
    // Pre-populate with some dummy credentials for development
    _credentials['mock-mdl-1'] = {
      'id': 'mock-mdl-1',
      'type': 'mDL',
      'issuer': 'State of Utopia',
      'data': {
        'given_name': 'John',
        'family_name': 'Doe',
        'birth_date': '1980-01-01',
      },
    };

    _credentials['mock-mdl-2'] = {
      'id': 'mock-mdl-2',
      'type': 'mDL',
      'issuer': 'State of Utopia',
      'data': {
        'given_name': 'Jane',
        'family_name': 'Doe',
        'birth_date': '1985-05-15',
      },
    };

    _credentials['mock-vc-1'] = {
      'id': 'mock-vc-1',
      'type': 'VerifiableId',
      'issuer': 'Acme Corp',
      'data': {'employee_id': '12345', 'role': 'Developer'},
    };

    _credentials['mock-vc-2'] = {
      'id': 'mock-vc-2',
      'type': 'VerifiableId',
      'issuer': 'Acme Corp',
      'data': {'employee_id': '67890', 'role': 'Designer'},
    };

    _credentials['mock-gym-1'] = {
      'id': 'mock-gym-1',
      'type': 'VerifiableId',
      'issuer': 'Gold\'s Gym',
      'data': {'member_id': 'GG-999', 'level': 'Platinum'},
    };

    // Add some expired credentials for testing
    _credentials['mock-expired-1'] = {
      'id': 'mock-expired-1',
      'type': 'VerifiableId',
      'issuer': 'Metro Transit',
      'expirationDate': '2024-12-31T23:59:59Z', // Expired
      'data': {'pass_type': 'Monthly', 'zone': 'City Center'},
    };

    _credentials['mock-expired-2'] = {
      'id': 'mock-expired-2',
      'type': 'VerifiableId',
      'issuer': 'Movie Theater',
      'expirationDate': '2024-11-15T23:59:59Z', // Expired
      'data': {'membership': 'Premium', 'benefits': 'Free popcorn'},
    };

    _credentials['mock-expired-3'] = {
      'id': 'mock-expired-3',
      'type': 'mDL',
      'issuer': 'State of Utopia',
      'expirationDate': '2024-10-01T23:59:59Z', // Expired
      'data': {
        'given_name': 'Bob',
        'family_name': 'Smith',
        'birth_date': '1975-03-20',
      },
    };
  }

  @override
  bool get isInitialized => _w3cInitialized;

  // W3C VC Methods
  @override
  Future<void> initializeW3C() async {
    return execute('initializeW3C', () async {
      _w3cInitialized = true;
      notifyStateChange('w3c_initialized', {});
    });
  }

  @override
  Future<Map<String, dynamic>> createDid({String method = 'key'}) async {
    return execute('createDid', () async {
      final did = 'did:$method:z${DateTime.now().millisecondsSinceEpoch}';
      _dids[did] = method;
      notifyStateChange('did_created', {'did': did, 'method': method});
      return {'did': did, 'method': method};
    });
  }

  @override
  Future<Map<String, dynamic>> resolveDid(String did) async {
    return execute('resolveDid', () async {
      if (!_dids.containsKey(did)) {
        throw Exception('DID not found: $did');
      }
      return {
        'did': did,
        'method': _dids[did],
        'document': {'@context': 'https://www.w3.org/ns/did/v1', 'id': did},
      };
    });
  }

  @override
  Future<Map<String, dynamic>> signVerifiableCredential(
    Map<String, dynamic> credential, {
    String? keyId,
  }) async {
    return execute('signVerifiableCredential', () async {
      final signed = Map<String, dynamic>.from(credential);
      signed['proof'] = {
        'type': 'Ed25519Signature2020',
        'created': DateTime.now().toIso8601String(),
        'proofPurpose': 'assertionMethod',
        'proofValue': 'mock-signature-${DateTime.now().millisecondsSinceEpoch}',
      };
      if (keyId != null) {
        signed['proof']['verificationMethod'] = keyId;
      }
      notifyStateChange('credential_signed', {'id': credential['id']});
      return signed;
    });
  }

  @override
  Future<Map<String, dynamic>> verifyVerifiableCredential(
    Map<String, dynamic> credential,
  ) async {
    return execute('verifyVerifiableCredential', () async {
      // Check if expired
      if (credential.containsKey('expirationDate')) {
        final expiry = DateTime.parse(credential['expirationDate'] as String);
        if (expiry.isBefore(DateTime.now())) {
          notifyStateChange('credential_expired', {'id': credential['id']});
          return {'valid': false, 'reason': 'expired'};
        }
      }

      notifyStateChange('credential_verified', {'id': credential['id']});
      return {'valid': true};
    });
  }

  // PKI/X.509 Methods
  @override
  Future<Map<String, dynamic>> generateKeyPair({
    String keyType = 'RSA',
    int keySize = 2048,
  }) async {
    return execute('generateKeyPair', () async {
      final keyId = 'key-${DateTime.now().millisecondsSinceEpoch}';
      notifyStateChange('keypair_generated', {
        'id': keyId,
        'type': keyType,
        'size': keySize,
      });
      return {
        'keyId': keyId,
        'publicKey': 'mock-public-key-$keyId',
        'keyType': keyType,
        'keySize': keySize,
      };
    });
  }

  @override
  Future<Map<String, dynamic>> createCSR(
    String subject, {
    String? keyId,
  }) async {
    return execute('createCSR', () async {
      return {
        'csr': 'mock-csr-${DateTime.now().millisecondsSinceEpoch}',
        'subject': subject,
        'keyId': keyId,
      };
    });
  }

  @override
  Future<Map<String, dynamic>> signWithCertificate(
    Map<String, dynamic> document,
    String certificateId,
  ) async {
    return execute('signWithCertificate', () async {
      final signed = Map<String, dynamic>.from(document);
      signed['signature'] = {
        'certificateId': certificateId,
        'signature':
            'mock-cert-signature-${DateTime.now().millisecondsSinceEpoch}',
        'timestamp': DateTime.now().toIso8601String(),
      };
      return signed;
    });
  }

  @override
  Future<Map<String, dynamic>> verifyCertificateChain(
    List<String> certificateChain,
  ) async {
    return execute('verifyCertificateChain', () async {
      return {'valid': true, 'chainLength': certificateChain.length};
    });
  }

  // JWT Methods
  @override
  Future<Map<String, dynamic>> createJWT(
    String issuer,
    Map<String, dynamic> claims,
  ) async {
    return execute('createJWT', () async {
      final jwt =
          'eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.${base64Encode(utf8.encode(jsonEncode(claims)))}.mock-signature';
      return {'jwt': jwt, 'issuer': issuer};
    });
  }

  @override
  Future<Map<String, dynamic>> verifyJWT(String jwt, String issuer) async {
    return execute('verifyJWT', () async {
      return {'valid': true, 'issuer': issuer};
    });
  }

  @override
  Future<Map<String, dynamic>> createSdJwt(
    String issuer,
    Map<String, dynamic> claims,
    List<String> selectivelyDisclosableClaims,
  ) async {
    return execute('createSdJwt', () async {
      final sdJwt = 'mock.sd.jwt~${selectivelyDisclosableClaims.join('~')}';
      return {
        'sdJwt': sdJwt,
        'issuer': issuer,
        'disclosableClaims': selectivelyDisclosableClaims,
      };
    });
  }

  @override
  Future<Map<String, dynamic>> verifySdJwt(
    String sdJwt,
    List<String> requiredClaims,
  ) async {
    return execute('verifySdJwt', () async {
      return {'valid': true, 'requiredClaims': requiredClaims};
    });
  }

  // mDoc Methods
  @override
  Future<Map<String, dynamic>> initializeMdl(
    Map<String, dynamic> mdlData,
  ) async {
    return execute('initializeMdl', () async {
      final id = 'mdl-${DateTime.now().millisecondsSinceEpoch}';
      _credentials[id] = mdlData;
      notifyStateChange('mdl_initialized', {'id': id});
      return {'id': id, 'initialized': true};
    });
  }

  @override
  Future<Map<String, dynamic>> presentForAgeVerification(int minimumAge) async {
    return execute('presentForAgeVerification', () async {
      final birthDate = DateTime.now().subtract(Duration(days: 365 * 25));
      return {
        'ageVerified': true,
        'minimumAge': minimumAge,
        'birthDate': birthDate.toIso8601String(),
      };
    });
  }

  @override
  Future<Map<String, dynamic>> createMdocResponse(
    List<String> requestedAttributes,
    List<String> hiddenAttributes,
  ) async {
    return execute('createMdocResponse', () async {
      return {
        'response': 'mock-mdoc-response',
        'requestedAttributes': requestedAttributes,
        'hiddenAttributes': hiddenAttributes,
      };
    });
  }

  // Wallet Methods
  @override
  Future<void> storeCredential(Map<String, dynamic> credential) async {
    return execute('storeCredential', () async {
      final id =
          credential['id'] as String? ??
          'cred-${DateTime.now().millisecondsSinceEpoch}';
      _credentials[id] = credential;
      notifyStateChange('credential_stored', {'id': id});
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getStoredCredentials() async {
    return execute('getStoredCredentials', () async {
      return _credentials.values.toList();
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type) async {
    return execute('getCredentialsByType', () async {
      return _credentials.values.where((cred) {
        final types = cred['type'];
        if (types is List) {
          return types.contains(type);
        }
        return types == type;
      }).toList();
    });
  }

  @override
  Future<void> deleteCredential(String id) async {
    return execute('deleteCredential', () async {
      _credentials.remove(id);
      notifyStateChange('credential_deleted', {'id': id});
    });
  }

  // Helper methods for testing
  void clearAllData() {
    _credentials.clear();
    _dids.clear();
    _w3cInitialized = false;
  }

  void preloadFixtures({CredentialState state = CredentialState.valid}) {
    // Preload W3C credentials
    final w3cCreds = W3CCredentialFixtures.allTypes(state: state);
    for (final cred in w3cCreds) {
      final id = cred['id'] as String;
      _credentials[id] = cred;
    }
  }

  Map<String, dynamic> getStorageSnapshot() {
    return {
      'credentials': Map.from(_credentials),
      'dids': Map.from(_dids),
      'initialized': _w3cInitialized,
    };
  }
}

/// Mock implementation of ISpruceIdClient
class MockSpruceIdClient extends MockServiceBase implements ISpruceIdClient {
  final ISpruceIdPlatformService platformService;

  MockSpruceIdClient(this.platformService, [MockSpruceIdConfig? config])
    : super(config ?? MockSpruceIdConfig());

  @override
  Future<void> initialize() async {
    return platformService.initializeW3C();
  }

  @override
  Future<String> createDid({String method = 'key'}) async {
    final result = await platformService.createDid(method: method);
    return result['did'] as String;
  }

  @override
  Future<Map<String, dynamic>> signCredential(
    Map<String, dynamic> credential,
  ) async {
    return platformService.signVerifiableCredential(credential);
  }

  @override
  Future<Map<String, dynamic>> verifyCredential(
    Map<String, dynamic> credential,
  ) async {
    return platformService.verifyVerifiableCredential(credential);
  }

  @override
  Future<Map<String, dynamic>> createMdocResponse({
    required List<String> requestedAttributes,
    List<String>? hiddenAttributes,
  }) async {
    return platformService.createMdocResponse(
      requestedAttributes,
      hiddenAttributes ?? [],
    );
  }

  @override
  Future<Map<String, dynamic>> createSdJwtPresentation({
    required String issuer,
    required Map<String, dynamic> claims,
    required List<String> discloseKeys,
  }) async {
    return platformService.createSdJwt(issuer, claims, discloseKeys);
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentials() async {
    return platformService.getStoredCredentials();
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type) async {
    return platformService.getCredentialsByType(type);
  }
}

/// Mock implementation of ISpruceIdMdocManager
class MockSpruceIdMdocManager extends MockServiceBase
    implements ISpruceIdMdocManager {
  final ISpruceIdPlatformService platformService;

  MockSpruceIdMdocManager(this.platformService, [MockSpruceIdConfig? config])
    : super(config ?? MockSpruceIdConfig());

  @override
  Future<Map<String, dynamic>> initializeMdl(Map<String, dynamic> mdlData) {
    return platformService.initializeMdl(mdlData);
  }

  @override
  Future<Map<String, dynamic>> presentForAgeVerification({
    required int minimumAge,
  }) {
    return platformService.presentForAgeVerification(minimumAge);
  }

  @override
  Future<Map<String, dynamic>> presentForIdVerification({
    required List<String> requestedAttributes,
    List<String>? hiddenAttributes,
  }) {
    return platformService.createMdocResponse(
      requestedAttributes,
      hiddenAttributes ?? [],
    );
  }
}

/// Mock implementation of ISpruceIdSdJwtManager
class MockSpruceIdSdJwtManager extends MockServiceBase
    implements ISpruceIdSdJwtManager {
  final ISpruceIdPlatformService platformService;

  MockSpruceIdSdJwtManager(this.platformService, [MockSpruceIdConfig? config])
    : super(config ?? MockSpruceIdConfig());

  @override
  Future<Map<String, dynamic>> createSdJwt({
    required String issuer,
    required Map<String, dynamic> claims,
    required List<String> selectivelyDisclosableClaims,
  }) {
    return platformService.createSdJwt(
      issuer,
      claims,
      selectivelyDisclosableClaims,
    );
  }

  @override
  Future<Map<String, dynamic>> present({
    required String issuer,
    required Map<String, dynamic> claims,
    required List<String> discloseClaims,
  }) {
    return platformService.createSdJwt(issuer, claims, discloseClaims);
  }
}

/// Mock implementation of ISpruceIdWalletManager
class MockSpruceIdWalletManager extends MockServiceBase
    implements ISpruceIdWalletManager {
  final ISpruceIdPlatformService platformService;

  MockSpruceIdWalletManager(this.platformService, [MockSpruceIdConfig? config])
    : super(config ?? MockSpruceIdConfig());

  @override
  Future<void> storeCredential(Map<String, dynamic> credential) {
    return platformService.storeCredential(credential);
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type) {
    return platformService.getCredentialsByType(type);
  }

  @override
  Future<void> deleteCredential(String credentialId) {
    return platformService.deleteCredential(credentialId);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllCredentials() {
    return platformService.getStoredCredentials();
  }
}

/// Helper class to create all mock services with shared config
class MockSpruceIdServices {
  final MockSpruceIdConfig config;
  late final MockSpruceIdPlatformService platformService;
  late final MockSpruceIdClient client;
  late final MockSpruceIdMdocManager mdocManager;
  late final MockSpruceIdSdJwtManager sdJwtManager;
  late final MockSpruceIdWalletManager walletManager;

  MockSpruceIdServices({MockSpruceIdConfig? config})
    : config = config ?? MockSpruceIdConfig() {
    platformService = MockSpruceIdPlatformService(this.config);
    client = MockSpruceIdClient(platformService, this.config);
    mdocManager = MockSpruceIdMdocManager(platformService, this.config);
    sdJwtManager = MockSpruceIdSdJwtManager(platformService, this.config);
    walletManager = MockSpruceIdWalletManager(platformService, this.config);
  }

  /// Create services with default/realistic config (alias for realistic())
  factory MockSpruceIdServices.createDefault({MockSpruceIdConfig? config}) {
    return MockSpruceIdServices(
      config: config ?? MockSpruceIdConfig.realistic(),
    );
  }

  /// Create services with fast config (no delays)
  factory MockSpruceIdServices.fast() {
    return MockSpruceIdServices(config: MockSpruceIdConfig.fast());
  }

  /// Create services with realistic delays
  factory MockSpruceIdServices.realistic() {
    return MockSpruceIdServices(config: MockSpruceIdConfig.realistic());
  }

  /// Create services configured for error testing
  factory MockSpruceIdServices.errorProne() {
    return MockSpruceIdServices(config: MockSpruceIdConfig.errorProne());
  }

  /// Create services with slow network simulation
  factory MockSpruceIdServices.slowNetwork() {
    return MockSpruceIdServices(config: MockSpruceIdConfig.slowNetwork());
  }

  /// Clear all mock data
  void clearAll() {
    platformService.clearAllData();
  }

  /// Preload fixtures into the mock storage
  void preloadFixtures({CredentialState state = CredentialState.valid}) {
    platformService.preloadFixtures(state: state);
  }

  /// Get a snapshot of current storage state
  Map<String, dynamic> getSnapshot() {
    return platformService.getStorageSnapshot();
  }
}
