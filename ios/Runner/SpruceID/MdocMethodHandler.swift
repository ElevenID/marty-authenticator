import Flutter

extension SpruceIdChannelHandler {
  func handleMdocMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initializeMdl", "createMdocResponse", "createDeviceEngagement",
         "handleMdocOID4VP":
      result(FlutterError(
        code: "REMOTE_KMS_REQUIRED",
        message: "mDoc holder responses require a remote KMS-backed signing flow",
        details: nil
      ))
    case "presentForAgeVerification", "verifyWithX509", "presentForIdVerification":
      result(FlutterError(
        code: "CRYPTOGRAPHIC_VERIFICATION_REQUIRED",
        message: "mDoc verification requires certificate-chain and device-authentication checks",
        details: nil
      ))
    case "startSession", "handleRequest", "getSessionStatus":
      result(FlutterError(
        code: "SESSION_IMPLEMENTATION_REQUIRED",
        message: "mDoc proximity sessions require a real transport and session state",
        details: nil
      ))
    case "addMdocToPack", "getMdocCredentials":
      result(FlutterError(
        code: "WALLET_STORAGE_REQUIRED",
        message: "mDoc storage requires an implemented wallet repository",
        details: nil
      ))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
