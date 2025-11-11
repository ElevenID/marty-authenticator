package it.netknights.piauthenticator

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import it.netknights.piauthenticator.channels.ChannelRegistry
import it.netknights.piauthenticator.config.SecurityConfig

/**
 * Main activity for the privacyIDEA Authenticator application (NetKnights flavor).
 *
 * This activity serves as the entry point for the Flutter application
 * and handles the initial configuration of Flutter engine, security settings,
 * and method channel registrations.
 */
class MainActivity : FlutterFragmentActivity() {

    private var channelRegistry: ChannelRegistry? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        // Register generated plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Apply security configurations
        SecurityConfig.applySecuritySettings(this)

        // Set up method channels
        channelRegistry = ChannelRegistry(this)
        channelRegistry?.registerChannels(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up channels to prevent memory leaks
        channelRegistry?.cleanup()
        channelRegistry = null
    }
}
