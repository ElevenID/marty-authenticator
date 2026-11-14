import Flutter

extension SpruceIdChannelHandler {
  func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initializeW3C", "createDid", "signVerifiableCredential",
         "createPresentation", "handleOID4VCOffer", "handleOID4VPRequest",
         "handleOID4VCOfferRefactored", "handleOID4VPRequestRefactored",
         "handleVpRequest", "addCredentialToPack", "getStoredCredentials":
      result(FlutterError(
        code: "REMOTE_KMS_REQUIRED",
        message: "W3C wallet operations require a remote KMS-backed holder flow",
        details: nil
      ))
    case "resolveDid", "verifyVerifiableCredential":
      result(FlutterError(
        code: "CRYPTOGRAPHIC_VERIFICATION_REQUIRED",
        message: "DID and credential verification require a trusted cryptographic verifier",
        details: nil
      ))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
