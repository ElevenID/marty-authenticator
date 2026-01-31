import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../rust/marty_bridge/api.dart';

/// Base class for ZK proof requests
abstract class ZkProofRequest {}

/// Request for Age Over 18 proof using the interactive Ligero protocol
class AgeOver18ProofRequest extends ZkProofRequest {
  final Uint8List msoBytes;
  final Uint8List signature;
  final String birthDate;
  final Uint8List sessionNonce;

  AgeOver18ProofRequest({
    required this.msoBytes,
    required this.signature,
    required this.birthDate,
    required this.sessionNonce,
  });
}

/// Request for a ZK proof based on a Presentation Definition
class PdProofRequest extends ZkProofRequest {
  final Map<String, dynamic> presentationDefinition;
  final Uint8List msoBytes;
  final Uint8List signature;
  final Map<String, String> secrets;
  final Uint8List sessionNonce;

  PdProofRequest({
    required this.presentationDefinition,
    required this.msoBytes,
    required this.signature,
    required this.secrets,
    required this.sessionNonce,
  });
}

class ZkVerificationService {
  Future<bool> isSupported() async {
    try {
      return await zkIsSupportedOnDevice();
    } catch (e) {
      return false;
    }
  }

  /// Generate a ZK proof based on the request type
  Future<Uint8List> generateProof(ZkProofRequest request) async {
    if (request is AgeOver18ProofRequest) {
      return await zkProveAgeOver18Interactive(
        msoBytes: request.msoBytes,
        signature: request.signature,
        birthDate: request.birthDate,
        sessionNonce: request.sessionNonce,
      );
    } else if (request is PdProofRequest) {
      return await zkProveFromPresentationDefinition(
        presentationDefinitionJson: jsonEncode(request.presentationDefinition),
        msoBytes: request.msoBytes,
        signature: request.signature,
        secretsJson: jsonEncode(request.secrets),
        sessionNonce: request.sessionNonce,
      );
    }

    throw UnimplementedError(
      'Unsupported ZK proof request type: ${request.runtimeType}',
    );
  }
}

final zkVerificationServiceProvider = Provider<ZkVerificationService>((ref) {
  return ZkVerificationService();
});
