import '../rust/marty_bridge.dart/api.dart' as rust_api;

/// The Rust wallet owns protocol parsing, issuer verification and signature
/// verification. Dart only coordinates the remote holder and user approval.
abstract interface class VerifiedWalletBridge {
  Future<rust_api.FrbPreparedSdJwtReceipt> prepareReceipt({
    required String offerUri,
    String? txCode,
    required String holderPublicJwkJson,
    required String issuerSnapshotJson,
  });

  Future<String> completeReceipt({
    required String sessionId,
    required List<int> remoteSignature,
    required String issuerSnapshotJson,
  });

  Future<rust_api.FrbVerifiedSdJwtReceipt> finalizeReceipt({
    required String responseId,
    required String issuerSnapshotJson,
  });

  Future<String> routePresentation({required String input});

  Future<rust_api.FrbPreparedSdJwtPresentation> preparePresentation({
    required String sessionId,
    required String governanceJson,
    required List<String> claimsToDisclose,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  });

  Future<String> reviewCredential({
    required String requestUri,
    required String governanceJson,
    required String credential,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  });

  Future<rust_api.FrbPresentationResponse> completePresentation({
    required String sessionId,
    required List<int> remoteSignature,
    required String governanceJson,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  });

  Future<void> cancelPresentation({required String sessionId});
}

class RustVerifiedWalletBridge implements VerifiedWalletBridge {
  const RustVerifiedWalletBridge();

  @override
  Future<String> reviewCredential({
    required String requestUri,
    required String governanceJson,
    required String credential,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  }) => rust_api.walletReviewGovernedSdJwtPresentation(
    requestUri: requestUri,
    governanceJson: governanceJson,
    credential: credential,
    issuerSnapshotJson: issuerSnapshotJson,
    holderPublicJwkJson: holderPublicJwkJson,
  );

  @override
  Future<rust_api.FrbPreparedSdJwtReceipt> prepareReceipt({
    required String offerUri,
    String? txCode,
    required String holderPublicJwkJson,
    required String issuerSnapshotJson,
  }) => rust_api.walletPrepareVerifiedSdJwtReceipt(
    offerUri: offerUri,
    txCode: txCode,
    holderPublicJwkJson: holderPublicJwkJson,
    issuerSnapshotJson: issuerSnapshotJson,
  );

  @override
  Future<String> completeReceipt({
    required String sessionId,
    required List<int> remoteSignature,
    required String issuerSnapshotJson,
  }) => rust_api.walletCompleteVerifiedSdJwtReceipt(
    sessionId: sessionId,
    remoteSignature: remoteSignature,
    issuerSnapshotJson: issuerSnapshotJson,
  );

  @override
  Future<rust_api.FrbVerifiedSdJwtReceipt> finalizeReceipt({
    required String responseId,
    required String issuerSnapshotJson,
  }) => rust_api.walletFinalizeVerifiedSdJwtReceipt(
    responseId: responseId,
    issuerSnapshotJson: issuerSnapshotJson,
  );

  @override
  Future<String> routePresentation({required String input}) =>
      rust_api.walletRoutePresentationRequest(input: input);

  @override
  Future<rust_api.FrbPreparedSdJwtPresentation> preparePresentation({
    required String sessionId,
    required String governanceJson,
    required List<String> claimsToDisclose,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  }) => rust_api.walletPrepareGovernedSdJwtPresentation(
    sessionId: sessionId,
    governanceJson: governanceJson,
    claimsToDisclose: claimsToDisclose,
    issuerSnapshotJson: issuerSnapshotJson,
    holderPublicJwkJson: holderPublicJwkJson,
  );

  @override
  Future<rust_api.FrbPresentationResponse> completePresentation({
    required String sessionId,
    required List<int> remoteSignature,
    required String governanceJson,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  }) => rust_api.walletCompleteGovernedSdJwtPresentation(
    sessionId: sessionId,
    remoteSignature: remoteSignature,
    governanceJson: governanceJson,
    issuerSnapshotJson: issuerSnapshotJson,
    holderPublicJwkJson: holderPublicJwkJson,
  );

  @override
  Future<void> cancelPresentation({required String sessionId}) =>
      rust_api.walletCancelGovernedSdJwtPresentation(sessionId: sessionId);
}
