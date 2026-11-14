import FlutterMacOS

/// Channel boundary until remote holder, verification, wallet and mDoc services exist.
final class SpruceIdChannelHandler {
  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    let handler = SpruceIdChannelHandler()

    let w3c = FlutterMethodChannel(
      name: "com.netknights.authenticator/spruce_w3c",
      binaryMessenger: binaryMessenger
    )
    w3c.setMethodCallHandler { call, result in
      handler.handleW3c(call, result: result)
    }

    let mdoc = FlutterMethodChannel(
      name: "com.netknights.authenticator/spruce_mdoc",
      binaryMessenger: binaryMessenger
    )
    mdoc.setMethodCallHandler { call, result in
      handler.handleMdoc(call, result: result)
    }

    let jwt = FlutterMethodChannel(
      name: "com.netknights.authenticator/spruce_jwt",
      binaryMessenger: binaryMessenger
    )
    jwt.setMethodCallHandler { call, result in
      handler.handleJwt(call, result: result)
    }

    let pki = FlutterMethodChannel(
      name: "com.netknights.authenticator/spruce_pki",
      binaryMessenger: binaryMessenger
    )
    pki.setMethodCallHandler { call, result in
      handler.handlePki(call, result: result)
    }

    let wallet = FlutterMethodChannel(
      name: "com.netknights.authenticator/spruce_wallet",
      binaryMessenger: binaryMessenger
    )
    wallet.setMethodCallHandler { call, result in
      handler.handleWallet(call, result: result)
    }
  }

  private func reject(
    _ result: @escaping FlutterResult,
    code: String,
    message: String
  ) {
    result(FlutterError(code: code, message: message, details: nil))
  }

  private func handleW3c(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize", "createDid", "signVerifiableCredential":
      reject(result, code: "REMOTE_KMS_REQUIRED", message: "W3C holder signing requires a remote KMS-backed key reference")
    case "resolveDid", "verifyVerifiableCredential":
      reject(result, code: "CRYPTOGRAPHIC_VERIFICATION_REQUIRED", message: "DID and credential verification require a trusted cryptographic verifier")
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleMdoc(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initializeMdl", "createMdocResponse", "createDeviceEngagement":
      reject(result, code: "REMOTE_KMS_REQUIRED", message: "mDoc holder responses require a remote KMS-backed signing flow")
    case "presentForAgeVerification", "verifyWithX509", "presentForIdVerification":
      reject(result, code: "CRYPTOGRAPHIC_VERIFICATION_REQUIRED", message: "mDoc verification requires certificate-chain and device-authentication checks")
    case "startSession", "handleRequest", "getSessionStatus":
      reject(result, code: "SESSION_IMPLEMENTATION_REQUIRED", message: "mDoc proximity requires a real transport and session state")
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleJwt(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createJWT", "createSdJwt":
      reject(result, code: "REMOTE_KMS_REQUIRED", message: "JWT signing requires a remote KMS-backed holder flow")
    case "verifyJWT", "verifySdJwt":
      reject(result, code: "CRYPTOGRAPHIC_VERIFICATION_REQUIRED", message: "JWT verification requires a trusted cryptographic verifier")
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handlePki(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "generateKeyPair", "createCSR", "signWithCertificate":
      reject(result, code: "REMOTE_KMS_REQUIRED", message: "PKI signing requires a remote KMS-backed key reference")
    case "verifyCertificateChain":
      reject(result, code: "CRYPTOGRAPHIC_VERIFICATION_REQUIRED", message: "Certificate-chain verification requires trusted anchors")
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleWallet(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "storeCredential", "getCredentials", "getStoredCredentials",
         "getCredentialsByType", "deleteCredential", "exportWallet",
         "importWallet", "backupWallet":
      reject(result, code: "WALLET_STORAGE_REQUIRED", message: "Wallet storage requires an implemented persistent repository")
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
