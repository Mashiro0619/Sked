use std::{collections::BTreeMap, fs::File, io::Read};

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tokio_util::sync::CancellationToken;

use super::{bridge, error, io_error};
use crate::execution::{
    ExecutionEnvironment, ExecutionErrorCode, ExecutionProviderIdentity, Result, office,
};

#[derive(Clone, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct RuntimeInfo {
    pub python_version: String,
    pub chaquopy_version: String,
    pub selected_abi: String,
    pub os_arch: String,
    pub is64_bit: bool,
    pub package_name: String,
    pub version_code: i64,
    pub last_update_time: i64,
    pub apk_paths: Vec<String>,
    pub native_library_dir: String,
    pub files_dir: String,
    pub cache_dir: String,
}

pub(super) struct Runtime {
    pub info: RuntimeInfo,
    pub environment: ExecutionEnvironment,
    pub variables: BTreeMap<String, String>,
    _apks: Vec<File>,
}

pub(super) fn info() -> Result<RuntimeInfo> {
    bridge::decode(
        &crate::android::python_runtime_info()
            .map_err(|failure| error(ExecutionErrorCode::ProviderUnavailable, failure))?,
    )
}

impl Runtime {
    pub fn capture(
        provider: ExecutionProviderIdentity,
        cancellation: &CancellationToken,
    ) -> Result<Self> {
        let info = info()?;
        let expected_abi = match std::env::consts::ARCH {
            "aarch64" => "arm64-v8a",
            "arm" => "armeabi-v7a",
            "x86_64" => "x86_64",
            _ => {
                return Err(error(
                    ExecutionErrorCode::Unsupported,
                    "The Android Python runtime does not support this process architecture.",
                ));
            }
        };
        if info.selected_abi != expected_abi
            || info.python_version != "3.11.17"
            || info.chaquopy_version != "17.2.0"
        {
            return Err(error(
                ExecutionErrorCode::ProviderUnavailable,
                "The Android Python runtime does not match this application build.",
            ));
        }
        let mut apks = Vec::new();
        let mut digests = Vec::new();
        for path in &info.apk_paths {
            check_cancelled(cancellation)?;
            let mut apk = File::open(path).map_err(io_error)?;
            let mut hash = Sha256::new();
            let mut buffer = [0_u8; 64 * 1024];
            loop {
                check_cancelled(cancellation)?;
                let count = apk.read(&mut buffer).map_err(io_error)?;
                if count == 0 {
                    break;
                }
                hash.update(&buffer[..count]);
            }
            digests.push(format!("{:x}", hash.finalize()));
            apks.push(apk);
        }
        let mut variables = std::env::vars_os()
            .map(|(name, value)| {
                Ok((
                    name.into_string().map_err(|_| {
                        error(
                            ExecutionErrorCode::InvalidSpec,
                            "An environment name is not valid Unicode.",
                        )
                    })?,
                    value.into_string().map_err(|_| {
                        error(
                            ExecutionErrorCode::InvalidSpec,
                            "An environment value is not valid Unicode.",
                        )
                    })?,
                ))
            })
            .collect::<Result<BTreeMap<String, String>>>()?;
        variables
            .entry("HOME".into())
            .or_insert_with(|| info.files_dir.clone());
        variables.insert("TMPDIR".into(), format!("{}/chaquopy/tmp", info.cache_dir));
        variables.insert(
            "PYTHONPATH".into(),
            format!(
                "{0}/chaquopy/stdlib-common.imy:{0}/chaquopy/bootstrap.imy:{0}/chaquopy/bootstrap-native/{1}",
                info.files_dir, info.selected_abi
            ),
        );
        variables.insert("CHAQUOPY_PROCESS_TYPE".into(), "java".into());
        let material = serde_json::to_vec(&("sked.android-python/1", &info, &digests, &variables))
            .map_err(|failure| error(ExecutionErrorCode::InvalidSpec, failure.to_string()))?;
        let mut dependencies = office::bundled_dependencies().clone();
        dependencies.insert("chaquopy".into(), info.chaquopy_version.clone());
        let environment = ExecutionEnvironment {
            provider,
            platform: "android".into(),
            architecture: std::env::consts::ARCH.into(),
            interpreter: "CPython".into(),
            interpreter_version: info.python_version.clone(),
            dependencies,
            environment_digest: format!("{:x}", Sha256::digest(material)),
        };
        Ok(Self {
            info,
            environment,
            variables,
            _apks: apks,
        })
    }
}

pub(super) fn check_cancelled(cancellation: &CancellationToken) -> Result<()> {
    if cancellation.is_cancelled() {
        Err(error(
            ExecutionErrorCode::CancelledBeforeStart,
            "The execution was cancelled before starting.",
        ))
    } else {
        Ok(())
    }
}
