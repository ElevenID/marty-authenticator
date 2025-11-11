package it.netknights.piauthenticator.config

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * Handles security-related configurations for the application.
 */
object SecurityConfig {

    /**
     * Applies security configurations to prevent screenshots and screen recording.
     * This is important for a privacy/security focused authenticator app.
     *
     * @param activity The activity to apply security settings to
     */
    fun applySecuritySettings(activity: FlutterFragmentActivity) {
        // Prevent screenshots and screen recording
        activity.window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
