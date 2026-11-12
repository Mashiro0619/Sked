use std::{
    collections::{BTreeMap, HashSet},
    path::Path,
};

use super::{
    AgentCore,
    execution::{ExecutionPreparationCancellation, PreparedExecutionHandle},
    execution_contracts::{PythonTaskEnvironment, PythonTaskRequest},
};
use crate::{
    execution::{
        EnvironmentValue, ExecutionSpec, InputSnapshot, ResourceVersion, ScriptExecutionSpec,
    },
    files::{FileKind, FileResourceKind, FileResourceRef, FileVersion},
    storage::StorageError,
};

const INPUTS_VARIABLE: &str = "SKED_INPUTS_JSON";

impl AgentCore {
    /// Resolve conversation-owned inputs before the existing execution service
    /// freezes the provider and returns its approval preview.
    pub async fn prepare_python_task(
        &self,
        conversation_id: String,
        request: PythonTaskRequest,
        cancellation: &ExecutionPreparationCancellation,
    ) -> Result<PreparedExecutionHandle, String> {
        let cancellation = cancellation.token.clone();
        if self.closing.is_cancelled() || cancellation.is_cancelled() {
            return Err(task_error(
                "cancelledBeforeStart",
                "Python preparation was cancelled.",
            ));
        }
        let execution = self.profile.execution_service().ok_or_else(|| {
            task_error("providerUnavailable", "No execution provider is available.")
        })?;
        let files = self
            .profile
            .file_service()
            .ok_or_else(|| task_error("providerUnavailable", "No file provider is available."))?;
        let mut environment = task_environment(request.environment)?;
        let mut names = HashSet::new();
        if request
            .inputs
            .iter()
            .any(|input| !names.insert(&input.name))
        {
            return Err(task_error(
                "invalidSpec",
                "Python input names must be unique.",
            ));
        }
        drop(names);
        let directory = files
            .stat(request.cwd.into(), cancellation.clone())
            .await
            .map_err(|error| {
                task_error(
                    if cancellation.is_cancelled() {
                        "cancelledBeforeStart"
                    } else {
                        "invalidSpec"
                    },
                    format!("cwd: {}", error.message),
                )
            })?;
        if directory.kind != FileKind::Directory {
            return Err(task_error(
                "invalidSpec",
                "The Python working directory must be a directory.",
            ));
        }
        let input_files = (*files).clone();
        let input_cancellation = cancellation.clone();
        let result = async {
            let (inputs, paths, retentions) = self
                .storage()
                .call(move |store| {
                    let conversation = store
                        .read_uncached(&conversation_id)?
                        .ok_or_else(|| StorageError::NotFound(conversation_id.clone()))?;
                    let mut inputs = Vec::new();
                    let mut paths = BTreeMap::new();
                    let mut retentions = Vec::new();
                    for input in request.inputs {
                        let reference = conversation
                            .messages
                            .iter()
                            .chain(
                                conversation
                                    .history_versions
                                    .iter()
                                    .flat_map(|version| &version.messages),
                            )
                            .flat_map(|message| &message.tool_content_refs)
                            .find(|reference| reference.id == input.content_id)
                            .ok_or_else(|| StorageError::NotFound(input.content_id.clone()))?;
                        let attachment = conversation
                            .attachments
                            .iter()
                            .find(|attachment| attachment.id == reference.attachment_id)
                            .ok_or_else(|| {
                                StorageError::NotFound(reference.attachment_id.clone())
                            })?;
                        let path = store.attachment_path(attachment)?;
                        let source = local_resource(&path)?;
                        // Keep the storage job exclusive until the complete copy
                        // is sealed, so collection cannot remove its source.
                        let (snapshot, retention) =
                            futures::executor::block_on(input_files.snapshot_retained(
                                source,
                                input_cancellation.clone(),
                                |_| {},
                            ))
                            .map_err(|error| StorageError::Invalid(error.to_string()))?;
                        if snapshot.content_version.byte_length != Some(attachment.byte_length)
                            || !snapshot
                                .content_version
                                .sha256
                                .as_ref()
                                .is_some_and(|digest| {
                                    digest.eq_ignore_ascii_case(&attachment.sha256)
                                })
                        {
                            return Err(StorageError::Invalid(
                                "The Python input differs from its saved attachment.".into(),
                            ));
                        }
                        let mut frozen_version = resource_version(snapshot.content_version);
                        frozen_version.resource_id = snapshot.id;
                        paths.insert(input.name, snapshot.content.value.clone());
                        inputs.push(InputSnapshot {
                            source: ResourceVersion {
                                resource_id: format!(
                                    "conversation:{conversation_id}:content:{}",
                                    input.content_id
                                ),
                                version: attachment.sha256.clone(),
                                digest: Some(attachment.sha256.clone()),
                                byte_length: Some(attachment.byte_length),
                            },
                            snapshot: frozen_version,
                            mounted_path: snapshot.content.value,
                        });
                        retentions.push(retention);
                    }
                    Ok((inputs, paths, retentions))
                })
                .await
                .map_err(|error| {
                    task_error(
                        if self.closing.is_cancelled() || cancellation.is_cancelled() {
                            "cancelledBeforeStart"
                        } else {
                            "storageFailure"
                        },
                        error.to_string(),
                    )
                })?;
            environment.insert(
                INPUTS_VARIABLE.into(),
                EnvironmentValue::Plain(
                    serde_json::to_string(&paths)
                        .map_err(|error| task_error("invalidSpec", error.to_string()))?,
                ),
            );
            let prepared = execution
                .prepare_cancellable(
                    ExecutionSpec::Python(ScriptExecutionSpec {
                        code: request.code,
                        argv: request.argv,
                        cwd_resource: directory.resource,
                        cwd: resource_version(directory.version),
                        environment,
                        inputs,
                    }),
                    cancellation,
                )
                .await
                .map_err(|error| task_error(error.code.as_str(), error.message))?;
            // The prepared backend now owns its input leases.
            drop(retentions);
            Ok(PreparedExecutionHandle { prepared })
        }
        .await;
        // File-service shutdown retries cleanup and reports its final result.
        let _ = files.collect_snapshots().await;
        result
    }
}

fn task_environment(
    values: Vec<PythonTaskEnvironment>,
) -> Result<BTreeMap<String, EnvironmentValue>, String> {
    let mut environment = BTreeMap::new();
    let mut names = HashSet::new();
    for variable in values {
        let name = if cfg!(windows) {
            variable.name.to_ascii_uppercase()
        } else {
            variable.name.clone()
        };
        if name == INPUTS_VARIABLE {
            return Err(task_error(
                "invalidSpec",
                "SKED_INPUTS_JSON is supplied by the Python task.",
            ));
        }
        if !names.insert(name) {
            return Err(task_error(
                "invalidSpec",
                "Python environment variable names must be unique.",
            ));
        }
        environment.insert(variable.name, EnvironmentValue::Plain(variable.value));
    }
    Ok(environment)
}

fn local_resource(path: &Path) -> Result<FileResourceRef, StorageError> {
    let kind = if cfg!(windows) {
        FileResourceKind::WindowsPath
    } else if cfg!(target_os = "android") {
        FileResourceKind::AndroidPath
    } else {
        return Err(StorageError::Invalid(
            "Local execution inputs are unavailable on this platform.".into(),
        ));
    };
    Ok(FileResourceRef {
        kind,
        value: path
            .to_str()
            .ok_or_else(|| {
                StorageError::Invalid(
                    "The attachment path cannot be represented as Unicode.".into(),
                )
            })?
            .to_owned(),
    })
}

fn task_error(code: &str, message: impl Into<String>) -> String {
    serde_json::json!({"code": code, "message": message.into()}).to_string()
}

fn resource_version(version: FileVersion) -> ResourceVersion {
    ResourceVersion {
        resource_id: version.resource_id,
        version: version.version,
        digest: version.sha256,
        byte_length: version.byte_length,
    }
}
