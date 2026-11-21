package it.netknights.piauthenticator.handlers

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Channel boundary until remote holder and trusted verification services are wired. */
class SpruceIdHandlerRefactored {
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createDid", "signCredential", "handleCredentialOffer",
            "handleOID4VCOffer", "handleOID4VCOfferRefactored",
            "handleVpRequest", "createMdocResponse", "createSdJwt" ->
                result.error(
                    "REMOTE_KMS_REQUIRED",
                    "Holder signing requires a remote KMS-backed key reference",
                    null
                )
            "resolveDid", "verifyCredential", "presentForAgeVerification",
            "verifySdJwt" ->
                result.error(
                    "CRYPTOGRAPHIC_VERIFICATION_REQUIRED",
                    "Verification requires a trusted cryptographic verifier",
                    null
                )
            "initializeMdl", "handleMdlProximityData" ->
                result.error(
                    "SESSION_IMPLEMENTATION_REQUIRED",
                    "mDoc proximity requires a real transport and session state",
                    null
                )
            "storeCredential", "getCredentials", "getCredentialsByType",
            "deleteCredential" ->
                result.error(
                    "WALLET_STORAGE_REQUIRED",
                    "Wallet storage requires a verified persistent repository",
                    null
                )
            "getSupportedMethods", "getSupportedFormats" ->
                result.success(emptyList<String>())
            else -> result.notImplemented()
        }
    }
}
