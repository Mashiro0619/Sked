mod bridge;
mod ledger;
mod runtime;

use std::{
    fs::{self, File, OpenOptions},
    os::{
        fd::AsRawFd,
        unix::fs::{MetadataExt, OpenOptionsExt},
    },
    path::{Path, PathBuf},
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};

use async_trait::async_trait;
use futures::future::BoxFuture;
use serde::Deserialize;
use serde_json::json;
use tokio::{io::AsyncReadExt, sync::Mutex};
use tokio_util::sync::CancellationToken;

use super::{
    EXECUTION_SERVICE, EffectsState, EnvironmentValue, ExecutionCapabilities, ExecutionError,
    ExecutionErrorCode, ExecutionEventKind, ExecutionIdentity, ExecutionPreparation,
    ExecutionProvider, ExecutionProviderIdentity, ExecutionReceipt, ExecutionService,
    ExecutionSpec, ExecutionStartRequest, ExecutionTerminal, FrozenExecutionKind,
    FrozenExecutionSpec, OutputReference, OutputStream, PreparedExecutionBackend, ResourceVersion,
    Result, office,
};
use crate::{
    files::{
        FILES_SERVICE, FileKind, FileResourceKind, FileResourceRef, FileService, FileVersion,
        SnapshotReadLease,
    },
    plugins::{Plugin, PluginContext, PluginDescriptor, PluginError},
};

pub struct AndroidExecutionPlugin {
    pub root: PathBuf,
}

#[async_trait]
impl Plugin for AndroidExecutionPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.android.execution",
            contract_version: 1,
            provides: vec![EXECUTION_SERVICE.key()],
            dependencies: vec![FILES_SERVICE.key()],
        }
    }
    async fn setup(&self, context: PluginContext) -> std::result::Result<(), PluginError> {
        let provider = AndroidProvider {
            inner: Arc::new(Provider {
                identity: ExecutionProviderIdentity {
                    provider_id: "sked.android.python".into(),
                    instance_id: context.instance_id().into(),
                    generation: context.generation(),
                    contract_version: 1,
                },
                files: (*context.require(FILES_SERVICE)?).clone(),
                root: self.root.clone(),
                process: Mutex::new(()),
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
    process: Mutex<()>,
}
#[derive(Clone)]
struct AndroidProvider {
    inner: Arc<Provider>,
}

impl ExecutionProvider for AndroidProvider {
    fn identity(&self) -> ExecutionProviderIdentity {
        self.inner.identity.clone()
    }
    fn capabilities(&self) -> ExecutionCapabilities {
        let available = crate::android::python_bridge_available();
        ExecutionCapabilities {
            python: available,
            controlled_readers: if available {
                vec![office::registration()]
            } else {
                Vec::new()
            },
        }
    }
    fn prepare(
        &self,
        specification: ExecutionSpec,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<ExecutionPreparation>> {
        let provider = self.inner.clone();
        Box::pin(async move {
            let (input, kind) = match specification {
                ExecutionSpec::Python(mut input) => {
                    let kind = FrozenExecutionKind::Python {
                        code: std::mem::take(&mut input.code),
                        code_digest: String::new(),
                    };
                    (input, kind)
                }
                ExecutionSpec::ControlledRead(input) => {
                    office::prepare(
                        input,
                        &provider.files,
                        path_resource(Path::new("/")),
                        cancellation.clone(),
                    )
                    .await?
                }
            };
            if input.cwd_resource.kind != FileResourceKind::AndroidPath {
                return Err(error(
                    ExecutionErrorCode::InvalidSpec,
                    "Android Python requires an Android working-directory path.",
                ));
            }
            if input.environment.contains_key("_SKED_EXECUTION_DIR") {
                return Err(error(
                    ExecutionErrorCode::InvalidSpec,
                    "_SKED_EXECUTION_DIR is set by the execution runtime.",
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
            let identity = provider.identity.clone();
            let preparing = cancellation.clone();
            let cwd_path = input.cwd_resource.value.clone();
            let (runtime, cwd) = tokio::task::spawn_blocking(move || {
                let runtime = runtime::Runtime::capture(identity, &preparing)?;
                let cwd = OpenOptions::new()
                    .read(true)
                    .custom_flags(libc::O_PATH | libc::O_DIRECTORY | libc::O_CLOEXEC)
                    .open(cwd_path)
                    .map_err(io_error)?;
                Ok::<_, ExecutionError>((runtime, cwd))
            })
            .await
            .map_err(join_error)??;
            check_cwd(
                &provider.files,
                &cwd,
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
                if metadata.content.kind != FileResourceKind::AndroidPath
                    || metadata.content.value != input.mounted_path
                    || metadata.content_version.version != input.snapshot.version
                    || metadata.content_version.sha256 != input.snapshot.digest
                    || metadata.content_version.byte_length != input.snapshot.byte_length
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
                kind,
                argv: input.argv,
                cwd: input.cwd,
                cwd_resource: input.cwd_resource,
                environment: runtime.environment.clone(),
                variables: input.environment,
                inputs: input.inputs,
                spec_digest: String::new(),
            };
            Ok(ExecutionPreparation {
                specification,
                backend: Arc::new(Backend {
                    resources: Arc::new(Resources {
                        provider,
                        runtime,
                        cwd,
                        _inputs: inputs,
                    }),
                }),
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
                observe_outputs(
                    &provider.files,
                    &ledger::directory(&provider.root, &identity)?,
                    &mut receipt,
                    true,
                    None,
                )
                .await;
            }
            Ok(receipt)
        })
    }
}

struct Resources {
    provider: Arc<Provider>,
    runtime: runtime::Runtime,
    cwd: File,
    _inputs: Vec<SnapshotReadLease>,
}
struct Backend {
    resources: Arc<Resources>,
}

impl PreparedExecutionBackend for Backend {
    fn start(&self, request: ExecutionStartRequest) -> BoxFuture<'static, ExecutionReceipt> {
        let resources = self.resources.clone();
        Box::pin(async move {
            let mut receipt = ledger::pending(&request.identity);
            office::mark_read(&request.specification.kind, &mut receipt);
            let prepared = prepare_run(&resources, &request);
            let (directory, _material) = match prepared {
                Ok(prepared) => prepared,
                Err(failure) => {
                    finish_not_started(&mut receipt, failure);
                    if let Ok(directory) =
                        ledger::directory(&resources.provider.root, &request.identity)
                    {
                        if directory.is_dir() {
                            let _ = ledger::append(&directory, &receipt);
                        }
                    }
                    return receipt;
                }
            };
            if let Err(failure) = ledger::append(&directory, &receipt) {
                finish_not_started(&mut receipt, failure);
                return receipt;
            }
            let slot = tokio::select! {
                biased;
                _ = request.cancellation.cancelled() => Err(error(
                    ExecutionErrorCode::CancelledBeforeStart,
                    "The queued Python execution was cancelled.",
                )),
                slot = resources.provider.process.lock() => Ok(slot),
            };
            match slot {
                Err(failure) => finish_not_started(&mut receipt, failure),
                Ok(_slot) => run(&resources, &request, &directory, &mut receipt).await,
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

fn prepare_run(
    resources: &Resources,
    request: &ExecutionStartRequest,
) -> Result<(PathBuf, Vec<File>)> {
    runtime::check_cancelled(&request.cancellation)?;
    let code = office::source(&request.specification.kind)?;
    let directory = ledger::create(&resources.provider.root, &request.identity)?;
    let mut environment = resources.runtime.variables.clone();
    for (name, value) in &request.specification.variables {
        let EnvironmentValue::Plain(value) = value else {
            return Err(error(
                ExecutionErrorCode::Unsupported,
                "This Python provider does not resolve secret handles.",
            ));
        };
        environment.insert(name.clone(), value.clone());
    }
    let invocation = serde_json::to_vec(&json!({
        "identity": request.identity,
        "cwd": request.specification.cwd_resource.value,
        "argv": request.specification.argv,
        "environment": environment,
        "controlledReader": office::is_controlled(&request.specification.kind),
    }))
    .map_err(|failure| error(ExecutionErrorCode::InvalidSpec, failure.to_string()))?;
    let material = vec![
        ledger::write_new(&directory.join("source.py"), code.as_bytes())?,
        ledger::write_new(&directory.join("invocation.json"), &invocation)?,
    ];
    fs::create_dir(directory.join("publications")).map_err(io_error)?;
    Ok((directory, material))
}

async fn run(
    resources: &Resources,
    request: &ExecutionStartRequest,
    directory: &Path,
    receipt: &mut ExecutionReceipt,
) {
    let preflight = async {
        runtime::check_cancelled(&request.cancellation)?;
        let current = tokio::task::spawn_blocking(runtime::info)
            .await
            .map_err(join_error)??;
        if current != resources.runtime.info {
            return Err(error(
                ExecutionErrorCode::StaleSpec,
                "The Android Python runtime changed after preparation.",
            ));
        }
        check_cwd(
            &resources.provider.files,
            &resources.cwd,
            &request.specification.cwd_resource,
            &request.specification.cwd,
            request.cancellation.clone(),
        )
        .await
    }
    .await;
    if let Err(failure) = preflight {
        finish_not_started(receipt, failure);
        return;
    }
    let call = match bridge::Call::begin(
        request.identity.execution_id.clone(),
        directory.to_string_lossy().into_owned(),
        resources.cwd.as_raw_fd(),
        request.cancellation.clone(),
    )
    .await
    {
        Ok(call) => call,
        Err(failure) => {
            finish_not_started(receipt, failure);
            return;
        }
    };
    let launch = async {
        let ready: bridge::Ready = call.request("ready").await?;
        if ready.pid <= 0 || ready.pid != ready.process_group {
            return Err(error(
                ExecutionErrorCode::AdmissionFailed,
                "The Python process has no independent process group.",
            ));
        }
        check_cwd(
            &resources.provider.files,
            &resources.cwd,
            &request.specification.cwd_resource,
            &request.specification.cwd,
            request.cancellation.clone(),
        )
        .await?;
        runtime::check_cancelled(&request.cancellation)?;
        receipt.started_at_ms = Some(now_ms());
        ledger::append(directory, receipt)?;
        let started: bridge::Started = call.request("start").await?;
        if started.started {
            let _ = request.events.send(ExecutionEventKind::Started).await;
        }
        Ok::<_, ExecutionError>(started.started)
    }
    .await;
    let signalled = launch.as_ref().is_ok_and(|started| *started);
    let mut failure = launch.err();
    if !signalled {
        if let Err(cancelling) = call.cancel().await {
            failure.get_or_insert(cancelling);
        }
    }
    let closed = call.request::<bridge::Closed>("wait").await;
    let cleanup = call.finish().await;
    if let Err(cleanup) = cleanup {
        failure.get_or_insert(cleanup);
    }
    let closed = match closed {
        Ok(closed) => closed,
        Err(waiting) => {
            receipt.terminal = Some(ExecutionTerminal::Lost);
            receipt.effects.state = EffectsState::Unknown;
            receipt.error = Some(waiting);
            if let Ok(terminal) = read_terminal(directory, &request.identity) {
                receipt.exit_code = Some(terminal.exit_code);
            }
            observe_outputs(
                &resources.provider.files,
                directory,
                receipt,
                true,
                Some(request.events.clone()),
            )
            .await;
            return;
        }
    };
    let cancelled = closed.cancelled && request.cancellation.is_cancelled();
    let lifecycle_failed = failure.is_some() || closed.error.is_some() || !closed.group_gone;
    if let Some(message) = closed.error {
        failure.get_or_insert_with(|| error(ExecutionErrorCode::OutcomeUnknown, message));
    }
    if !closed.started {
        receipt.started_at_ms = None;
        finish_not_started(
            receipt,
            failure.unwrap_or_else(|| {
                error(
                    ExecutionErrorCode::CancelledBeforeStart,
                    "The Python execution was cancelled before starting.",
                )
            }),
        );
        return;
    }
    if !signalled {
        let _ = request.events.send(ExecutionEventKind::Started).await;
    }
    let terminal = read_terminal(directory, &request.identity);
    let output_failed = terminal
        .as_ref()
        .is_ok_and(|terminal| terminal.output_error.is_some());
    match terminal {
        Ok(terminal) => {
            receipt.exit_code = Some(terminal.exit_code);
            receipt.terminal = Some(if lifecycle_failed {
                ExecutionTerminal::Lost
            } else if cancelled {
                ExecutionTerminal::Cancelled
            } else {
                ExecutionTerminal::Exited
            });
            if let Some(message) = terminal.output_error {
                failure
                    .get_or_insert_with(|| error(ExecutionErrorCode::OutputUnavailable, message));
            }
        }
        Err(missing) => {
            receipt.terminal = Some(if cancelled && !lifecycle_failed {
                ExecutionTerminal::Cancelled
            } else {
                ExecutionTerminal::Lost
            });
            if !cancelled {
                failure.get_or_insert(missing);
            }
        }
    }
    receipt.effects.state = if receipt.terminal == Some(ExecutionTerminal::Lost) {
        EffectsState::Unknown
    } else {
        EffectsState::Observed
    };
    receipt.error = failure;
    let truncated = output_failed || receipt.terminal == Some(ExecutionTerminal::Lost);
    observe_outputs(
        &resources.provider.files,
        directory,
        receipt,
        truncated,
        Some(request.events.clone()),
    )
    .await;
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Terminal {
    identity: ExecutionIdentity,
    exit_code: i32,
    #[allow(dead_code)]
    finished_at_ms: i64,
    output_error: Option<String>,
}
fn read_terminal(directory: &Path, identity: &ExecutionIdentity) -> Result<Terminal> {
    let data = fs::read(directory.join("terminal.json")).map_err(|failure| {
        error(
            ExecutionErrorCode::OutcomeUnknown,
            format!("The Python process has no complete terminal record: {failure}"),
        )
    })?;
    let terminal: Terminal = serde_json::from_slice(&data)
        .map_err(|failure| error(ExecutionErrorCode::OutcomeUnknown, failure.to_string()))?;
    if terminal.identity != *identity {
        return Err(error(
            ExecutionErrorCode::IdentityMismatch,
            "The Python terminal record belongs to another execution.",
        ));
    }
    Ok(terminal)
}

async fn check_cwd(
    files: &FileService,
    directory: &File,
    resource: &FileResourceRef,
    expected: &ResourceVersion,
    cancellation: CancellationToken,
) -> Result<()> {
    let metadata = directory.metadata().map_err(io_error)?;
    let identity = format!("android:{:x}:{:x}", metadata.dev(), metadata.ino());
    let entry = files
        .stat(resource.clone(), cancellation)
        .await
        .map_err(file_error)?;
    if identity != expected.resource_id
        || entry.kind != FileKind::Directory
        || resource_version(&entry.version) != *expected
    {
        return Err(error(
            ExecutionErrorCode::StaleSpec,
            "The execution working directory changed after preparation.",
        ));
    }
    Ok(())
}

fn finish_not_started(receipt: &mut ExecutionReceipt, failure: ExecutionError) {
    receipt.started_at_ms = None;
    receipt.terminal = Some(ExecutionTerminal::NotStarted);
    receipt.effects.state = EffectsState::NotStarted;
    receipt.finished_at_ms = Some(now_ms());
    receipt.error = Some(failure);
}

fn path_resource(path: &Path) -> FileResourceRef {
    FileResourceRef {
        kind: FileResourceKind::AndroidPath,
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

async fn observe_outputs(
    files: &FileService,
    directory: &Path,
    receipt: &mut ExecutionReceipt,
    truncated: bool,
    events: Option<tokio::sync::mpsc::Sender<ExecutionEventKind>>,
) {
    let mut errors = Vec::new();
    for (stream, name) in [
        (OutputStream::Stdout, "stdout.txt"),
        (OutputStream::Stderr, "stderr.txt"),
    ] {
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
                truncated,
            }),
            Err(failure) => {
                errors.push(failure);
                continue;
            }
        }
        if let Some(events) = &events {
            if let Err(failure) = emit_output(&path, stream, events).await {
                errors.push(failure);
            }
        }
    }
    let artifacts = match observe_artifacts(files, directory).await {
        Ok((artifacts, failures)) => {
            errors.extend(failures);
            artifacts
        }
        Err(failure) => {
            errors.push(failure);
            Vec::new()
        }
    };
    if let Some(failure) = errors.first() {
        receipt.error.get_or_insert_with(|| failure.clone());
        receipt.effects.state = EffectsState::Unknown;
    }
    receipt.effects.artifacts = artifacts
        .iter()
        .map(|artifact| artifact.version.clone())
        .collect();
    office::record_outputs(
        receipt,
        "Files registered with sked_runtime.publish",
        artifacts,
        errors,
    );
}

async fn emit_output(
    path: &Path,
    stream: OutputStream,
    events: &tokio::sync::mpsc::Sender<ExecutionEventKind>,
) -> Result<()> {
    let mut file = tokio::fs::File::open(path).await.map_err(io_error)?;
    let mut buffer = [0u8; 16 * 1024];
    let mut offset = 0;
    loop {
        let count = file.read(&mut buffer).await.map_err(io_error)?;
        if count == 0 {
            return Ok(());
        }
        let _ = events
            .send(ExecutionEventKind::Output {
                stream,
                offset,
                bytes: buffer[..count].to_vec(),
            })
            .await;
        offset += count as u64;
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
    let mut artifacts = Vec::new();
    let mut errors = Vec::new();
    let mut seen = std::collections::HashSet::new();
    let mut records = Vec::new();
    match fs::read_dir(directory.join("publications")) {
        Ok(entries) => {
            let mut paths = Vec::new();
            for entry in entries {
                match entry {
                    Ok(entry) => {
                        let path = entry.path();
                        if path
                            .extension()
                            .is_some_and(|extension| extension == "json")
                        {
                            paths.push(path);
                        }
                    }
                    Err(failure) => errors.push(io_error(failure)),
                }
            }
            paths.sort();
            for path in paths {
                match fs::read_to_string(path) {
                    Ok(record) => records.push(record),
                    Err(failure) => errors.push(io_error(failure)),
                }
            }
        }
        Err(failure) if failure.kind() == std::io::ErrorKind::NotFound => {
            let legacy =
                fs::read_to_string(directory.join("published.ndjson")).map_err(io_error)?;
            records.extend(legacy.lines().map(str::to_owned));
        }
        Err(failure) => return Err(io_error(failure)),
    }
    for record in records {
        let publication: Publication = match serde_json::from_str(&record) {
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
