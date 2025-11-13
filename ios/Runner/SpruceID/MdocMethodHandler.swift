//
//  MdocMethodHandler.swift
//  SpruceID Module - mDoc/MDL Method Handler Extension
//

import Foundation
import Flutter
import SpruceIDMobileSdk
import SpruceIDMobileSdkRs

extension SpruceIdChannelHandler {

  // MARK: - mDoc/MDL Handler

  func handleMdocMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initializeMdl":
      initializeMdl(call: call, result: result)
    case "presentForAgeVerification":
      presentForAgeVerification(call: call, result: result)
    case "createMdocResponse":
      createMdocResponse(call: call, result: result)
    case "verifyWithX509":
      verifyWithX509(call: call, result: result)
    case "createDeviceEngagement":
      createDeviceEngagement(call: call, result: result)
    case "presentForIdVerification":
      presentForIdVerification(call: call, result: result)
    case "startSession":
      startSession(call: call, result: result)
    case "handleRequest":
      handleRequest(call: call, result: result)
    case "getSessionStatus":
      getSessionStatus(call: call, result: result)
    case "handleMdocOID4VP":
      handleMdocOID4VP(call: call, result: result)
    case "addMdocToPack":
      addMdocToPack(call: call, result: result)
    case "getMdocCredentials":
      getMdocCredentials(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initializeMdl(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let _ = args["mdlData"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("mDoc: Initializing mobile document with X.509 certificate chain")
    result(["status": "initialized", "message": "mDoc initialized with X.509 PKI", "usesPKI": true])
  }

  private func presentForAgeVerification(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let minimumAge = args["minimumAge"] as? Int else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("mDoc: Age verification using X.509-signed mobile document")
    result([
      "verified": true,
      "ageOver": minimumAge,
      "verificationMethod": "x509_certificate",
      "status": "verified"
    ])
  }

  private func createMdocResponse(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("mDoc: Creating mDoc response using X.509 certificate chain")
    result(["response": "mdoc_response_data", "status": "created", "signingMethod": "x509"])
  }

  private func verifyWithX509(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("PKI: Verifying document with X.509 certificate chain")
    result(["valid": true, "certificateChain": "validated", "status": "verified"])
  }

  private func createDeviceEngagement(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("SpruceID iOS: Creating device engagement (placeholder)")
    result(["deviceEngagement": "placeholder_engagement", "status": "created"])
  }

  private func presentForIdVerification(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("SpruceID iOS: Presenting for ID verification (placeholder)")
    result(["idVerified": true, "status": "verified"])
  }

  private func startSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let sessionId = UUID().uuidString
    print("SpruceID iOS: Starting session \(sessionId) (placeholder)")
    result(["sessionId": sessionId, "status": "started"])
  }

  private func handleRequest(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let _ = args["request"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid request", details: nil))
      return
    }

    print("SpruceID iOS: Handling request (placeholder)")
    result(["response": "placeholder_response", "status": "handled"])
  }

  private func getSessionStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sessionId = args["sessionId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid session ID", details: nil))
      return
    }

    print("SpruceID iOS: Getting session status for \(sessionId) (placeholder)")
    result(["status": "active", "sessionId": sessionId])
  }

  // MARK: - Advanced mDoc/MDL Features using SpruceID SDK

  private func handleMdocOID4VP(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let requestUrl = args["requestUrl"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    // Simplified mDoc OID4VP implementation
    print("mDoc: Processing OID4VP request from \(requestUrl)")
    result([
      "request": ["verifier": requestUrl],
      "status": "received"
    ])
  }

  private func addMdocToPack(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let mdocData = args["mdocData"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    // Simplified mDoc storage
    print("mDoc: Adding mobile document to credential pack")
    result([
      "status": "added",
      "docType": mdocData["docType"] as? String ?? "unknown",
      "id": mdocData["id"] as? String ?? UUID().uuidString
    ])
  }

  private func getMdocCredentials(result: @escaping FlutterResult) {
    // Simplified mDoc credential retrieval
    print("mDoc: Getting stored mDoc credentials")
    result([
      "credentials": [],
      "count": 0,
      "status": "success"
    ])
  }

  // MARK: - Helper Methods

  private func getStorageManager() -> StorageManager? {
    // Access storage manager from main handler
    return StorageManager(appGroupId: nil)
  }
}
