mod ledger;
mod process;
mod runtime;

use std::{
    collections::HashSet,
    fs::{self, File},
    path::{Path, PathBuf},
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};

use async_trait::async_trait;
use futures::future::BoxFuture;
use serde::Deserialize;
use serde_json::json;
use tokio_util::sync::CancellationToken;

use super::{
    EXECUTION_SERVICE, EffectsState, EnvironmentValue, ExecutionCapabilities, ExecutionError,
    ExecutionErrorCode, ExecutionIdentity, ExecutionPreparation, ExecutionProvider,
    ExecutionProviderIdentity, ExecutionReceipt, ExecutionService, ExecutionSpec,
    ExecutionStartRequest, ExecutionTerminal, FrozenExecutionKind, FrozenExecutionSpec,
    OutputReference, OutputStream, PreparedExecutionBackend, ResourceVersion, Result,
};
use crate::{
    files::{
        FILES_SERVICE, FileKind, FileResourceKind, FileResourceRef, FileService, FileVersion,
        SnapshotReadLease,
    },
    plugins::{Plugin, PluginContext, PluginDescriptor, PluginError},
};

pub struct WindowsExecutionPlugin {
    pub root: PathBuf,
}

#[async_trait]
impl Plugin for WindowsExecutionPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.windows.execution",
            contract_version: 1,
            provides: vec![EXECUTION_SERVICE.key()],
            dependencies: vec![FILES_SERVICE.key()],
        }
    }

    async fn setup(&self, context: PluginContext) -> std::result::Result<(), PluginError> {
        let executable =
            std::env::current_exe().map_err(|failure| PluginError::new(failure.to_string()))?;
        let directory = executable
            .parent()
            .ok_or_else(|| PluginError::new("The application directory is unavailable."))?
            .join("data")
            .join("python");
        let provider = WindowsProvider {
            inner: Arc::new(Provider {
                identity: ExecutionProviderIdentity {
                    provider_id: "sked.windows.python".into(),
                    instance_id: context.instance_id().into(),
                    generation: context.generation(),
                    contract_version: 1,
                },
                files: (*context.require(FILES_SERVICE)?).clone(),
                root: self.root.clone(),
                directory,
            }),
        };
        let service = ExecutionService::new(Arc::new(provider));
        let closing = service.clone();
        context.on_quiesce(move || {
            Box::pin(async move {
                closing.shutdown().await;
                Ok(())
            })
        })?;
        context.provide(EXECUTION_SERVICE, service)
    }
}

struct Provider {
    identity: ExecutionProviderIdentity,
    files: FileService,
    root: PathBuf,
    directory: PathBuf,
}

#[derive(Clone)]
struct WindowsProvider {
    inner: Arc<Provider>,
}

impl ExecutionProvider for WindowsProvider {
    fn identity(&self) -> ExecutionProviderIdentity {
        self.inner.identity.clone()
    }

    fn capabilities(&self) -> ExecutionCapabilities {
        ExecutionCapabilities {
            python: self.inner.directory.join("manifest.json").is_file(),
            controlled_readers: Vec::new(),
        }
    }

    fn prepare(
        &self,
        specification: ExecutionSpec,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<ExecutionPreparation>> {
        let provider = self.inner.clone();
        Box::pin(async move {
            let ExecutionSpec::Python(input) = specification else {
                return Err(error(
                    ExecutionErrorCode::UnknownReader,
                    "This provider has no controlled document reader.",
                ));
            };
            if input.cwd_resource.kind != FileResourceKind::WindowsPath {
                return Err(error(
                    ExecutionErrorCode::InvalidSpec,
                    "Windows Python requires a Windows working-directory path.",
                ));
            }
            if input
                .environment
                .values()
                .any(|value| matches!(value, EnvironmentValue::SecretHandle { .. }))
            {
                return Err(error(
                    ExecutionErrorCode::Unsupported,
                    "This Python provider does not resolve secret handles.",
                ));
            }
            let bundle_path = provider.directory.clone();
            if input
                .environment
                .keys()
                .any(|name| name.eq_ignore_ascii_case("_SKED_EXECUTION_DIR"))
            {
                return Err(error(
                    ExecutionErrorCode::InvalidSpec,
                    "_SKED_EXECUTION_DIR is set by the execution runtime.",
                ));
            }
            let mut variable_names = HashSet::new();
            if input
                .environment
                .keys()
                .any(|name| !variable_names.insert(name.to_ascii_uppercase()))
            {
                return Err(error(
                    ExecutionErrorCode::InvalidSpec,
                    "Windows environment variable names are case-insensitive; each name must occur once.",
                ));
            }
            let identity = provider.identity.clone();
            let preparing = cancellation.clone();
            let cwd_path = input.cwd_resource.value.clone();
            let (bundle, cwd) = tokio::task::spawn_blocking(move || {
                let bundle = runtime::RuntimeBundle::open(bundle_path, identity, &preparing)?;
                let cwd = runtime::lock_directory(Path::new(&cwd_path))?;
                Ok::<_, ExecutionError>((bundle, cwd))
            })
            .await
            .map_err(join_error)??;
            check_cwd(
                &provider.files,
                &input.cwd_resource,
                &input.cwd,
                cancellation.clone(),
            )
            .await?;
            let mut inputs = Vec::new();
            for input in &input.inputs {
                let lease = provider
                    .files
                    .lease_snapshot(input.snapshot.resource_id.clone(), cancellation.clone())
                    .await
                    .map_err(file_error)?;
                let metadata = lease.metadata();
                let version = &metadata.content_version;
                if metadata.content.kind != FileResourceKind::WindowsPath
                    || metadata.content.value != input.mounted_path
                    || version.version != input.snapshot.version
                    || version.sha256 != input.snapshot.digest
                    || version.byte_length != input.snapshot.byte_length
                {
                    return Err(error(
                        ExecutionErrorCode::StaleSpec,
                        "The mounted input no longer matches its frozen file snapshot.",
                    ));
                }
                inputs.push(lease);
            }
            runtime::check_cancelled(&cancellation)?;
            let specification = FrozenExecutionSpec {
                kind: FrozenExecutionKind::Python {
                    code: input.code,
                    code_digest: String::new(),
                },
                argv: input.argv,
                cwd: input.cwd,
                cwd_resource: input.cwd_resource,
                environment: bundle.environment.clone(),
                variables: input.environment,
                inputs: input.inputs,
                spec_digest: String::new(),
            };
            let backend = Backend {
                resources: Arc::new(PreparedResources {
                    provider,
                    bundle,
                    _cwd: cwd,
                    _inputs: inputs,
                }),
            };
            Ok(ExecutionPreparation {
                specification,
                backend: Arc::new(backend),
            })
        })
    }

    fn inspect(
        &self,
        identity: ExecutionIdentity,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<ExecutionReceipt>> {
        let provider = self.inner.clone();
        Box::pin(async move {
            let reading = provider.clone();
            let original = identity.clone();
            let mut receipt = tokio::task::spawn_blocking(move || {
                runtime::check_cancelled(&cancellation)?;
                ledger::inspect(&reading.root, &original)
            })
            .await
            .map_err(join_error)??;
            if receipt.terminal.is_none() {
                receipt.terminal = Some(ExecutionTerminal::Lost);
                receipt.finished_at_ms = Some(now_ms());
                receipt.effects.state = EffectsState::Unknown;
                receipt.error = Some(error(
                    ExecutionErrorCode::OutcomeUnknown,
                    "The previous execution has no final record. Its saved output can be read; the script was not run again.",
                ));
                let directory = ledger::directory(&provider.root, &identity)?;
                recover_outputs(&provider.files, &directory, &mut receipt).await;
            }
            Ok(receipt)
        })
    }
}

struct PreparedResources {
    provider: Arc<Provider>,
    bundle: runtime::RuntimeBundle,
    _cwd: File,
    _inputs: Vec<SnapshotReadLease>,
}

struct Backend {
    resources: Arc<PreparedResources>,
}

impl PreparedExecutionBackend for Backend {
    fn start(&self, request: ExecutionStartRequest) -> BoxFuture<'static, ExecutionReceipt> {
        let resources = self.resources.clone();
        Box::pin(async move {
            let provider = &resources.provider;
            let mut receipt = ledger::pending(&request.identity);
            let prepared = prepare_run(&resources, &request).await;
            let (directory, _material) = match prepared {
                Ok(prepared) => prepared,
                Err(failure) => {
                    receipt.terminal = Some(ExecutionTerminal::NotStarted);
                    receipt.effects.state = EffectsState::NotStarted;
                    receipt.finished_at_ms = Some(now_ms());
                    receipt.error = Some(failure);
                    if let Ok(directory) = ledger::directory(&provider.root, &request.identity) {
                        if directory.is_dir() {
                            let _ = ledger::append(&directory, &receipt);
                        }
                    }
                    return receipt;
                }
            };
            if let Err(failure) = ledger::append(&directory, &receipt) {
                receipt.terminal = Some(ExecutionTerminal::NotStarted);
                receipt.effects.state = EffectsState::NotStarted;
                receipt.finished_at_ms = Some(now_ms());
                receipt.error = Some(failure);
                return receipt;
            }
            let completed = process::run(
                &resources.bundle,
                &request.specification,
                &directory,
                &mut receipt,
                request.cancellation,
                request.events,
            )
            .await;
            receipt.exit_code = completed.exit_code;
            receipt.error = completed.error;
            receipt.terminal = Some(if !completed.started {
                ExecutionTerminal::NotStarted
            } else if receipt
                .error
                .as_ref()
                .is_some_and(|failure| failure.code == ExecutionErrorCode::OutcomeUnknown)
            {
                ExecutionTerminal::Lost
            } else if completed.cancelled {
                ExecutionTerminal::Cancelled
            } else {
                ExecutionTerminal::Exited
            });
            receipt.effects.state = match receipt.terminal {
                Some(ExecutionTerminal::NotStarted) => EffectsState::NotStarted,
                Some(ExecutionTerminal::Lost) => EffectsState::Unknown,
                _ => EffectsState::Observed,
            };
            for output in completed.outputs {
                let file = path_resource(&output.path);
                match observe(&provider.files, file.clone()).await {
                    Ok(version) => receipt.outputs.push(OutputReference {
                        stream: output.stream,
                        file,
                        resource: version,
                        truncated: output.error.is_some(),
                    }),
                    Err(failure) => {
                        receipt.error.get_or_insert(failure);
                    }
                }
            }
            if completed.started {
                match observe_artifacts(&provider.files, &directory).await {
                    Ok((files, errors)) => {
                        receipt.effects.artifacts =
                            files.iter().map(|file| file.version.clone()).collect();
                        if let Some(failure) = errors.first() {
                            receipt.error.get_or_insert_with(|| failure.clone());
                            receipt.effects.state = EffectsState::Unknown;
                        }
                        receipt.effects.detail = json!({"scope":"Files registered with sked_runtime.publish", "files":files, "errors":errors});
                    }
                    Err(failure) => {
                        receipt.error.get_or_insert(failure);
                        receipt.effects.state = EffectsState::Unknown;
                    }
                }
            }
            receipt.finished_at_ms = Some(now_ms());
            if let Err(failure) = ledger::append(&directory, &receipt) {
                receipt.terminal = Some(ExecutionTerminal::Lost);
                receipt.effects.state = EffectsState::Unknown;
                receipt.error = Some(failure);
            }
            receipt
        })
    }
}

async fn prepare_run(
    resources: &PreparedResources,
    request: &ExecutionStartRequest,
) -> Result<(PathBuf, Vec<File>)> {
    runtime::check_cancelled(&request.cancellation)?;
    check_cwd(
        &resources.provider.files,
        &request.specification.cwd_resource,
        &request.specification.cwd,
        request.cancellation.clone(),
    )
    .await?;
    let FrozenExecutionKind::Python { code, .. } = &request.specification.kind else {
        return Err(error(
            ExecutionErrorCode::InvalidSpec,
            "The prepared task is not Python source.",
        ));
    };
    let directory = ledger::create(&resources.provider.root, &request.identity)?;
    let invocation = serde_json::to_vec(&json!({"argv":request.specification.argv}))
        .map_err(|failure| error(ExecutionErrorCode::InvalidSpec, failure.to_string()))?;
    let material = vec![
        ledger::write_locked(&directory.join("source.py"), code.as_bytes())?,
        ledger::write_locked(&directory.join("invocation.json"), &invocation)?,
    ];
    ledger::write_new(&directory.join("published.ndjson"), b"")?;
    Ok((directory, material))
}

async fn check_cwd(
    files: &FileService,
    resource: &FileResourceRef,
    expected: &ResourceVersion,
    cancellation: CancellationToken,
) -> Result<()> {
    let entry = files
        .stat(resource.clone(), cancellation)
        .await
        .map_err(file_error)?;
    if entry.kind != FileKind::Directory || resource_version(&entry.version) != *expected {
        return Err(error(
            ExecutionErrorCode::StaleSpec,
            "The execution working directory changed after preparation.",
        ));
    }
    Ok(())
}

fn path_resource(path: &Path) -> FileResourceRef {
    FileResourceRef {
        kind: FileResourceKind::WindowsPath,
        value: path.to_string_lossy().into_owned(),
    }
}

fn resource_version(version: &FileVersion) -> ResourceVersion {
    ResourceVersion {
        resource_id: version.resource_id.clone(),
        version: version.version.clone(),
        digest: version.sha256.clone(),
        byte_length: version.byte_length,
    }
}

async fn observe(files: &FileService, file: FileResourceRef) -> Result<ResourceVersion> {
    let snapshot = files
        .snapshot(file, CancellationToken::new())
        .await
        .map_err(file_error)?;
    snapshot
        .source_version
        .as_ref()
        .map(resource_version)
        .ok_or_else(|| {
            error(
                ExecutionErrorCode::OutputUnavailable,
                "The output snapshot has no original file version.",
            )
        })
}

async fn recover_outputs(files: &FileService, directory: &Path, receipt: &mut ExecutionReceipt) {
    let mut errors = Vec::new();
    for (stream, name) in [
        (OutputStream::Stdout, "stdout.txt"),
        (OutputStream::Stderr, "stderr.txt"),
    ] {
        if receipt.outputs.iter().any(|output| output.stream == stream) {
            continue;
        }
        let path = directory.join(name);
        match fs::metadata(&path) {
            Err(failure) if failure.kind() == std::io::ErrorKind::NotFound => continue,
            Err(failure) => {
                errors.push(io_error(failure));
                continue;
            }
            Ok(_) => {}
        }
        let file = path_resource(&path);
        match observe(files, file.clone()).await {
            Ok(version) => receipt.outputs.push(OutputReference {
                stream,
                file,
                resource: version,
                truncated: true,
            }),
            Err(failure) => errors.push(failure),
        }
    }
    match observe_artifacts(files, directory).await {
        Ok((artifacts, failures)) => {
            errors.extend(failures);
            receipt.effects.artifacts = artifacts
                .iter()
                .map(|artifact| artifact.version.clone())
                .collect();
            receipt.effects.detail = json!({"scope":"Files observed after the interrupted execution", "files":artifacts, "errors":errors});
        }
        Err(failure) => {
            errors.push(failure);
            receipt.effects.detail =
                json!({"scope":"Files observed after the interrupted execution", "errors":errors});
        }
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Publication {
    path: String,
    name: Option<String>,
    media_type: Option<String>,
}

#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct Artifact {
    file: FileResourceRef,
    version: ResourceVersion,
    name: String,
    media_type: Option<String>,
}

async fn observe_artifacts(
    files: &FileService,
    directory: &Path,
) -> Result<(Vec<Artifact>, Vec<ExecutionError>)> {
    let records = fs::read_to_string(directory.join("published.ndjson")).map_err(io_error)?;
    let mut artifacts = Vec::new();
    let mut seen = HashSet::new();
    let mut errors = Vec::new();
    for line in records.lines() {
        let publication: Publication = match serde_json::from_str(line) {
            Ok(publication) => publication,
            Err(failure) => {
                errors.push(error(
                    ExecutionErrorCode::OutputUnavailable,
                    format!("The published file record cannot be read: {failure}"),
                ));
                continue;
            }
        };
        if !seen.insert(publication.path.clone()) {
            continue;
        }
        let path = Path::new(&publication.path);
        let file = path_resource(path);
        let version = match observe(files, file.clone()).await {
            Ok(version) => version,
            Err(failure) => {
                errors.push(failure);
                continue;
            }
        };
        let name = publication.name.unwrap_or_else(|| {
            path.file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .into_owned()
        });
        artifacts.push(Artifact {
            file,
            version,
            name,
            media_type: publication.media_type,
        });
    }
    Ok((artifacts, errors))
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
fn error(code: ExecutionErrorCode, message: impl Into<String>) -> ExecutionError {
    ExecutionError::new(code, message)
}
fn io_error(failure: std::io::Error) -> ExecutionError {
    error(ExecutionErrorCode::StorageFailure, failure.to_string())
}
fn file_error(failure: crate::files::FileError) -> ExecutionError {
    error(ExecutionErrorCode::OutputUnavailable, failure.to_string())
}
fn join_error(failure: tokio::task::JoinError) -> ExecutionError {
    error(ExecutionErrorCode::ProviderUnavailable, failure.to_string())
}
