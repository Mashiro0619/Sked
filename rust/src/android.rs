//! Android process initialization, called by SkedApplication before Flutter
//! starts the Agent or creates an HTTP client.

use std::sync::OnceLock;

use jni::errors::ThrowRuntimeExAndDefault;
use jni::jni_mangle;
use jni::objects::{Global, JObject, JString, JValue};
use jni::{EnvUnowned, JavaVM, jni_sig, jni_str};

struct FileBridge {
    vm: JavaVM,
    object: Global<JObject<'static>>,
}

static FILE_BRIDGE: OnceLock<FileBridge> = OnceLock::new();

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

#[allow(non_snake_case)]
#[jni_mangle("com.mashiro.sked.SkedApplication")]
pub fn initializeRustFileAccessBridge<'caller>(
    mut unowned_env: EnvUnowned<'caller>,
    _application: JObject<'caller>,
    bridge: JObject<'caller>,
) {
    unowned_env
        .with_env(|env| -> jni::errors::Result<()> {
            let vm = env.get_java_vm()?;
            let object = env.new_global_ref(bridge)?;
            let _ = FILE_BRIDGE.set(FileBridge { vm, object });
            Ok(())
        })
        .resolve::<ThrowRuntimeExAndDefault>();
}

pub(crate) fn file_bridge_available() -> bool {
    FILE_BRIDGE.get().is_some()
}

pub(crate) fn file_call(request: &str) -> Result<String, String> {
    let bridge = FILE_BRIDGE
        .get()
        .ok_or_else(|| "The Android file bridge is not initialized.".to_owned())?;
    bridge
        .vm
        .attach_current_thread(|env| -> jni::errors::Result<String> {
            let request = env.new_string(request)?;
            let result = env
                .call_method(
                    &bridge.object,
                    jni_str!("call"),
                    jni_sig!("(Ljava/lang/String;)Ljava/lang/String;"),
                    &[JValue::Object(request.as_ref())],
                )?
                .l()?;
            let result = env.cast_local::<JString>(result)?;
            result.try_to_string(env)
        })
        .map_err(|error| error.to_string())
}

pub(crate) fn cancel_file_call(call_id: &str) -> Result<(), String> {
    let bridge = FILE_BRIDGE
        .get()
        .ok_or_else(|| "The Android file bridge is not initialized.".to_owned())?;
    bridge
        .vm
        .attach_current_thread(|env| -> jni::errors::Result<()> {
            let call_id = env.new_string(call_id)?;
            env.call_method(
                &bridge.object,
                jni_str!("cancel"),
                jni_sig!("(Ljava/lang/String;)V"),
                &[JValue::Object(call_id.as_ref())],
            )?;
            Ok(())
        })
        .map_err(|error| error.to_string())
}
