package it.netknights.piauthenticator.handlers

import android.util.Log
import com.spruceid.mobile.sdk.KeyManager

/**
 * Custom signer implementation for SpruceID SDK operations.
 * 
 * This class provides signing functionality for Holder and presentation workflows,
 * following the pattern from the SpruceID Showcase App.
 * 
 * Used by Holder.newWithCredentials() and other SDK methods that require signing.
 */
class Signer(
    private val keyId: String,
    private val keyManager: KeyManager
) {
    companion object {
        private const val TAG = "Signer"
    }

    /**
     * Sign the given payload using the configured key.
     * 
     * @param payload The data to sign
     * @return The signature bytes
     */
    fun sign(payload: ByteArray): ByteArray {
        return try {
            Log.d(TAG, "Signing ${payload.size} bytes with key: $keyId")
            
            // Use KeyManager's signing functionality
            val signature = keyManager.signPayload(keyId, payload)
                ?: throw IllegalStateException("KeyManager returned null signature")
            
            Log.d(TAG, "Generated signature: ${signature.size} bytes")
            signature
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sign payload", e)
            throw RuntimeException("Signing failed: ${e.message}", e)
        }
    }

    /**
     * Get the public key JWK for verification.
     * 
     * @return The public key in JWK format
     */
    fun getPublicKeyJwk(): String {
        return try {
            Log.d(TAG, "Getting public key JWK for: $keyId")
            
            // Get signing key from KeyManager
            val signingKey = keyManager.getSigningKey(keyId)
            
            // Extract JWK representation
            val jwk = signingKey.jwk()
            
            Log.d(TAG, "Retrieved public key JWK")
            jwk
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get public key", e)
            throw RuntimeException("Failed to retrieve public key: ${e.message}", e)
        }
    }

    /**
     * Get the key identifier.
     * 
     * @return The key ID
     */
    fun getKeyId(): String = keyId

    /**
     * Check if the key exists in the KeyManager.
     * 
     * @return True if the key exists, false otherwise
     */
    fun keyExists(): Boolean {
        return try {
            keyManager.keyExists(keyId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check key existence", e)
            false
        }
    }
}
