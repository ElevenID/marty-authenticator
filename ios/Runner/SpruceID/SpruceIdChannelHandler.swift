//
//  SpruceIdChannelHandler.swift
//  SpruceID Module - Main Channel Handler
//

import Foundation
import Flutter

/// Routes platform channels to implemented operations or explicit errors.
class SpruceIdChannelHandler: NSObject {
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

}
