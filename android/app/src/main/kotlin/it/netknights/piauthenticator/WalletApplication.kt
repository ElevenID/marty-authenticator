package it.netknights.piauthenticator

import android.app.Application
import androidx.annotation.Keep

@Keep
class WalletApplication : Application() {
    private external fun initializePlatformVerifier()

    override fun onCreate() {
        super.onCreate()
        System.loadLibrary("marty_authenticator_bridge")
        initializePlatformVerifier()
    }
}
