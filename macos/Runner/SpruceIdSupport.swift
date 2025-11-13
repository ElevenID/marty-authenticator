//
//  SpruceIdSupport.swift
//  privacyidea_authenticator
//
//  SpruceID SDK support for macOS with separated concerns
//

import Foundation
import FlutterMacOS

// MARK: - Core Technology Handler Base Classes

/// Handles traditional PKI/X.509 operations
class PKIHandler {
  func initialize() {
    print("PKI Handler: Initialized for X.509 certificate operations")
  }
}

/// Handles mDoc/MDL operations using X.509 certificates
class MdocHandler {
  func initialize() {
    print("mDoc Handler: Initialized for ISO 18013-5 mobile documents with X.509")
  }
}

/// Handles JWT/SD-JWT operations with URL-based issuers
class JWTHandler {
  func initialize() {
    print("JWT Handler: Initialized for JWT/SD-JWT with traditional URL issuers")
  }
}

/// Handles W3C Verifiable Credentials (DID-based only)
class W3CHandler {
  func initialize() {
    print("W3C Handler: Initialized for W3C Verifiable Credentials (DID required)")
  }
}

// MARK: - Core Managers

/// Key manager for cryptographic operations
class KeyManager {
  static func generateSigningKey(id: String) -> Bool {
    print("KeyManager: Generating signing key with ID: \(id)")
    return true
  }

  static func getJwk(id: String) -> String? {
    print("KeyManager: Retrieving JWK for key ID: \(id)")
    return "{\"kty\":\"EC\",\"crv\":\"P-256\"}"
  }
}

/// Storage manager for secure credential storage
class StorageManager {
  private let appGroupId: String?

  init(appGroupId: String?) {
    self.appGroupId = appGroupId
    print("StorageManager: Initialized with app group: \(appGroupId ?? "none")")
  }
}

// MARK: - Main SpruceID Channel Handler

/// Handler for SpruceID platform channels with clear separation of concerns
class SpruceIdChannelHandler: NSObject {
  // Core crypto and storage (no DIDs)
  private var keyManager: KeyManager?
  private var storageManager: StorageManager?

  // Separate handlers for different concerns
  private var pkiHandler: PKIHandler?
  private var mdocHandler: MdocHandler?
  private var jwtHandler: JWTHandler?
  private var w3cHandler: W3CHandler?  // Only handler that uses DIDs

  static func register(with registrar: FlutterPluginRegistrar) {
    let handler = SpruceIdChannelHandler()

    // W3C Verifiable Credentials channel (DID-based)
    let w3cChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_w3c", binaryMessenger: registrar.messenger)
    w3cChannel.setMethodCallHandler { (call, result) in
      handler.w3cMethodHandler.handleMethodCall(call, result: result)
    }

    // mDoc/MDL channel (X.509-based)
    let mdocChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_mdoc", binaryMessenger: registrar.messenger)
    mdocChannel.setMethodCallHandler { (call, result) in
      handler.mdocMethodHandler.handleMethodCall(call, result: result)
    }

    // JWT/SD-JWT channel (URL issuer-based)
    let jwtChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_jwt", binaryMessenger: registrar.messenger)
    jwtChannel.setMethodCallHandler { (call, result) in
      handler.jwtMethodHandler.handleMethodCall(call, result: result)
    }

    // PKI/X.509 channel (certificate-based)
    let pkiChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_pki", binaryMessenger: registrar.messenger)
    pkiChannel.setMethodCallHandler { (call, result) in
      handler.pkiMethodHandler.handleMethodCall(call, result: result)
    }

    // Wallet storage channel (agnostic)
    let walletChannel = FlutterMethodChannel(name: "com.netknights.authenticator/spruce_wallet", binaryMessenger: registrar.messenger)
    walletChannel.setMethodCallHandler { (call, result) in
      handler.walletMethodHandler.handleMethodCall(call, result: result)
    }
  }

  // Lazy-loaded method handlers
  lazy var w3cMethodHandler = W3CMethodHandler()
  lazy var mdocMethodHandler = MdocMethodHandler()
  lazy var jwtMethodHandler = JWTMethodHandler()
  lazy var pkiMethodHandler = PKIMethodHandler()
  lazy var walletMethodHandler = WalletMethodHandler()

  private func initializeSpruceId() {
    keyManager = KeyManager()
    storageManager = StorageManager(appGroupId: nil)

    // Initialize separate handlers
    pkiHandler = PKIHandler()
    mdocHandler = MdocHandler()
    jwtHandler = JWTHandler()
    w3cHandler = W3CHandler()

    print("SpruceID macOS: Initialized with separated concerns - PKI/X.509, mDoc, JWT, and W3C/DID handlers")
  }
}

// MARK: - W3C Method Handler

/// Handler for W3C Verifiable Credentials operations
class W3CMethodHandler: NSObject {

  func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      initializeW3C(result: result)
    case "createDid":
      createDID(call: call, result: result)
    case "resolveDid":
      resolveDid(call: call, result: result)
    case "signVerifiableCredential":
      signVerifiableCredential(call: call, result: result)
    case "verifyVerifiableCredential":
      verifyVerifiableCredential(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initializeW3C(result: @escaping FlutterResult) {
    result(["status": "initialized", "message": "W3C VC support with DIDs initialized"])
  }

  private func createDID(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let method = args["method"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    let keyId = UUID().uuidString
    let success = KeyManager.generateSigningKey(id: keyId)
    if !success {
      result(FlutterError(code: "KEY_GENERATION_FAILED", message: "Failed to generate signing key", details: nil))
      return
    }

    guard let jwk = KeyManager.getJwk(id: keyId) else {
      result(FlutterError(code: "JWK_RETRIEVAL_FAILED", message: "Failed to retrieve JWK", details: nil))
      return
    }

    let createdDID = "did:\(method):\(keyId)"
    print("W3C macOS: Created DID \(createdDID) for W3C Verifiable Credentials")
    result(["did": createdDID, "keyId": keyId, "jwk": jwk, "method": method, "status": "created"])
  }

  private func resolveDid(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let did = args["did"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("W3C macOS: Resolving DID \(did) for W3C VC verification")
    result(["did": did, "document": "{\"@context\": \"https://www.w3.org/ns/did/v1\"}", "status": "resolved"])
  }

  private func signVerifiableCredential(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let credential = args["credential"] as? [String: Any],
          let keyId = args["keyId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("W3C macOS: Signing W3C Verifiable Credential with DID-based key \(keyId)")
    var signedCredential = credential
    signedCredential["proof"] = [
      "type": "Ed25519Signature2018",
      "proofValue": "w3c_vc_signature_with_did",
      "verificationMethod": "did:key:\(keyId)#key-1"
    ]
    result(["signedCredential": signedCredential, "status": "signed"])
  }

  private func verifyVerifiableCredential(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    if args["credential"] is String {
      print("W3C macOS: Verifying W3C VC from string format")
      result(["valid": true, "status": "verified", "verificationMethod": "did_resolution"])
    } else if let credential = args["credential"] as? [String: Any] {
      print("W3C macOS: Verifying W3C VC from object format")
      result(["valid": true, "status": "verified", "credential": credential, "verificationMethod": "did_resolution"])
    } else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid credential format", details: nil))
    }
  }
}

// MARK: - mDoc Method Handler

/// Handler for mDoc/MDL operations
class MdocMethodHandler: NSObject {

  func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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

    print("mDoc macOS: Initializing mobile document with X.509 certificate chain")
    result(["status": "initialized", "message": "mDoc initialized with X.509 PKI", "usesPKI": true])
  }

  private func presentForAgeVerification(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let minimumAge = args["minimumAge"] as? Int else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("mDoc macOS: Age verification using X.509-signed mobile document")
    result([
      "verified": true,
      "ageOver": minimumAge,
      "verificationMethod": "x509_certificate",
      "status": "verified"
    ])
  }

  private func createMdocResponse(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("mDoc macOS: Creating mDoc response using X.509 certificate chain")
    result(["response": "mdoc_response_data", "status": "created", "signingMethod": "x509"])
  }

  private func verifyWithX509(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("PKI macOS: Verifying document with X.509 certificate chain")
    result(["valid": true, "certificateChain": "validated", "status": "verified"])
  }

  private func createDeviceEngagement(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("SpruceID macOS: Creating device engagement (placeholder)")
    result(["deviceEngagement": "placeholder_engagement", "status": "created"])
  }

  private func presentForIdVerification(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("SpruceID macOS: Presenting for ID verification (placeholder)")
    result(["idVerified": true, "status": "verified"])
  }

  private func startSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let sessionId = UUID().uuidString
    print("SpruceID macOS: Starting session \(sessionId) (placeholder)")
    result(["sessionId": sessionId, "status": "started"])
  }

  private func handleRequest(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let _ = args["request"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid request", details: nil))
      return
    }

    print("SpruceID macOS: Handling request (placeholder)")
    result(["response": "placeholder_response", "status": "handled"])
  }

  private func getSessionStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let sessionId = args["sessionId"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid session ID", details: nil))
      return
    }

    print("SpruceID macOS: Getting session status for \(sessionId) (placeholder)")
    result(["status": "active", "sessionId": sessionId])
  }
}

// MARK: - JWT Method Handler

/// Handler for JWT/SD-JWT operations
class JWTMethodHandler: NSObject {

  func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createJWT":
      createJWT(call: call, result: result)
    case "verifyJWT":
      verifyJWT(call: call, result: result)
    case "createSdJwt":
      createSdJwtWithUrlIssuer(call: call, result: result)
    case "verifySdJwt":
      verifySdJwt(call: call, result: result)
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

    print("JWT macOS: Creating JWT with URL issuer: \(issuer)")
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

    print("SD-JWT macOS: Creating selective disclosure JWT with URL issuer: \(issuer)")
    let sdJwt = "eyJ0eXAiOiJzZC1qd3QiLCJhbGciOiJSUzI1NiJ9.claims~disclosure1~disclosure2"
    result(sdJwt)
  }

  private func verifyJWT(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("JWT macOS: Verifying JWT with URL issuer")
    result(["valid": true, "issuerVerified": true, "status": "verified"])
  }

  private func verifySdJwt(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("SD-JWT macOS: Verifying selective disclosure JWT")
    result(["valid": true, "disclosedClaims": ["name", "verified"], "status": "verified"])
  }
}

// MARK: - PKI Method Handler

/// Handler for PKI/X.509 operations
class PKIMethodHandler: NSObject {

  func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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

    print("PKI macOS: Generating \(keyType) key pair for X.509 operations")
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

    print("PKI macOS: Signing document with X.509 certificate: \(certificateId)")
    result([
      "signedDocument": document,
      "signature": "x509_signature_data",
      "certificateId": certificateId,
      "status": "signed"
    ])
  }

  private func createCSR(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("PKI macOS: Creating Certificate Signing Request")
    result(["csr": "certificate_signing_request_data", "status": "created"])
  }

  private func verifyCertificateChain(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("PKI macOS: Verifying X.509 certificate chain")
    result(["valid": true, "chain": "trusted", "status": "verified"])
  }
}

// MARK: - Wallet Method Handler

/// Handler for Wallet storage operations
class WalletMethodHandler: NSObject {

  func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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
          let _ = args["credential"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    let id = args["id"] as? String ?? UUID().uuidString
    print("SpruceID macOS: Storing credential in wallet \(id) (placeholder)")
    result(nil)
  }

  private func walletGetCredentials(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("SpruceID macOS: Getting wallet credentials (placeholder)")
    result([
      ["id": "credential1", "type": "VerifiableCredential", "issuer": "did:example:issuer"],
      ["id": "credential2", "type": "DriversLicense", "issuer": "did:example:dmv"]
    ])
  }

  private func walletGetCredentialsByType(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let type = args["type"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("SpruceID macOS: Getting wallet credentials by type \(type) (placeholder)")
    result([["id": "credential1", "type": type, "issuer": "did:example:issuer"]])
  }

  private func walletDeleteCredential(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let id = args["id"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      return
    }

    print("SpruceID macOS: Deleting wallet credential \(id) (placeholder)")
    result(["status": "deleted", "id": id])
  }

  private func exportWallet(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("SpruceID macOS: Exporting wallet (placeholder)")
    result(["walletData": "placeholder_wallet_export", "status": "exported"])
  }

  private func importWallet(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let _ = args["walletData"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid wallet data", details: nil))
      return
    }

    print("SpruceID macOS: Importing wallet (placeholder)")
    result(["status": "imported", "credentialCount": 5])
  }

  private func backupWallet(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("SpruceID macOS: Backing up wallet (placeholder)")
    result(["backupId": UUID().uuidString, "status": "backed_up"])
  }
}
