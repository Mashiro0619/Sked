use std::{collections::BTreeMap, fmt};

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::files::FileResourceRef;

/// The exact provider generation selected for an execution. Recovery may use
/// a newer instance of the same provider, but retains this original identity.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExecutionProviderIdentity {
    pub provider_id: String,
    pub instance_id: String,
    pub generation: u64,
    pub contract_version: u32,
}

/// Identity shared by admission, progress, terminal receipts and later lookup.
/// A matching execution id alone cannot authorize a different operation/spec.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExecutionIdentity {
    pub execution_id: String,
    pub operation_id: String,
    pub spec_digest: String,
    pub provider: ExecutionProviderIdentity,
}

/// A host-owned resource at a real revision. Directory and URI identities may
/// omit content metadata; a frozen input snapshot requires digest and length.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ResourceVersion {
    pub resource_id: String,
    pub version: String,
    pub digest: Option<String>,
    pub byte_length: Option<u64>,
}

/// The original resource and the exact content exposed to this execution.
/// The prepared backend retains the frozen content/handle behind snapshot;
/// launching must not reopen a changed source through its original path.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InputSnapshot {
    pub source: ResourceVersion,
    pub snapshot: ResourceVersion,
    pub mounted_path: String,
}

/// Plain environment values can contain sensitive material, so execution
/// descriptions do not implement Debug. Secret values remain in host-owned
/// handles; the prepared backend captures their approved revision privately.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "data", rename_all = "camelCase")]
pub enum EnvironmentValue {
    Plain(String),
    SecretHandle { handle: String, revision: String },
}

/// The interpreter and dependency set actually selected by the host provider.
/// environment_digest binds its implementation/build configuration as well as
/// these version labels; it is not computed from a caller's claimed versions.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExecutionEnvironment {
    pub provider: ExecutionProviderIdentity,
    pub platform: String,
    pub architecture: String,
    pub interpreter: String,
    pub interpreter_version: String,
    pub dependencies: BTreeMap<String, String>,
    pub environment_digest: String,
}

#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScriptExecutionSpec {
    pub code: String,
    pub argv: Vec<String>,
    pub cwd_resource: FileResourceRef,
    pub cwd: ResourceVersion,
    pub environment: BTreeMap<String, EnvironmentValue>,
    pub inputs: Vec<InputSnapshot>,
}

/// reader_id selects a host registration, not caller-supplied code. The host
/// checks that registration's fixed entrypoint and argument schema. This input
/// deliberately has no arbitrary code, module, command, argv or environment.
#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ControlledReadSpec {
    pub reader_id: String,
    pub arguments: Value,
    pub inputs: Vec<InputSnapshot>,
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "data", rename_all = "camelCase")]
pub enum ExecutionSpec {
    Python(ScriptExecutionSpec),
    ControlledRead(ControlledReadSpec),
}

/// The exact reviewed code or resolved fixed-reader invocation. These public
/// descriptions are data; an opaque prepared backend owns launch authority.
#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(
    tag = "kind",
    content = "data",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum FrozenExecutionKind {
    Python {
        code: String,
        code_digest: String,
    },
    ControlledRead {
        reader_id: String,
        registration_digest: String,
        arguments: Value,
        arguments_digest: String,
    },
}

/// All code, arguments, working-directory/resource bindings, environment and
/// input snapshots participate in spec_digest. Preparing this description
/// never runs the script or installs dependencies.
#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FrozenExecutionSpec {
    pub kind: FrozenExecutionKind,
    pub argv: Vec<String>,
    pub cwd_resource: FileResourceRef,
    pub cwd: ResourceVersion,
    pub environment: ExecutionEnvironment,
    pub variables: BTreeMap<String, EnvironmentValue>,
    pub inputs: Vec<InputSnapshot>,
    pub spec_digest: String,
}

/// Process termination is independent of observed resource effects. Exited
/// includes nonzero exit codes; Cancelled does not imply unchanged files.
#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ExecutionTerminal {
    NotStarted,
    Exited,
    Cancelled,
    Lost,
}

#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EffectsState {
    NotStarted,
    Observed,
    Unknown,
}

/// Observed records only the effects the provider can establish. detail states
/// the observation scope; artifacts remain meaningful after failure or stop.
/// Unknown cannot be converted to NotStarted merely because lookup found no
/// live process or because the interpreter returned a nonzero exit code.
#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EffectsObservation {
    pub state: EffectsState,
    pub artifacts: Vec<ResourceVersion>,
    pub detail: Value,
}

#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum OutputStream {
    Stdout,
    Stderr,
}

#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OutputReference {
    pub stream: OutputStream,
    pub file: FileResourceRef,
    pub resource: ResourceVersion,
    pub truncated: bool,
}

/// Accepted, started and terminal are separate observations. A final receipt
/// retains its original four identity fields during recovery. Output and
/// effects may exist for Exited, Cancelled or Lost; exit_code alone never proves
/// whether a file changed. Providers return a terminal receipt after admission.
#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
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
    pub effects: EffectsObservation,
    pub outputs: Vec<OutputReference>,
    pub error: Option<ExecutionError>,
}

/// sequence orders one execution's events, including replay after reconnect.
/// Output bytes may split UTF-8 sequences and are not automatically log-safe.
#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExecutionEvent {
    pub execution_id: String,
    pub operation_id: String,
    pub spec_digest: String,
    pub provider: ExecutionProviderIdentity,
    pub sequence: u64,
    pub at_ms: i64,
    pub kind: ExecutionEventKind,
}

#[derive(Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "data", rename_all = "camelCase")]
pub enum ExecutionEventKind {
    Accepted,
    Started,
    Output {
        stream: OutputStream,
        offset: u64,
        bytes: Vec<u8>,
    },
    Progress {
        phase: String,
        message: String,
    },
    Terminal {
        receipt: ExecutionReceipt,
    },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
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

impl ExecutionErrorCode {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::InvalidSpec => "invalidSpec",
            Self::UnknownReader => "unknownReader",
            Self::StaleSpec => "staleSpec",
            Self::ProviderUnavailable => "providerUnavailable",
            Self::AlreadyConsumed => "alreadyConsumed",
            Self::IdentityMismatch => "identityMismatch",
            Self::CancelledBeforeStart => "cancelledBeforeStart",
            Self::AdmissionFailed => "admissionFailed",
            Self::StorageFailure => "storageFailure",
            Self::OutcomeUnknown => "outcomeUnknown",
            Self::OutputUnavailable => "outputUnavailable",
            Self::Unsupported => "unsupported",
        }
    }
}

/// message is a user-facing diagnostic and must be filtered before delivery or
/// persistence. Debug and Display expose only the stable error code.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExecutionError {
    pub code: ExecutionErrorCode,
    pub message: String,
}

impl ExecutionError {
    pub fn new(code: ExecutionErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

impl fmt::Debug for ExecutionError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("ExecutionError")
            .field("code", &self.code)
            .finish_non_exhaustive()
    }
}

impl fmt::Display for ExecutionError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "execution.{}", self.code.as_str())
    }
}

impl std::error::Error for ExecutionError {}
