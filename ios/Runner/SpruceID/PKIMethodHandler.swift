import Flutter

extension SpruceIdChannelHandler {
  func handlePkiMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "generateKeyPair", "createCSR", "signWithCertificate":
      result(FlutterError(
        code: "REMOTE_KMS_REQUIRED",
        message: "PKI signing requires a remote KMS-backed key reference",
        details: nil
      ))
    case "verifyCertificateChain":
      result(FlutterError(
        code: "CRYPTOGRAPHIC_VERIFICATION_REQUIRED",
        message: "Certificate chain verification requires trusted anchors and a cryptographic verifier",
        details: nil
      ))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
