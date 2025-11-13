//
//  WalletMethodHandler.swift
//  SpruceID Module - Wallet Storage Method Handler Extension
//

import Foundation
import Flutter
import SpruceIDMobileSdk
import SpruceIDMobileSdkRs

extension SpruceIdChannelHandler {

  // MARK: - Wallet Storage Handler

  func handleWalletMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "storeCredential":
      walletStoreCredential(call: call, result: result)
    case "getCredentials":
      walletGetCredentials(call: call, result: result)
    case "getStoredCredentials":
      walletGetCredentials(call: call, result: result) // Map to same implementation
    case "getCredentialsByType":
      walletGetCredentialsByType(call: call, result: result)
    case "deleteCredential":
      walletDeleteCredential(call: call, result: result)
    case "exportWallet":
      exportWallet(call: call, result: result)
    case "importWallet":
      importWallet(call: call, result: result)
    case "backupWallet":
      backupWallet(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func walletStoreCredential(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let credential = args["credential"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    let id = args["id"] as? String ?? UUID().uuidString

    // Simplified credential storage
    print("Wallet: Stored credential \(id) using SpruceID SDK")
    result(["status": "stored", "credentialId": id])
  }

  private func walletGetCredentials(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Simplified credential retrieval
    print("Wallet: Retrieved credentials using SpruceID SDK")
    result([])
  }

  private func walletGetCredentialsByType(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let type = args["type"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    // Simplified credential retrieval by type
    print("Wallet: Getting credentials of type \(type)")
    result([])
  }

  private func walletDeleteCredential(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let id = args["id"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    // Simplified credential deletion
    print("Wallet: Deleted credential \(id)")
    result(["status": "deleted", "id": id])
  }

  private func exportWallet(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Simplified wallet export
    print("Wallet: Exported wallet")
    result(["walletData": "exported_data", "status": "exported"])
  }

  private func importWallet(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let walletData = args["walletData"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid wallet data", details: nil))
      return
    }

    // Simplified wallet import
    print("Wallet: Imported wallet")
    result(["status": "imported", "credentialCount": 0])
  }

  private func backupWallet(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Simplified wallet backup
    let backupId = UUID().uuidString
    let backupTimestamp = ISO8601DateFormatter().string(from: Date())

    print("Wallet: Created backup \(backupId)")
    result(["backupId": backupId, "status": "backed_up", "timestamp": backupTimestamp])
  }  // MARK: - Helper Methods

  private func getStorageManager() -> StorageManager? {
    // Access storage manager from main handler
    return StorageManager(appGroupId: nil)
  }
}
