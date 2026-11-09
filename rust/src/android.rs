//! Android process initialization, called by SkedApplication before Flutter
//! starts the Agent or creates an HTTP client.

use jni::EnvUnowned;
use jni::errors::ThrowRuntimeExAndDefault;
use jni::jni_mangle;
use jni::objects::JObject;

#[allow(non_snake_case)]
#[jni_mangle("com.mashiro.sked.SkedApplication")]
pub fn initializeRustPlatformVerifier<'caller>(
    mut unowned_env: EnvUnowned<'caller>,
    _application: JObject<'caller>,
    context: JObject<'caller>,
) {
    unowned_env
        .with_env(|env| rustls_platform_verifier::android::init_with_env(env, context))
        .resolve::<ThrowRuntimeExAndDefault>();
}
