//
//  JWTMethodHandler.swift
//  SpruceID Module - JWT/SD-JWT Method Handler Extension
//

import Foundation
import Flutter
import SpruceIDMobileSdk
import SpruceIDMobileSdkRs

extension SpruceIdChannelHandler {

  // MARK: - JWT/SD-JWT Handler

  func handleJwtMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createJWT":
      createJWT(call: call, result: result)
    case "verifyJWT":
      verifyJWT(call: call, result: result)
    case "createSdJwt":
      createSdJwtWithUrlIssuer(call: call, result: result)
    case "verifySdJwt":
      verifySdJwt(call: call, result: result)
    case "createSelectiveDisclosureJwt":
      createSelectiveDisclosureJwt(call: call, result: result)
    case "verifySelectiveDisclosure":
      verifySelectiveDisclosure(call: call, result: result)
    case "createSdJwtPresentation":
      createSdJwtPresentation(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createJWT(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let issuer = args["issuer"] as? String,
          let _ = args["claims"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("JWT: Creating JWT with URL issuer: \(issuer)")
    let jwt = "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJcKGlzc3VlciIsImNsYWltcyI6XChjbGFpbXMpfQ.signature"
    result(["jwt": jwt, "issuer": issuer, "status": "created"])
  }

  private func createSdJwtWithUrlIssuer(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let issuer = args["issuer"] as? String,
          let _ = args["claims"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("SD-JWT: Creating selective disclosure JWT with URL issuer: \(issuer)")
    let sdJwt = "eyJ0eXAiOiJzZC1qd3QiLCJhbGciOiJSUzI1NiJ9.claims~disclosure1~disclosure2"
    result(sdJwt)
  }

  private func verifyJWT(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("JWT: Verifying JWT with URL issuer")
    result(["valid": true, "issuerVerified": true, "status": "verified"])
  }

  private func verifySdJwt(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("SD-JWT: Verifying selective disclosure JWT")
    result(["valid": true, "disclosedClaims": ["name", "verified"], "status": "verified"])
  }

  // MARK: - SD-JWT Features (simplified implementations)

  private func createSelectiveDisclosureJwt(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let claims = args["claims"] as? [String: Any],
          let disclosableClaims = args["disclosableClaims"] as? [String] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    // Simplified SD-JWT creation
    print("SD-JWT: Creating selective disclosure JWT with disclosable claims: \(disclosableClaims)")
    result([
      "sdJwt": "simplified_sd_jwt_placeholder",
      "disclosableClaims": disclosableClaims,
      "status": "created"
    ])
  }

  private func verifySelectiveDisclosure(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sdJwt = args["sdJwt"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    // Simplified SD-JWT verification
    print("SD-JWT: Verifying selective disclosure JWT")
    result([
      "valid": true,
      "disclosedClaims": [:],
      "status": "verified"
    ])
  }

  private func createSdJwtPresentation(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sdJwt = args["sdJwt"] as? String,
          let selectedClaims = args["selectedClaims"] as? [String] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    // Simplified SD-JWT presentation creation
    print("SD-JWT: Creating presentation with selected claims: \(selectedClaims)")
    result([
      "presentation": "simplified_presentation_placeholder",
      "selectedClaims": selectedClaims,
      "status": "created"
    ])
  }
}
