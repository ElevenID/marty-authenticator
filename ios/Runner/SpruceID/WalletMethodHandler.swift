import Flutter

extension SpruceIdChannelHandler {
  func handleWalletMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "storeCredential", "getCredentials", "getStoredCredentials",
         "getCredentialsByType", "deleteCredential", "exportWallet",
         "importWallet", "backupWallet":
      result(FlutterError(
        code: "WALLET_STORAGE_REQUIRED",
        message: "Wallet storage requires an implemented persistent repository",
        details: nil
      ))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
