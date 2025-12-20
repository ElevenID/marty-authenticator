package it.netknights.piauthenticator.channels

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import it.netknights.piauthenticator.handlers.FileHandler
import it.netknights.piauthenticator.handlers.SpruceIdHandlerRefactored

/**
 * Manages all method channels for the Flutter application.
 * This centralizes channel registration and provides a clean separation of concerns.
 */
class ChannelRegistry(private val context: Context) {

    // Channel names as constants
    companion object {
        private const val TAG = "ChannelRegistry"
        private const val FILE_CHANNEL = "readValueFromFile"
        private const val PKI_CHANNEL = "com.netknights.authenticator/spruce_pki"
        private const val JWT_CHANNEL = "com.netknights.authenticator/spruce_jwt"
        private const val MDOC_CHANNEL = "com.netknights.authenticator/spruce_mdoc"
        private const val WALLET_CHANNEL = "com.netknights.authenticator/spruce_wallet"
        private const val W3C_CHANNEL = "com.netknights.authenticator/spruce_w3c"
    }

    // Handlers
    private val fileHandler = FileHandler(context)
    private val spruceIdHandler = SpruceIdHandlerRefactored(context)

    // Channels
    private var fileChannel: MethodChannel? = null
    private var pkiChannel: MethodChannel? = null
    private var jwtChannel: MethodChannel? = null
    private var mdocChannel: MethodChannel? = null
    private var walletChannel: MethodChannel? = null
    private var w3cChannel: MethodChannel? = null

    /**
     * Registers all method channels with the Flutter engine.
     *
     * @param binaryMessenger The binary messenger from Flutter engine
     */
    fun registerChannels(binaryMessenger: BinaryMessenger) {
        Log.d(TAG, "Registering all method channels")

        // Initialize SpruceID handler
        val initialized = spruceIdHandler.initialize()
        if (!initialized) {
            Log.w(TAG, "SpruceID handler initialization failed - channels will return errors")
        }

        setupFileChannel(binaryMessenger)
        setupPkiChannel(binaryMessenger)
        setupJwtChannel(binaryMessenger)
        setupMdocChannel(binaryMessenger)
        setupWalletChannel(binaryMessenger)
        setupW3cChannel(binaryMessenger)

        Log.d(TAG, "All method channels registered successfully")
    }

    /**
     * Sets up the file operations method channel.
     */
    private fun setupFileChannel(binaryMessenger: BinaryMessenger) {
        fileChannel = MethodChannel(binaryMessenger, FILE_CHANNEL)
        fileChannel?.setMethodCallHandler { call, result ->
            fileHandler.handleCall(call, result)
        }
    }

    /**
     * Sets up the PKI operations method channel.
     */
    private fun setupPkiChannel(binaryMessenger: BinaryMessenger) {
        Log.d(TAG, "Setting up PKI channel: $PKI_CHANNEL")
        pkiChannel = MethodChannel(binaryMessenger, PKI_CHANNEL)
        pkiChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "PKI channel received method call: ${call.method}")
            spruceIdHandler.handleMethodCall(call, result)
        }
    }

    /**
     * Sets up the JWT operations method channel.
     */
    private fun setupJwtChannel(binaryMessenger: BinaryMessenger) {
        Log.d(TAG, "Setting up JWT channel: $JWT_CHANNEL")
        jwtChannel = MethodChannel(binaryMessenger, JWT_CHANNEL)
        jwtChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "JWT channel received method call: ${call.method}")
            spruceIdHandler.handleMethodCall(call, result)
        }
    }

    /**
     * Sets up the mDoc operations method channel.
     */
    private fun setupMdocChannel(binaryMessenger: BinaryMessenger) {
        Log.d(TAG, "Setting up mDoc channel: $MDOC_CHANNEL")
        mdocChannel = MethodChannel(binaryMessenger, MDOC_CHANNEL)
        mdocChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "mDoc channel received method call: ${call.method}")
            spruceIdHandler.handleMethodCall(call, result)
        }
    }

    /**
     * Sets up the Wallet operations method channel.
     */
    private fun setupWalletChannel(binaryMessenger: BinaryMessenger) {
        Log.d(TAG, "Setting up Wallet channel: $WALLET_CHANNEL")
        walletChannel = MethodChannel(binaryMessenger, WALLET_CHANNEL)
        walletChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "Wallet channel received method call: ${call.method}")
            spruceIdHandler.handleMethodCall(call, result)
        }
    }

    /**
     * Sets up the W3C operations method channel.
     */
    private fun setupW3cChannel(binaryMessenger: BinaryMessenger) {
        Log.d(TAG, "Setting up W3C channel: $W3C_CHANNEL")
        w3cChannel = MethodChannel(binaryMessenger, W3C_CHANNEL)
        w3cChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "W3C channel received method call: ${call.method}")
            spruceIdHandler.handleMethodCall(call, result)
        }
    }

    /**
     * Cleans up all channels. Should be called when the activity is destroyed.
     */
    fun cleanup() {
        fileChannel?.setMethodCallHandler(null)
        fileChannel = null

        pkiChannel?.setMethodCallHandler(null)
        pkiChannel = null

        jwtChannel?.setMethodCallHandler(null)
        jwtChannel = null

        mdocChannel?.setMethodCallHandler(null)
        mdocChannel = null

        walletChannel?.setMethodCallHandler(null)
        walletChannel = null

        w3cChannel?.setMethodCallHandler(null)
        w3cChannel = null
    }
}
