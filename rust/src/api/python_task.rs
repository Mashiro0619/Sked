use std::collections::BTreeMap;

use super::{
    AgentCore,
    execution::{ExecutionPreparationCancellation, PreparedExecutionHandle},
    execution_contracts::{PythonTaskEnvironment, PythonTaskRequest},
    task_inputs::{freeze_task_inputs, resource_version, task_error},
};
use crate::{
    execution::{EnvironmentValue, ExecutionSpec, ScriptExecutionSpec, environment_names_equal},
    files::FileKind,
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
        let result = async {
            let frozen = freeze_task_inputs(
                self,
                &files,
                conversation_id,
                request.inputs,
                cancellation.clone(),
            )
            .await?;
            environment.insert(
                INPUTS_VARIABLE.into(),
                EnvironmentValue::Plain(
                    serde_json::to_string(&frozen.paths)
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
                        inputs: frozen.inputs,
                    }),
                    cancellation,
                )
                .await
                .map_err(|error| task_error(error.code.as_str(), error.message))?;
            // The prepared backend now owns its input leases.
            drop(frozen.retentions);
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
    for variable in values {
        if variable.name.contains('\0') {
            return Err(task_error(
                "invalidSpec",
                "An environment variable name cannot contain NUL.",
            ));
        }
        if environment_names_equal(&variable.name, INPUTS_VARIABLE) {
            return Err(task_error(
                "invalidSpec",
                "SKED_INPUTS_JSON is supplied by the Python task.",
            ));
        }
        if environment
            .insert(variable.name, EnvironmentValue::Plain(variable.value))
            .is_some()
        {
            return Err(task_error(
                "invalidSpec",
                "Python environment variable names must be unique.",
            ));
        }
    }
    Ok(environment)
}
