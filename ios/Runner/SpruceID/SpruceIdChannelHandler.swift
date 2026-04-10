//
//  SpruceIdChannelHandler.swift
//  SpruceID Module - Main Channel Handler
//

import Foundation
import Flutter
import SpruceIDMobileSdk
import SpruceIDMobileSdkRs

/// Handler for SpruceID platform channels with advanced SDK integration
class SpruceIdChannelHandler: NSObject {
  // Core crypto and storage
  private var keyManager: KeyManager?
  private var storageManager: StorageManager?

  // Advanced SDK components
  private var credentialPack: CredentialPack?
  private var contextMap: [String: Any] = [:]

  // Pending requests for split flow
  static var pendingMdocRequests: [String: Any] = [:]

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    let handler = SpruceIdChannelHandler()

    // W3C Verifiable Credentials channel (DID-based)
    let w3cChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_w3c", binaryMessenger: binaryMessenger)
    w3cChannel.setMethodCallHandler(handler.handleMethodCall)

    // mDoc/MDL channel (X.509-based)
    let mdocChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_mdoc", binaryMessenger: binaryMessenger)
    mdocChannel.setMethodCallHandler(handler.handleMdocMethodCall)

    // JWT/SD-JWT channel (URL issuer-based)
    let jwtChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_jwt", binaryMessenger: binaryMessenger)
    jwtChannel.setMethodCallHandler(handler.handleJwtMethodCall)

    // PKI/X.509 channel (certificate-based)
    let pkiChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_pki", binaryMessenger: binaryMessenger)
    pkiChannel.setMethodCallHandler(handler.handlePkiMethodCall)

    // Wallet storage channel (agnostic)
    let walletChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_wallet", binaryMessenger: binaryMessenger)
    walletChannel.setMethodCallHandler(handler.handleWalletMethodCall)
  }

  internal func initializeSpruceId() {
    keyManager = KeyManager()
    storageManager = StorageManager(appGroupId: nil)

    // Initialize basic SDK components that actually exist
    credentialPack = CredentialPack()

    // Set up default context map for JSON-LD contexts
    contextMap = [
      "https://www.w3.org/2018/credentials/v1": "https://www.w3.org/2018/credentials/v1",
      "https://w3id.org/security/suites/ed25519-2018/v1": "https://w3id.org/security/suites/ed25519-2018/v1"
    ]

    print("SpruceID: Initialized with SDK features - CredentialPack and protocol support")
  }
}
