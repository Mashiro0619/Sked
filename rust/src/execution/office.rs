use std::{collections::BTreeMap, sync::OnceLock};

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio_util::sync::CancellationToken;

use super::{
    ControlledReadSpec, ControlledReaderRegistration, ExecutionError, ExecutionErrorCode,
    ExecutionReceipt, FrozenExecutionKind, ResourceVersion, Result, ScriptExecutionSpec,
};
use crate::files::{FileKind, FileResourceRef, FileService};

const READER_ID: &str = "office.inspect";
const SOURCE: &str = include_str!("../../../tool/python/office_inspect.py");

pub(super) fn bundled_dependencies() -> &'static BTreeMap<String, String> {
    static DEPENDENCIES: OnceLock<BTreeMap<String, String>> = OnceLock::new();
    DEPENDENCIES.get_or_init(|| {
        let configuration: Value =
            serde_json::from_str(include_str!("../../../tool/python/runtime.json"))
                .expect("bundled Python runtime configuration");
        let key = if cfg!(target_os = "android") {
            "androidDependencies"
        } else {
            "dependencies"
        };
        serde_json::from_value(configuration[key].clone())
            .expect("locked Python dependency versions")
    })
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Arguments {
    format: Format,
}

#[derive(Deserialize)]
#[serde(rename_all = "lowercase")]
enum Format {
    Docx,
    Xlsx,
    Pptx,
}

pub(super) fn registration() -> ControlledReaderRegistration {
    let arguments_schema = json!({
        "type": "object",
        "additionalProperties": false,
        "required": ["format"],
        "properties": {
            "format": {"type": "string", "enum": ["docx", "xlsx", "pptx"]}
        }
    });
    let mut digest = Sha256::new();
    digest.update(READER_ID);
    digest.update([0]);
    digest.update(SOURCE);
    digest.update([0]);
    digest.update(arguments_schema.to_string());
    ControlledReaderRegistration {
        reader_id: READER_ID.into(),
        registration_digest: format!("{:x}", digest.finalize()),
        arguments_schema,
    }
}

/// Resolve only the provider-owned entrypoint. The caller supplies a format
/// and one immutable document, never Python code or a module search path.
pub(super) async fn prepare(
    request: ControlledReadSpec,
    files: &FileService,
    cwd: FileResourceRef,
    cancellation: CancellationToken,
) -> Result<(ScriptExecutionSpec, FrozenExecutionKind)> {
    if request.reader_id != READER_ID {
        return Err(ExecutionError::new(
            ExecutionErrorCode::UnknownReader,
            "The controlled document reader is not registered.",
        ));
    }
    let arguments: Arguments =
        serde_json::from_value(request.arguments.clone()).map_err(|failure| {
            ExecutionError::new(ExecutionErrorCode::InvalidSpec, failure.to_string())
        })?;
    let [document] = request.inputs.as_slice() else {
        return Err(ExecutionError::new(
            ExecutionErrorCode::InvalidSpec,
            "Office reading requires one frozen document input.",
        ));
    };
    let format = match arguments.format {
        Format::Docx => "docx",
        Format::Xlsx => "xlsx",
        Format::Pptx => "pptx",
    };
    let argv = vec![format.into(), document.mounted_path.clone()];
    let directory = files
        .stat(cwd, cancellation.clone())
        .await
        .map_err(|failure| {
            ExecutionError::new(
                if cancellation.is_cancelled() {
                    ExecutionErrorCode::CancelledBeforeStart
                } else {
                    ExecutionErrorCode::ProviderUnavailable
                },
                failure.to_string(),
            )
        })?;
    if directory.kind != FileKind::Directory {
        return Err(ExecutionError::new(
            ExecutionErrorCode::ProviderUnavailable,
            "The document reader working directory is unavailable.",
        ));
    }
    let registration = registration();
    Ok((
        ScriptExecutionSpec {
            code: String::new(),
            argv,
            cwd_resource: directory.resource,
            cwd: ResourceVersion {
                resource_id: directory.version.resource_id,
                version: directory.version.version,
                digest: directory.version.sha256,
                byte_length: directory.version.byte_length,
            },
            environment: BTreeMap::new(),
            inputs: request.inputs,
        },
        FrozenExecutionKind::ControlledRead {
            reader_id: registration.reader_id,
            registration_digest: registration.registration_digest,
            arguments: request.arguments,
            arguments_digest: String::new(),
        },
    ))
}

pub(super) fn source(kind: &FrozenExecutionKind) -> Result<&str> {
    match kind {
        FrozenExecutionKind::Python { code, .. } => Ok(code),
        FrozenExecutionKind::ControlledRead { reader_id, .. } if reader_id == READER_ID => {
            Ok(SOURCE)
        }
        _ => Err(ExecutionError::new(
            ExecutionErrorCode::UnknownReader,
            "The prepared controlled reader is not registered.",
        )),
    }
}

pub(super) fn is_controlled(kind: &FrozenExecutionKind) -> bool {
    matches!(kind, FrozenExecutionKind::ControlledRead { .. })
}

pub(super) fn mark_read(kind: &FrozenExecutionKind, receipt: &mut ExecutionReceipt) {
    if let FrozenExecutionKind::ControlledRead { reader_id, .. } = kind {
        receipt.effects.detail = json!({
            "readerId": reader_id,
            "sourceModified": false,
            "scope": "Document extraction output",
        });
    }
}

pub(super) fn record_outputs(
    receipt: &mut ExecutionReceipt,
    scope: &str,
    files: impl Serialize,
    errors: impl Serialize,
) {
    let mut detail = std::mem::take(&mut receipt.effects.detail);
    if detail.get("readerId").is_none() {
        detail["scope"] = Value::String(scope.into());
    }
    detail["files"] = json!(files);
    detail["errors"] = json!(errors);
    receipt.effects.detail = detail;
}
