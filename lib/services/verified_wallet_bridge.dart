import '../rust/marty_bridge.dart/api.dart' as rust_api;

/// The Rust wallet owns protocol parsing, issuer verification and signature
/// verification. Dart only coordinates the remote holder and user approval.
abstract interface class VerifiedWalletBridge {
  Future<rust_api.FrbPreparedSdJwtReceipt> prepareReceipt({
    required String offerUri,
    String? txCode,
    required String holderPublicJwkJson,
  });

  Future<rust_api.FrbVerifiedSdJwtReceipt> completeReceipt({
    required String sessionId,
    required List<int> remoteSignature,
    required String issuerSnapshotJson,
  });

  Future<String> routePresentation({required String input});

  Future<rust_api.FrbPresentationRequest> parsePresentation({
    required String requestUri,
  });

  Future<rust_api.FrbPreparedSdJwtPresentation> preparePresentation({
    required String requestUri,
    required String approvedRequestDigest,
    required String credential,
    required String queryId,
    required List<String> claimsToDisclose,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  });

  Future<rust_api.FrbPresentationResponse> completePresentation({
    required String sessionId,
    required List<int> remoteSignature,
  });
}

class RustVerifiedWalletBridge implements VerifiedWalletBridge {
  const RustVerifiedWalletBridge();

  @override
  Future<rust_api.FrbPreparedSdJwtReceipt> prepareReceipt({
    required String offerUri,
    String? txCode,
    required String holderPublicJwkJson,
  }) => rust_api.walletPrepareVerifiedSdJwtReceipt(
    offerUri: offerUri,
    txCode: txCode,
    holderPublicJwkJson: holderPublicJwkJson,
  );

  @override
  Future<rust_api.FrbVerifiedSdJwtReceipt> completeReceipt({
    required String sessionId,
    required List<int> remoteSignature,
    required String issuerSnapshotJson,
  }) => rust_api.walletCompleteVerifiedSdJwtReceipt(
    sessionId: sessionId,
    remoteSignature: remoteSignature,
    issuerSnapshotJson: issuerSnapshotJson,
  );

  @override
  Future<String> routePresentation({required String input}) =>
      rust_api.walletRoutePresentationRequest(input: input);

  @override
  Future<rust_api.FrbPresentationRequest> parsePresentation({
    required String requestUri,
  }) => rust_api.walletParsePresentationRequest(requestUri: requestUri);

  @override
  Future<rust_api.FrbPreparedSdJwtPresentation> preparePresentation({
    required String requestUri,
    required String approvedRequestDigest,
    required String credential,
    required String queryId,
    required List<String> claimsToDisclose,
    required String issuerSnapshotJson,
    required String holderPublicJwkJson,
  }) => rust_api.walletPrepareVerifiedSdJwtPresentation(
    requestUri: requestUri,
    approvedRequestDigest: approvedRequestDigest,
    credential: credential,
    queryId: queryId,
    claimsToDisclose: claimsToDisclose,
    issuerSnapshotJson: issuerSnapshotJson,
    holderPublicJwkJson: holderPublicJwkJson,
  );

  @override
  Future<rust_api.FrbPresentationResponse> completePresentation({
    required String sessionId,
    required List<int> remoteSignature,
  }) => rust_api.walletCompleteVerifiedSdJwtPresentation(
    sessionId: sessionId,
    remoteSignature: remoteSignature,
  );
}
