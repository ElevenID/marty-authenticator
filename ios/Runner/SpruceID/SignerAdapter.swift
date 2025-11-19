//
//  SignerAdapter.swift
//  SpruceID SDK Integration - iOS Signer Adapter
//

import Foundation
import SpruceIDMobileSdk
import SpruceIDMobileSdkRs

/**
 * iOS adapter that wraps KeyManager for SpruceID SDK signing operations.
 * 
 * Mirrors the Android Signer class to provide consistent interface layer
 * across platforms for Holder and presentation workflows.
 * 
 * Pattern based on SpruceID Showcase App's iOS Signer implementation.
 */
class SignerAdapter {
    private let keyId: String
    private let keyManager: KeyManager
    
    private static let TAG = "SignerAdapter"
    
    /**
     * Initialize signer with KeyManager and key identifier.
     * 
     * @param keyId The key identifier to use for signing operations
     * @param keyManager The KeyManager instance for crypto operations
     */
    init(keyId: String, keyManager: KeyManager) {
        self.keyId = keyId
        self.keyManager = keyManager
        print("\(Self.TAG): Initialized signer with key: \(keyId)")
    }
    
    /**
     * Sign the given payload using the configured key.
     * 
     * @param payload The data to sign
     * @returns The signature data
     * @throws SigningError if signing fails
     */
    func sign(payload: Data) throws -> Data {
        print("\(Self.TAG): Signing \(payload.count) bytes with key: \(keyId)")
        
        guard keyExists() else {
            throw SigningError.keyNotFound("Key \(keyId) not found")
        }
        
        // Use KeyManager's signing functionality
        guard let signature = KeyManager.signPayload(id: keyId, payload: payload) else {
            throw SigningError.signingFailed("KeyManager returned nil signature")
        }
        
        print("\(Self.TAG): Generated signature: \(signature.count) bytes")
        return signature
    }
    
    /**
     * Get the public key JWK for verification.
     * 
     * @returns The public key in JWK format
     * @throws KeyError if key retrieval fails
     */
    func getPublicKeyJwk() throws -> String {
        print("\(Self.TAG): Getting public key JWK for: \(keyId)")
        
        guard let jwk = KeyManager.getJwk(id: keyId) else {
            throw KeyError.jwkRetrievalFailed("Failed to retrieve JWK for key \(keyId)")
        }
        
        print("\(Self.TAG): Retrieved public key JWK")
        return jwk
    }
    
    /**
     * Get the key identifier.
     * 
     * @returns The key ID
     */
    func getKeyId() -> String {
        return keyId
    }
    
    /**
     * Check if the key exists in the KeyManager.
     * 
     * @returns True if the key exists, false otherwise
     */
    func keyExists() -> Bool {
        do {
            let _ = try getPublicKeyJwk()
            return true
        } catch {
            print("\(Self.TAG): Key existence check failed: \(error)")
            return false
        }
    }
    
    /**
     * Generate a new signing key if it doesn't exist.
     * 
     * @returns True if key was generated or already exists, false on failure
     */
    func ensureKeyExists() -> Bool {
        if keyExists() {
            return true
        }
        
        print("\(Self.TAG): Generating new signing key: \(keyId)")
        return KeyManager.generateSigningKey(id: keyId)
    }
    
    /**
     * Get the verification method (DID#key-id) for this signer.
     * Used in presentation proofs to identify which key signed the data.
     * 
     * @param did The holder's DID
     * @returns Full verification method string (e.g., "did:key:z6Mk...#z6Mk...")
     */
    func getVerificationMethod(did: String) -> String {
        return "\(did)#\(keyId)"
    }
}

// MARK: - Error Types

enum SigningError: Error, LocalizedError {
    case keyNotFound(String)
    case signingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .keyNotFound(let message):
            return "Key not found: \(message)"
        case .signingFailed(let message):
            return "Signing failed: \(message)"
        }
    }
}

enum KeyError: Error, LocalizedError {
    case jwkRetrievalFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .jwkRetrievalFailed(let message):
            return "JWK retrieval failed: \(message)"
        }
    }
}
