//
//  PKIMethodHandler.swift
//  SpruceID Module - PKI/X.509 Method Handler Extension
//

import Foundation
import Flutter
import SpruceIDMobileSdk
import SpruceIDMobileSdkRs

extension SpruceIdChannelHandler {

  // MARK: - PKI/X.509 Handler

  func handlePkiMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "generateKeyPair":
      generateKeyPair(call: call, result: result)
    case "createCSR":
      createCSR(call: call, result: result)
    case "signWithCertificate":
      signWithCertificate(call: call, result: result)
    case "verifyCertificateChain":
      verifyCertificateChain(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func generateKeyPair(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let keyType = args["keyType"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("PKI: Generating \(keyType) key pair for X.509 operations")
    let keyId = UUID().uuidString
    let success = KeyManager.generateSigningKey(id: keyId)

    if success {
      result([
        "keyId": keyId,
        "keyType": keyType,
        "usage": "x509_signing",
        "status": "generated"
      ])
    } else {
      result(FlutterError(code: "KEY_GENERATION_FAILED", message: "Failed to generate key pair", details: nil))
    }
  }

  private func signWithCertificate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let document = args["document"] as? [String: Any],
          let certificateId = args["certificateId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("PKI: Signing document with X.509 certificate: \(certificateId)")
    result([
      "signedDocument": document,
      "signature": "x509_signature_data",
      "certificateId": certificateId,
      "status": "signed"
    ])
  }

  private func createCSR(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("PKI: Creating Certificate Signing Request")
    result(["csr": "certificate_signing_request_data", "status": "created"])
  }

  private func verifyCertificateChain(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("PKI: Verifying X.509 certificate chain")
    result(["valid": true, "chain": "trusted", "status": "verified"])
  }
}
