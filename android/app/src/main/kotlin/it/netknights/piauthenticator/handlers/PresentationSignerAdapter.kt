package it.netknights.piauthenticator.handlers

import com.spruceid.mobile.sdk.KeyManager
import com.spruceid.mobile.sdk.rs.DidMethod
import com.spruceid.mobile.sdk.rs.DidMethodUtils
import com.spruceid.mobile.sdk.rs.PresentationSigner
import org.json.JSONObject

/** Presentation signer compatible with SpruceKit Mobile 0.12.11. */
class Signer(
    private val keyId: String,
    private val keyManager: KeyManager
) : PresentationSigner {
    private val didJwk = DidMethodUtils(DidMethod.JWK)
    private val publicJwk: String = keyManager.getJwk(keyId)
        ?: throw IllegalArgumentException("No public JWK for key '$keyId'")

    override suspend fun sign(payload: ByteArray): ByteArray =
        keyManager.signPayload(keyId, payload)
            ?: throw IllegalStateException("Failed to sign payload with key '$keyId'")

    override fun algorithm(): String =
        runCatching { JSONObject(publicJwk).getString("alg") }.getOrDefault("ES256")

    override suspend fun verificationMethod(): String = didJwk.vmFromJwk(publicJwk)

    override fun did(): String = didJwk.didFromJwk(publicJwk)

    override fun jwk(): String = publicJwk

    override fun cryptosuite(): String = "ecdsa-rdfc-2019"

    fun getPublicKeyJwk(): String = publicJwk
}
