import Flutter

extension SpruceIdChannelHandler {
  func handleJwtMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createJWT", "createSdJwt", "createSelectiveDisclosureJwt", "createSdJwtPresentation":
      result(FlutterError(
        code: "REMOTE_KMS_REQUIRED",
        message: "JWT signing requires a remote KMS-backed holder flow",
        details: nil
      ))
    case "verifyJWT", "verifySdJwt", "verifySelectiveDisclosure":
      result(FlutterError(
        code: "CRYPTOGRAPHIC_VERIFICATION_REQUIRED",
        message: "JWT verification requires a cryptographic verifier and trusted issuer key",
        details: nil
      ))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
