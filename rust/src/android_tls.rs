use jni::{errors::ThrowRuntimeExAndDefault, objects::JObject, EnvUnowned};

/// Initialize the system trust verifier on the application thread, where its
/// class loader can resolve the Kotlin component packaged in the APK.
#[no_mangle]
pub extern "system" fn Java_it_netknights_piauthenticator_WalletApplication_initializePlatformVerifier(
    mut env: EnvUnowned,
    application: JObject,
) {
    env.with_env(|env| rustls_platform_verifier::android::init_with_env(env, application))
        .resolve::<ThrowRuntimeExAndDefault>();
}
