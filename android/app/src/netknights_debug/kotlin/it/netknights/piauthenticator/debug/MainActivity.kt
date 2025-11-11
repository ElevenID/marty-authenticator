package it.netknights.piauthenticator

import android.util.Log
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import it.netknights.piauthenticator.channels.ChannelRegistry
import it.netknights.piauthenticator.config.SecurityConfig

/**
 * Debug MainActivity for the privacyIDEA Authenticator application.
 *
 * This debug version includes the same functionality as the main MainActivity
 * but with additional debug-specific configurations.
 */
class MainActivity : FlutterFragmentActivity() {

    private lateinit var channelRegistry: ChannelRegistry

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        Log.d("MainActivity", "DEBUG: configureFlutterEngine called")

        // Register generated plugins
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Apply security configurations (including FLAG_SECURE)
        SecurityConfig.applySecuritySettings(this)

        // Set up method channels using the centralized registry
        channelRegistry = ChannelRegistry(this)
        channelRegistry.registerChannels(flutterEngine.dartExecutor.binaryMessenger)

        Log.d("MainActivity", "DEBUG: configureFlutterEngine completed")
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up channels to prevent memory leaks
        if (::channelRegistry.isInitialized) {
            channelRegistry.cleanup()
        }
    }
}
