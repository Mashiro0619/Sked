use std::{
    collections::BTreeMap,
    fs::{File, OpenOptions},
    io::Read,
    os::windows::fs::OpenOptionsExt,
    path::{Component, Path, PathBuf},
};

use serde::Deserialize;
use sha2::{Digest, Sha256};
use tokio_util::sync::CancellationToken;
use windows_sys::Win32::Storage::FileSystem::{
    FILE_FLAG_BACKUP_SEMANTICS, FILE_READ_ATTRIBUTES, FILE_SHARE_READ, FILE_SHARE_WRITE,
};

use super::{error, io_error};
use crate::execution::{
    ExecutionEnvironment, ExecutionErrorCode, ExecutionProviderIdentity, Result,
    environment_names_equal, office,
};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Manifest {
    schema: u32,
    version: String,
    architecture: String,
    archive_digest: String,
    dependencies: BTreeMap<String, String>,
    files: BTreeMap<String, String>,
}

pub(super) fn office_available(directory: &Path) -> bool {
    std::fs::read(directory.join("manifest.json"))
        .ok()
        .and_then(|bytes| serde_json::from_slice::<Manifest>(&bytes).ok())
        .is_some_and(|manifest| {
            manifest.dependencies == *office::bundled_dependencies()
                && manifest.files.contains_key("office_inspect.py")
        })
}

pub(super) struct RuntimeBundle {
    pub directory: PathBuf,
    pub environment: ExecutionEnvironment,
    pub system_variables: BTreeMap<String, String>,
    // Read handles prevent replacing any approved interpreter or library.
    _files: Vec<File>,
    _directory: File,
}

impl RuntimeBundle {
    pub fn open(
        directory: PathBuf,
        provider: ExecutionProviderIdentity,
        cancellation: &CancellationToken,
    ) -> Result<Self> {
        let directory_handle = lock_directory(&directory)?;
        let mut manifest_file = locked_file(&directory.join("manifest.json"))?;
        let mut manifest_bytes = Vec::new();
        manifest_file
            .read_to_end(&mut manifest_bytes)
            .map_err(io_error)?;
        let manifest: Manifest = serde_json::from_slice(&manifest_bytes).map_err(|failure| {
            error(ExecutionErrorCode::ProviderUnavailable, failure.to_string())
        })?;
        if manifest.schema != 1
            || manifest.architecture != std::env::consts::ARCH
            || manifest.version != "3.11.9"
        {
            return Err(error(
                ExecutionErrorCode::ProviderUnavailable,
                "The bundled Python runtime does not match this application build.",
            ));
        }
        for required in [
            "python.exe",
            "python311.dll",
            "python311.zip",
            "python311._pth",
            "bootstrap.py",
            "sked_runtime.py",
        ] {
            if !manifest.files.contains_key(required) {
                return Err(error(
                    ExecutionErrorCode::ProviderUnavailable,
                    format!("The Python bundle is missing {required}."),
                ));
            }
        }
        let mut files = vec![manifest_file];
        for (relative, expected) in &manifest.files {
            check_cancelled(cancellation)?;
            let relative = Path::new(relative);
            if relative
                .components()
                .any(|part| !matches!(part, Component::Normal(_)))
            {
                return Err(error(
                    ExecutionErrorCode::ProviderUnavailable,
                    "The Python manifest contains a path outside its bundle.",
                ));
            }
            let mut file = locked_file(&directory.join(relative))?;
            let mut hash = Sha256::new();
            let mut buffer = [0_u8; 64 * 1024];
            loop {
                check_cancelled(cancellation)?;
                let read = file.read(&mut buffer).map_err(io_error)?;
                if read == 0 {
                    break;
                }
                hash.update(&buffer[..read]);
            }
            if format!("{:x}", hash.finalize()) != *expected {
                return Err(error(
                    ExecutionErrorCode::StaleSpec,
                    format!(
                        "The bundled Python file {} has changed.",
                        relative.display()
                    ),
                ));
            }
            files.push(file);
        }
        let mut system_variables = std::env::vars_os()
            .map(|(name, value)| {
                Ok((
                    name.into_string().map_err(|_| {
                        error(
                            ExecutionErrorCode::InvalidSpec,
                            "An environment name cannot be represented as Unicode.",
                        )
                    })?,
                    value.into_string().map_err(|_| {
                        error(
                            ExecutionErrorCode::InvalidSpec,
                            "An environment value cannot be represented as Unicode.",
                        )
                    })?,
                ))
            })
            .collect::<Result<BTreeMap<String, String>>>()?;
        let path_key = system_variables
            .keys()
            .find(|name| environment_names_equal(name, "PATH"))
            .cloned()
            .unwrap_or_else(|| "PATH".into());
        let inherited_path = system_variables.remove(&path_key).unwrap_or_default();
        system_variables.insert(
            path_key,
            format!("{};{inherited_path}", directory.display()),
        );
        let digest_material = serde_json::to_vec(&(
            "sked.windows-python/1",
            &manifest_bytes,
            &manifest.archive_digest,
            &system_variables,
        ))
        .map_err(|failure| error(ExecutionErrorCode::InvalidSpec, failure.to_string()))?;
        let environment = ExecutionEnvironment {
            provider,
            platform: "windows".into(),
            architecture: manifest.architecture,
            interpreter: "CPython".into(),
            interpreter_version: manifest.version,
            dependencies: manifest.dependencies,
            environment_digest: format!("{:x}", Sha256::digest(&digest_material)),
        };
        Ok(Self {
            directory,
            environment,
            system_variables,
            _files: files,
            _directory: directory_handle,
        })
    }
}

pub(super) fn lock_directory(path: &Path) -> Result<File> {
    let file = OpenOptions::new()
        .access_mode(FILE_READ_ATTRIBUTES)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS)
        .open(path)
        .map_err(io_error)?;
    if !file.metadata().map_err(io_error)?.is_dir() {
        return Err(error(
            ExecutionErrorCode::InvalidSpec,
            "The execution working directory is not a directory.",
        ));
    }
    Ok(file)
}

fn locked_file(path: &Path) -> Result<File> {
    OpenOptions::new()
        .read(true)
        .share_mode(FILE_SHARE_READ)
        .open(path)
        .map_err(io_error)
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
