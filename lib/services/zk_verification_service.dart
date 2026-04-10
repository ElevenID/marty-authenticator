import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../rust/marty_bridge.dart/api.dart';

/// Base class for ZK proof requests
abstract class ZkProofRequest {}

/// Request for Age Over 18 proof using the interactive Ligero protocol
class AgeOver18ProofRequest extends ZkProofRequest {
  final List<int> mdocBytes;
  final String issuerPkx;
  final String issuerPky;
  final String docType;
  final String birthDate;
  final List<int> sessionNonce;

  AgeOver18ProofRequest({
    required this.mdocBytes,
    required this.issuerPkx,
    required this.issuerPky,
    required this.docType,
    required this.birthDate,
    required this.sessionNonce,
  });
}

/// Request for a ZK proof based on a Presentation Definition
class PdProofRequest extends ZkProofRequest {
  final Map<String, dynamic> presentationDefinition;
  final List<int> mdocBytes;
  final String issuerPkx;
  final String issuerPky;
  final String docType;
  final Map<String, String> secrets;
  final List<int> sessionNonce;

  PdProofRequest({
    required this.presentationDefinition,
    required this.mdocBytes,
    required this.issuerPkx,
    required this.issuerPky,
    required this.docType,
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
      return await zkProve(
        predicateId: 'age_over_18',
        claimValue: request.birthDate,
        mdocBytes: request.mdocBytes,
        issuerPkx: request.issuerPkx,
        issuerPky: request.issuerPky,
        docType: request.docType,
        sessionNonce: request.sessionNonce,
      );
    } else if (request is PdProofRequest) {
      return await zkProveFromPresentationDefinition(
        presentationDefinitionJson: jsonEncode(request.presentationDefinition),
        mdocBytes: request.mdocBytes,
        issuerPkx: request.issuerPkx,
        issuerPky: request.issuerPky,
        docType: request.docType,
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
