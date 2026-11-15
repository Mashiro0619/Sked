//! Typed execution inputs, frozen previews and original execution evidence.

use std::collections::BTreeMap;

use super::{file_contracts::FileResourceRef, models::JsonPayload};
use crate::execution as internal;

#[derive(Clone)]
pub struct ExecutionProviderIdentity {
    pub provider_id: String,
    pub instance_id: String,
    pub generation: u64,
    pub contract_version: u32,
}

impl From<internal::ExecutionProviderIdentity> for ExecutionProviderIdentity {
    fn from(value: internal::ExecutionProviderIdentity) -> Self {
        Self {
            provider_id: value.provider_id,
            instance_id: value.instance_id,
            generation: value.generation,
            contract_version: value.contract_version,
        }
    }
}

impl From<ExecutionProviderIdentity> for internal::ExecutionProviderIdentity {
    fn from(value: ExecutionProviderIdentity) -> Self {
        Self {
            provider_id: value.provider_id,
            instance_id: value.instance_id,
            generation: value.generation,
            contract_version: value.contract_version,
        }
    }
}

#[derive(Clone)]
pub struct ExecutionIdentity {
    pub execution_id: String,
    pub operation_id: String,
    pub spec_digest: String,
    pub provider: ExecutionProviderIdentity,
}

impl From<internal::ExecutionIdentity> for ExecutionIdentity {
    fn from(value: internal::ExecutionIdentity) -> Self {
        Self {
            execution_id: value.execution_id,
            operation_id: value.operation_id,
            spec_digest: value.spec_digest,
            provider: value.provider.into(),
        }
    }
}

impl From<ExecutionIdentity> for internal::ExecutionIdentity {
    fn from(value: ExecutionIdentity) -> Self {
        Self {
            execution_id: value.execution_id,
            operation_id: value.operation_id,
            spec_digest: value.spec_digest,
            provider: value.provider.into(),
        }
    }
}

#[derive(Clone)]
pub struct ExecutionResourceVersion {
    pub resource_id: String,
    pub version: String,
    pub digest: Option<String>,
    pub byte_length: Option<u64>,
}

impl From<internal::ResourceVersion> for ExecutionResourceVersion {
    fn from(value: internal::ResourceVersion) -> Self {
        Self {
            resource_id: value.resource_id,
            version: value.version,
            digest: value.digest,
            byte_length: value.byte_length,
        }
    }
}

impl From<ExecutionResourceVersion> for internal::ResourceVersion {
    fn from(value: ExecutionResourceVersion) -> Self {
        Self {
            resource_id: value.resource_id,
            version: value.version,
            digest: value.digest,
            byte_length: value.byte_length,
        }
    }
}

#[derive(Clone)]
pub struct ExecutionInputSnapshot {
    pub source: ExecutionResourceVersion,
    pub snapshot: ExecutionResourceVersion,
    pub mounted_path: String,
}

impl From<internal::InputSnapshot> for ExecutionInputSnapshot {
    fn from(value: internal::InputSnapshot) -> Self {
        Self {
            source: value.source.into(),
            snapshot: value.snapshot.into(),
            mounted_path: value.mounted_path,
        }
    }
}

impl From<ExecutionInputSnapshot> for internal::InputSnapshot {
    fn from(value: ExecutionInputSnapshot) -> Self {
        Self {
            source: value.source.into(),
            snapshot: value.snapshot.into(),
            mounted_path: value.mounted_path,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ExecutionEnvironmentValueKind {
    Plain,
    SecretHandle,
}

#[derive(Clone)]
pub struct ExecutionEnvironmentVariable {
    pub name: String,
    pub kind: ExecutionEnvironmentValueKind,
    pub value: Option<String>,
    pub secret_handle: Option<String>,
    pub secret_revision: Option<String>,
}

fn environment_from_input(
    values: Vec<ExecutionEnvironmentVariable>,
) -> Result<BTreeMap<String, internal::EnvironmentValue>, String> {
    let mut variables = BTreeMap::new();
    for variable in values {
        let value = match (
            variable.kind,
            variable.value,
            variable.secret_handle,
            variable.secret_revision,
        ) {
            (ExecutionEnvironmentValueKind::Plain, Some(value), None, None) => {
                internal::EnvironmentValue::Plain(value)
            }
            (ExecutionEnvironmentValueKind::SecretHandle, None, Some(handle), Some(revision)) => {
                internal::EnvironmentValue::SecretHandle { handle, revision }
            }
            _ => return Err(invalid_spec()),
        };
        if variables.insert(variable.name, value).is_some() {
            return Err(invalid_spec());
        }
    }
    Ok(variables)
}

fn environment_to_view(
    variables: BTreeMap<String, internal::EnvironmentValue>,
) -> Vec<ExecutionEnvironmentVariable> {
    variables
        .into_iter()
        .map(|(name, value)| match value {
            internal::EnvironmentValue::Plain(value) => ExecutionEnvironmentVariable {
                name,
                kind: ExecutionEnvironmentValueKind::Plain,
                value: Some(value),
                secret_handle: None,
                secret_revision: None,
            },
            internal::EnvironmentValue::SecretHandle { handle, revision } => {
                ExecutionEnvironmentVariable {
                    name,
                    kind: ExecutionEnvironmentValueKind::SecretHandle,
                    value: None,
                    secret_handle: Some(handle),
                    secret_revision: Some(revision),
                }
            }
        })
        .collect()
}

#[derive(Clone)]
pub struct ExecutionDependency {
    pub name: String,
    pub version: String,
}

#[derive(Clone)]
pub struct ExecutionEnvironmentSnapshot {
    pub provider: ExecutionProviderIdentity,
    pub platform: String,
    pub architecture: String,
    pub interpreter: String,
    pub interpreter_version: String,
    pub dependencies: Vec<ExecutionDependency>,
    pub environment_digest: String,
}

impl From<internal::ExecutionEnvironment> for ExecutionEnvironmentSnapshot {
    fn from(value: internal::ExecutionEnvironment) -> Self {
        Self {
            provider: value.provider.into(),
            platform: value.platform,
            architecture: value.architecture,
            interpreter: value.interpreter,
            interpreter_version: value.interpreter_version,
            dependencies: value
                .dependencies
                .into_iter()
                .map(|(name, version)| ExecutionDependency { name, version })
                .collect(),
            environment_digest: value.environment_digest,
        }
    }
}

#[derive(Clone)]
pub struct PythonTaskInput {
    pub name: String,
    pub source: TaskInputSource,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum TaskInputSourceKind {
    Content,
    Attachment,
}

#[derive(Clone)]
pub struct TaskInputSource {
    pub kind: TaskInputSourceKind,
    pub id: String,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum OfficeDocumentFormat {
    Docx,
    Xlsx,
    Pptx,
}

#[derive(Clone)]
pub struct OfficeReadTaskRequest {
    pub source: TaskInputSource,
    pub format: OfficeDocumentFormat,
}

#[derive(Clone)]
pub struct PythonTaskEnvironment {
    pub name: String,
    pub value: String,
}

#[derive(Clone)]
pub struct PythonTaskRequest {
    pub code: String,
    pub argv: Vec<String>,
    pub cwd: FileResourceRef,
    pub inputs: Vec<PythonTaskInput>,
    pub environment: Vec<PythonTaskEnvironment>,
}

#[derive(Clone)]
pub struct PythonExecutionRequest {
    pub code: String,
    pub argv: Vec<String>,
    pub cwd_resource: FileResourceRef,
    pub cwd: ExecutionResourceVersion,
    pub environment: Vec<ExecutionEnvironmentVariable>,
    pub inputs: Vec<ExecutionInputSnapshot>,
}

impl TryFrom<PythonExecutionRequest> for internal::ExecutionSpec {
    type Error = String;

    fn try_from(value: PythonExecutionRequest) -> Result<Self, Self::Error> {
        Ok(Self::Python(internal::ScriptExecutionSpec {
            code: value.code,
            argv: value.argv,
            cwd_resource: value.cwd_resource.into(),
            cwd: value.cwd.into(),
            environment: environment_from_input(value.environment)?,
            inputs: value.inputs.into_iter().map(Into::into).collect(),
        }))
    }
}

#[derive(Clone)]
pub struct ControlledReadExecutionRequest {
    pub reader_id: String,
    pub arguments: JsonPayload,
    pub inputs: Vec<ExecutionInputSnapshot>,
}

impl TryFrom<ControlledReadExecutionRequest> for internal::ExecutionSpec {
    type Error = String;

    fn try_from(value: ControlledReadExecutionRequest) -> Result<Self, Self::Error> {
        Ok(Self::ControlledRead(internal::ControlledReadSpec {
            reader_id: value.reader_id,
            arguments: value.arguments.parse().map_err(|_| invalid_spec())?,
            inputs: value.inputs.into_iter().map(Into::into).collect(),
        }))
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ExecutionKind {
    Python,
    ControlledRead,
}

#[derive(Clone)]
pub struct ExecutionPreview {
    pub execution_id: String,
    pub kind: ExecutionKind,
    pub code: Option<String>,
    pub code_digest: Option<String>,
    pub reader_id: Option<String>,
    pub reader_registration_digest: Option<String>,
    pub arguments: Option<JsonPayload>,
    pub arguments_digest: Option<String>,
    pub argv: Vec<String>,
    pub cwd_resource: FileResourceRef,
    pub cwd: ExecutionResourceVersion,
    pub environment: ExecutionEnvironmentSnapshot,
    pub variables: Vec<ExecutionEnvironmentVariable>,
    pub inputs: Vec<ExecutionInputSnapshot>,
    pub spec_digest: String,
}

impl ExecutionPreview {
    pub(crate) fn from_prepared(
        execution_id: String,
        value: internal::FrozenExecutionSpec,
    ) -> Self {
        let (kind, code, code_digest, reader_id, registration_digest, arguments, arguments_digest) =
            match value.kind {
                internal::FrozenExecutionKind::Python { code, code_digest } => (
                    ExecutionKind::Python,
                    Some(code),
                    Some(code_digest),
                    None,
                    None,
                    None,
                    None,
                ),
                internal::FrozenExecutionKind::ControlledRead {
                    reader_id,
                    registration_digest,
                    arguments,
                    arguments_digest,
                } => (
                    ExecutionKind::ControlledRead,
                    None,
                    None,
                    Some(reader_id),
                    Some(registration_digest),
                    Some(json_payload(arguments)),
                    Some(arguments_digest),
                ),
            };
        Self {
            execution_id,
            kind,
            code,
            code_digest,
            reader_id,
            reader_registration_digest: registration_digest,
            arguments,
            arguments_digest,
            argv: value.argv,
            cwd_resource: value.cwd_resource.into(),
            cwd: value.cwd.into(),
            environment: value.environment.into(),
            variables: environment_to_view(value.variables),
            inputs: value.inputs.into_iter().map(Into::into).collect(),
            spec_digest: value.spec_digest,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ExecutionTerminal {
    NotStarted,
    Exited,
    Cancelled,
    Lost,
}

impl From<internal::ExecutionTerminal> for ExecutionTerminal {
    fn from(value: internal::ExecutionTerminal) -> Self {
        match value {
            internal::ExecutionTerminal::NotStarted => Self::NotStarted,
            internal::ExecutionTerminal::Exited => Self::Exited,
            internal::ExecutionTerminal::Cancelled => Self::Cancelled,
            internal::ExecutionTerminal::Lost => Self::Lost,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ExecutionEffectsState {
    NotStarted,
    Observed,
    Unknown,
}

impl From<internal::EffectsState> for ExecutionEffectsState {
    fn from(value: internal::EffectsState) -> Self {
        match value {
            internal::EffectsState::NotStarted => Self::NotStarted,
            internal::EffectsState::Observed => Self::Observed,
            internal::EffectsState::Unknown => Self::Unknown,
        }
    }
}

#[derive(Clone)]
pub struct ExecutionEffectsObservation {
    pub state: ExecutionEffectsState,
    pub artifacts: Vec<ExecutionResourceVersion>,
    pub detail: JsonPayload,
}

impl From<internal::EffectsObservation> for ExecutionEffectsObservation {
    fn from(value: internal::EffectsObservation) -> Self {
        Self {
            state: value.state.into(),
            artifacts: value.artifacts.into_iter().map(Into::into).collect(),
            detail: json_payload(value.detail),
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ExecutionOutputStream {
    Stdout,
    Stderr,
}

impl From<internal::OutputStream> for ExecutionOutputStream {
    fn from(value: internal::OutputStream) -> Self {
        match value {
            internal::OutputStream::Stdout => Self::Stdout,
            internal::OutputStream::Stderr => Self::Stderr,
        }
    }
}

#[derive(Clone)]
pub struct ExecutionOutputReference {
    pub stream: ExecutionOutputStream,
    pub file: FileResourceRef,
    pub resource: ExecutionResourceVersion,
    pub truncated: bool,
}

impl From<internal::OutputReference> for ExecutionOutputReference {
    fn from(value: internal::OutputReference) -> Self {
        Self {
            stream: value.stream.into(),
            file: value.file.into(),
            resource: value.resource.into(),
            truncated: value.truncated,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ExecutionErrorCode {
    InvalidSpec,
    UnknownReader,
    StaleSpec,
    ProviderUnavailable,
    AlreadyConsumed,
    IdentityMismatch,
    CancelledBeforeStart,
    AdmissionFailed,
    StorageFailure,
    OutcomeUnknown,
    OutputUnavailable,
    Unsupported,
}

impl From<internal::ExecutionErrorCode> for ExecutionErrorCode {
    fn from(value: internal::ExecutionErrorCode) -> Self {
        match value {
            internal::ExecutionErrorCode::InvalidSpec => Self::InvalidSpec,
            internal::ExecutionErrorCode::UnknownReader => Self::UnknownReader,
            internal::ExecutionErrorCode::StaleSpec => Self::StaleSpec,
            internal::ExecutionErrorCode::ProviderUnavailable => Self::ProviderUnavailable,
            internal::ExecutionErrorCode::AlreadyConsumed => Self::AlreadyConsumed,
            internal::ExecutionErrorCode::IdentityMismatch => Self::IdentityMismatch,
            internal::ExecutionErrorCode::CancelledBeforeStart => Self::CancelledBeforeStart,
            internal::ExecutionErrorCode::AdmissionFailed => Self::AdmissionFailed,
            internal::ExecutionErrorCode::StorageFailure => Self::StorageFailure,
            internal::ExecutionErrorCode::OutcomeUnknown => Self::OutcomeUnknown,
            internal::ExecutionErrorCode::OutputUnavailable => Self::OutputUnavailable,
            internal::ExecutionErrorCode::Unsupported => Self::Unsupported,
        }
    }
}

#[derive(Clone)]
pub struct ExecutionError {
    pub code: ExecutionErrorCode,
    pub message: String,
}

impl From<internal::ExecutionError> for ExecutionError {
    fn from(value: internal::ExecutionError) -> Self {
        Self {
            code: value.code.into(),
            message: value.message,
        }
    }
}

#[derive(Clone)]
pub struct ExecutionReceipt {
    pub execution_id: String,
    pub operation_id: String,
    pub spec_digest: String,
    pub provider: ExecutionProviderIdentity,
    pub accepted_at_ms: Option<i64>,
    pub started_at_ms: Option<i64>,
    pub terminal: Option<ExecutionTerminal>,
    pub finished_at_ms: Option<i64>,
    pub exit_code: Option<i32>,
    pub effects: ExecutionEffectsObservation,
    pub outputs: Vec<ExecutionOutputReference>,
    pub error: Option<ExecutionError>,
}

impl From<internal::ExecutionReceipt> for ExecutionReceipt {
    fn from(value: internal::ExecutionReceipt) -> Self {
        Self {
            execution_id: value.execution_id,
            operation_id: value.operation_id,
            spec_digest: value.spec_digest,
            provider: value.provider.into(),
            accepted_at_ms: value.accepted_at_ms,
            started_at_ms: value.started_at_ms,
            terminal: value.terminal.map(Into::into),
            finished_at_ms: value.finished_at_ms,
            exit_code: value.exit_code,
            effects: value.effects.into(),
            outputs: value.outputs.into_iter().map(Into::into).collect(),
            error: value.error.map(Into::into),
        }
    }
}

#[derive(Clone)]
pub struct ExecutionControlledReader {
    pub reader_id: String,
    pub registration_digest: String,
    pub arguments_schema: JsonPayload,
}

impl From<internal::ControlledReaderRegistration> for ExecutionControlledReader {
    fn from(value: internal::ControlledReaderRegistration) -> Self {
        Self {
            reader_id: value.reader_id,
            registration_digest: value.registration_digest,
            arguments_schema: json_payload(value.arguments_schema),
        }
    }
}

#[derive(Clone)]
pub struct ExecutionAvailability {
    pub available: bool,
    pub provider: Option<ExecutionProviderIdentity>,
    pub python: bool,
    pub controlled_readers: Vec<ExecutionControlledReader>,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum ExecutionEventKind {
    Accepted,
    Started,
    Output,
    Progress,
    Terminal,
    Snapshot,
}

#[derive(Clone)]
pub struct ExecutionEvent {
    pub execution_id: String,
    pub operation_id: String,
    pub spec_digest: String,
    pub provider: ExecutionProviderIdentity,
    pub sequence: Option<u64>,
    pub at_ms: Option<i64>,
    pub kind: ExecutionEventKind,
    pub stream: Option<ExecutionOutputStream>,
    pub offset: Option<u64>,
    pub bytes: Vec<u8>,
    pub phase: Option<String>,
    pub message: Option<String>,
    pub receipt: Option<ExecutionReceipt>,
}

impl From<internal::ExecutionEvent> for ExecutionEvent {
    fn from(value: internal::ExecutionEvent) -> Self {
        let mut event = Self {
            execution_id: value.execution_id,
            operation_id: value.operation_id,
            spec_digest: value.spec_digest,
            provider: value.provider.into(),
            sequence: Some(value.sequence),
            at_ms: Some(value.at_ms),
            kind: ExecutionEventKind::Accepted,
            stream: None,
            offset: None,
            bytes: Vec::new(),
            phase: None,
            message: None,
            receipt: None,
        };
        match value.kind {
            internal::ExecutionEventKind::Accepted => {}
            internal::ExecutionEventKind::Started => event.kind = ExecutionEventKind::Started,
            internal::ExecutionEventKind::Output {
                stream,
                offset,
                bytes,
            } => {
                event.kind = ExecutionEventKind::Output;
                event.stream = Some(stream.into());
                event.offset = Some(offset);
                event.bytes = bytes;
            }
            internal::ExecutionEventKind::Progress { phase, message } => {
                event.kind = ExecutionEventKind::Progress;
                event.phase = Some(phase);
                event.message = Some(message);
            }
            internal::ExecutionEventKind::Terminal { receipt } => {
                event.kind = ExecutionEventKind::Terminal;
                event.receipt = Some(receipt.into());
            }
        }
        event
    }
}

impl ExecutionEvent {
    pub(crate) fn from_receipt(receipt: internal::ExecutionReceipt) -> Self {
        Self {
            execution_id: receipt.execution_id.clone(),
            operation_id: receipt.operation_id.clone(),
            spec_digest: receipt.spec_digest.clone(),
            provider: receipt.provider.clone().into(),
            sequence: None,
            at_ms: None,
            kind: ExecutionEventKind::Snapshot,
            stream: None,
            offset: None,
            bytes: Vec::new(),
            phase: None,
            message: None,
            receipt: Some(receipt.into()),
        }
    }
}

fn json_payload(value: serde_json::Value) -> JsonPayload {
    JsonPayload {
        json: value.to_string(),
    }
}

fn invalid_spec() -> String {
    internal::ExecutionError::new(
        internal::ExecutionErrorCode::InvalidSpec,
        "The execution input fields are inconsistent.",
    )
    .to_string()
}
