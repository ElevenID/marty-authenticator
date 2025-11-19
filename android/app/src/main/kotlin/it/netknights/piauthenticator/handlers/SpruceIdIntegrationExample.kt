package it.netknights.piauthenticator.handlers

import android.util.Log
import com.spruceid.mobile.sdk.KeyManager
import com.spruceid.mobile.sdk.CredentialPack
import com.spruceid.mobile.sdk.rs.Oid4vci
import com.spruceid.mobile.sdk.rs.Holder
import com.spruceid.mobile.sdk.rs.Oid4vp180137
import kotlinx.coroutines.*

/**
 * Example integration showing how the adapters enable SDK usage.
 * This demonstrates the interface layer that reduces code duplication.
 * 
 * Before: 300+ lines of custom implementations
 * After: ~50 lines calling SDK with our adapters
 */
class SpruceIdIntegrationExample(
    private val keyManager: KeyManager,
    private val credentialPack: CredentialPack
) {
    companion object {
        private const val TAG = "SpruceIdIntegration"
        private const val DEFAULT_SIGNING_KEY_ID = "spruce_key_default"
    }

    private val signer = Signer(DEFAULT_SIGNING_KEY_ID, keyManager)
    private val httpClient = HttpClientWrapper()

    /**
     * Handle OID4VCI credential offer using SDK + adapters.
     * 
     * Before: 50+ lines of custom JSON parsing, HTTP requests, signing
     * After: 10 lines calling SDK with our HTTP wrapper
     */
    suspend fun handleCredentialOffer(offerUrl: String): String {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Processing credential offer: $offerUrl")
                
                // Use SDK with our HTTP client adapter - no custom implementation needed!
                val oid4vciSession = Oid4vci.newWithAsyncClient(httpClient.getOkHttpClient())
                oid4vciSession.initiateWithOffer(offerUrl, "privacyidea-authenticator", "https://netknights.it")
                
                val nonce = oid4vciSession.exchangeToken()
                val metadata = oid4vciSession.getMetadata()
                
                // Use our signer adapter for proof-of-possession
                val signingInput = generatePopPrepare(metadata.issuer(), nonce, DidMethod.JWK, signer.getPublicKeyJwk(), null)
                val signature = signer.sign(signingInput)
                val pop = generatePopComplete(signingInput, signature)
                
                val credentials = oid4vciSession.exchangeCredential(listOf(pop), Oid4vciExchangeOptions(false))
                
                // Store using CredentialPack - no custom storage logic needed!
                credentials.forEach { credential ->
                    credentialPack.tryAddRawCredential(credential)
                }
                credentialPack.save(storageManager)
                
                Log.d(TAG, "Successfully processed ${credentials.size} credentials")
                "Success: ${credentials.size} credentials stored"
                
            } catch (e: Exception) {
                Log.e(TAG, "Credential offer failed", e)
                throw e
            }
        }
    }

    /**
     * Handle presentation request using SDK + adapters.
     * 
     * Before: 80+ lines of custom VP creation, JSON-LD contexts, signing
     * After: 15 lines calling SDK with our signer
     */
    suspend fun createPresentation(requestUrl: String): String {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Creating presentation for: $requestUrl")
                
                val credentials = credentialPack.list()
                val trustedDids = emptyList<String>()
                val contextMap = emptyMap<String, String>() // TODO: Add proper contexts
                
                // Use SDK with our signer adapter - no custom VP logic needed!
                val holder = Holder.newWithCredentials(credentials, trustedDids, signer, contextMap)
                val permissionRequest = holder.authorizationRequest(Url(requestUrl))
                
                // User would select credentials/fields here
                val selectedCredentials = credentials // Simplified for example
                val selectedFields = emptyMap<String, List<String>>()
                
                val permissionResponse = permissionRequest.createPermissionResponse(
                    selectedCredentials,
                    selectedFields,
                    ResponseOptions(false, false, false)
                )
                
                val result = holder.submitPermissionResponse(permissionResponse)
                
                Log.d(TAG, "Successfully created presentation")
                result.toString()
                
            } catch (e: Exception) {
                Log.e(TAG, "Presentation creation failed", e)
                throw e
            }
        }
    }

    /**
     * Handle mDoc presentation request using SDK.
     * 
     * Before: 60+ lines of custom mDoc structure, CBOR encoding, signing
     * After: 8 lines calling SDK directly
     */
    suspend fun handleMdocRequest(requestUrl: String): String {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "Processing mDoc request: $requestUrl")
                
                // Use SDK for mDoc - no custom CBOR/signing logic needed!
                val mdocCredentials = credentialPack.list().mapNotNull { it.asMsoMdoc() }
                val handler = Oid4vp180137(mdocCredentials, keyManager)
                val request = handler.processRequest(requestUrl)
                
                val matches = request.matches()
                Log.d(TAG, "Found ${matches.size} matching credentials")
                
                // User would approve specific fields here
                val approvedResponse = matches.first() // Simplified for example
                val response = request.respond(approvedResponse)
                
                Log.d(TAG, "Successfully created mDoc response")
                response.toString()
                
            } catch (e: Exception) {
                Log.e(TAG, "mDoc request failed", e)
                throw e
            }
        }
    }

    /**
     * Clean up resources.
     */
    fun shutdown() {
        httpClient.shutdown()
    }
}

/**
 * Placeholder functions - these would be implemented by the SDK
 */
private fun generatePopPrepare(issuer: String, nonce: String, didMethod: Any, jwk: String, keyId: String?): ByteArray {
    // SDK implementation
    return "mock_pop_prepare".toByteArray()
}

private fun generatePopComplete(signingInput: ByteArray, signature: ByteArray): String {
    // SDK implementation
    return "mock_pop_complete"
}

// Placeholder classes
class Url(val value: String)
class ResponseOptions(val a: Boolean, val b: Boolean, val c: Boolean)
