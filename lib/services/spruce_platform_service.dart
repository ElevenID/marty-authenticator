import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../interfaces/spruce_interfaces.dart';
import '../utils/spruce_channels.dart';
import '../utils/logger.dart';
import 'spruce_platform_service_extended.dart';
import 'spruce_platform_service_web.dart';

/// Exception thrown when SpruceID operations fail
class SpruceIdException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  const SpruceIdException(this.code, this.message, [this.details]);

  @override
  String toString() => 'SpruceIdException($code): $message';
}

/// Service for managing SpruceID platform channels with separated technologies
class SpruceIdPlatformService implements ISpruceIdPlatformService {
  static final _instance = SpruceIdPlatformService._internal();
  factory SpruceIdPlatformService() => _instance;
  SpruceIdPlatformService._internal();

  // Separated platform channels
  final MethodChannel _w3cChannel = const MethodChannel(SpruceIdChannels.w3c);
  final MethodChannel _pkiChannel = const MethodChannel(SpruceIdChannels.pki);
  final MethodChannel _jwtChannel = const MethodChannel(SpruceIdChannels.jwt);
  final MethodChannel _mdocChannel = const MethodChannel(SpruceIdChannels.mdoc);
  final MethodChannel _walletChannel = const MethodChannel(
    SpruceIdChannels.wallet,
  );

  // Expose channels for subclasses
  MethodChannel get w3cChannel => _w3cChannel;
  MethodChannel get pkiChannel => _pkiChannel;
  MethodChannel get jwtChannel => _jwtChannel;
  MethodChannel get mdocChannel => _mdocChannel;
  MethodChannel get walletChannel => _walletChannel;

  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  /// Protected constructor for subclasses
  SpruceIdPlatformService.protected();

  @override
  Future<void> initializeW3C() async {
    try {
      await _w3cChannel.invokeMethod(SpruceIdW3CMethods.initialize);
      _initialized = true;
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to initialize W3C DID system: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // W3C VC Methods (DID-based - use sparingly)
  // ========================

  @override
  Future<Map<String, dynamic>> createDid({String method = 'key'}) async {
    if (!_initialized) await initializeW3C();

    try {
      final result = await _w3cChannel.invokeMethod(
        SpruceIdW3CMethods.createDid,
        {'method': method},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to create DID: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> resolveDid(String did) async {
    try {
      final result = await _w3cChannel.invokeMethod(
        SpruceIdW3CMethods.resolveDid,
        {'did': did},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to resolve DID: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> signVerifiableCredential(
    Map<String, dynamic> credential, {
    String? keyId,
  }) async {
    try {
      final result = await _w3cChannel.invokeMethod(
        SpruceIdW3CMethods.signVerifiableCredential,
        {'credential': credential, 'keyId': ?keyId},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to sign verifiable credential: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> verifyVerifiableCredential(
    Map<String, dynamic> credential,
  ) async {
    try {
      final result = await _w3cChannel.invokeMethod(
        SpruceIdW3CMethods.verifyVerifiableCredential,
        {'credential': credential},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to verify verifiable credential: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // PKI/X.509 Methods (Recommended for enterprise)
  // ========================

  @override
  Future<Map<String, dynamic>> generateKeyPair({
    String keyType = 'RSA',
    int keySize = 2048,
  }) async {
    try {
      final result = await _pkiChannel.invokeMethod(
        SpruceIdPkiMethods.generateKeyPair,
        {'keyType': keyType, 'keySize': keySize},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to generate key pair: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createCSR(
    String subject, {
    String? keyId,
  }) async {
    try {
      final result = await _pkiChannel.invokeMethod(
        SpruceIdPkiMethods.createCSR,
        {'subject': subject, 'keyId': ?keyId},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to create CSR: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> signWithCertificate(
    Map<String, dynamic> document,
    String certificateId,
  ) async {
    try {
      final result = await _pkiChannel.invokeMethod(
        SpruceIdPkiMethods.signWithCertificate,
        {'document': document, 'certificateId': certificateId},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to sign with certificate: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> verifyCertificateChain(
    List<String> certificateChain,
  ) async {
    try {
      final result = await _pkiChannel.invokeMethod(
        SpruceIdPkiMethods.verifyCertificateChain,
        {'certificateChain': certificateChain},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to verify certificate chain: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // JWT Methods (URL issuer-based)
  // ========================

  @override
  Future<Map<String, dynamic>> createJWT(
    String issuer,
    Map<String, dynamic> claims,
  ) async {
    try {
      final result = await _jwtChannel.invokeMethod(
        SpruceIdJwtMethods.createJWT,
        {'issuer': issuer, 'claims': claims},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to create JWT: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> verifyJWT(String jwt, String issuer) async {
    try {
      final result = await _jwtChannel.invokeMethod(
        SpruceIdJwtMethods.verifyJWT,
        {'jwt': jwt, 'issuer': issuer},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to verify JWT: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createSdJwt(
    String issuer,
    Map<String, dynamic> claims,
    List<String> selectivelyDisclosableClaims,
  ) async {
    try {
      final result = await _jwtChannel
          .invokeMethod(SpruceIdJwtMethods.createSdJwt, {
            'issuer': issuer,
            'claims': claims,
            'selectivelyDisclosableClaims': selectivelyDisclosableClaims,
          });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to create SD-JWT: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> verifySdJwt(
    String sdJwt,
    List<String> requiredClaims,
  ) async {
    try {
      final result = await _jwtChannel.invokeMethod(
        SpruceIdJwtMethods.verifySdJwt,
        {'sdJwt': sdJwt, 'requiredClaims': requiredClaims},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to verify SD-JWT: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // mDoc Methods (X.509-based mobile documents)
  // ========================

  @override
  Future<Map<String, dynamic>> initializeMdl(
    Map<String, dynamic> mdlData,
  ) async {
    try {
      final result = await _mdocChannel.invokeMethod(
        SpruceIdMdocMethods.initializeMdl,
        {'mdlData': mdlData},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to initialize MDL: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> presentForAgeVerification(int minimumAge) async {
    try {
      final result = await _mdocChannel.invokeMethod(
        SpruceIdMdocMethods.presentForAgeVerification,
        {'minimumAge': minimumAge},
      );
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to present for age verification: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createMdocResponse(
    List<String> requestedAttributes,
    List<String> hiddenAttributes,
  ) async {
    try {
      final result = await _mdocChannel
          .invokeMethod(SpruceIdMdocMethods.createMdocResponse, {
            'requestedAttributes': requestedAttributes,
            'hiddenAttributes': hiddenAttributes,
          });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to create mDoc response: ${e.message}',
        e.details,
      );
    }
  }

  // ========================
  // Wallet Methods (Technology agnostic)
  // ========================

  @override
  Future<void> storeCredential(Map<String, dynamic> credential) async {
    try {
      await _walletChannel.invokeMethod(SpruceIdWalletMethods.storeCredential, {
        'credential': credential,
      });
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to store credential: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getStoredCredentials() async {
    try {
      final result = await _walletChannel.invokeMethod(
        SpruceIdWalletMethods.getCredentials,
      );
      return List<Map<String, dynamic>>.from(result ?? []);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to get credentials: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCredentialsByType(String type) async {
    try {
      final result = await _walletChannel.invokeMethod(
        SpruceIdWalletMethods.getCredentialsByType,
        {'type': type},
      );
      return List<Map<String, dynamic>>.from(result ?? []);
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to get credentials by type: ${e.message}',
        e.details,
      );
    }
  }

  @override
  Future<void> deleteCredential(String id) async {
    try {
      await _walletChannel.invokeMethod(
        SpruceIdWalletMethods.deleteCredential,
        {'id': id},
      );
    } on PlatformException catch (e) {
      throw SpruceIdException(
        e.code,
        'Failed to delete credential: ${e.message}',
        e.details,
      );
    }
  }
}

/// Provider for SpruceID platform service
final spruceIdPlatformServiceProvider = Provider<ISpruceIdPlatformService>((
  ref,
) {
  // Use Web implementation for Web platform
  if (kIsWeb) {
    Logger.debug('DEBUG: Using SpruceIdPlatformServiceWeb');
    return SpruceIdPlatformServiceWeb();
  }

  // Desktop uses the platform-neutral implementation. Native mobile builds
  // use the extended platform-channel service below.
  if (defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    Logger.debug('DEBUG: Using SpruceIdPlatformServiceWeb on desktop');
    return SpruceIdPlatformServiceWeb();
  }

  Logger.debug('DEBUG: Using Real SpruceIdPlatformServiceExtended');
  return SpruceIdPlatformServiceExtended();
});

/// Provider for initialization state
final spruceIdInitializationProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(spruceIdPlatformServiceProvider);
  await service.initializeW3C();
});
