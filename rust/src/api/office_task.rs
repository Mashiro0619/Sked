use tokio_util::sync::CancellationToken;

use super::{
    AgentCore,
    execution::{ExecutionPreparationCancellation, PreparedExecutionHandle},
    execution_contracts::{OfficeDocumentFormat, OfficeReadTaskRequest, PythonTaskInput},
    task_inputs::{freeze_task_inputs, task_error},
};
use crate::execution::{ControlledReadSpec, ExecutionSpec};

impl AgentCore {
    /// Freeze an existing conversation file for the provider's fixed reader.
    pub async fn prepare_office_read_task(
        &self,
        conversation_id: String,
        request: OfficeReadTaskRequest,
        cancellation: &ExecutionPreparationCancellation,
    ) -> Result<PreparedExecutionHandle, String> {
        let cancellation: CancellationToken = cancellation.token.clone();
        if self.closing.is_cancelled() || cancellation.is_cancelled() {
            return Err(task_error(
                "cancelledBeforeStart",
                "Office reading was cancelled.",
            ));
        }
        let execution = self.profile.execution_service().ok_or_else(|| {
            task_error(
                "providerUnavailable",
                "No document execution provider is available.",
            )
        })?;
        let files = self
            .profile
            .file_service()
            .ok_or_else(|| task_error("providerUnavailable", "No file provider is available."))?;
        let result = async {
            let frozen = freeze_task_inputs(
                self,
                &files,
                conversation_id,
                vec![PythonTaskInput {
                    name: "document".into(),
                    source: request.source,
                }],
                cancellation.clone(),
            )
            .await?;
            let format = match request.format {
                OfficeDocumentFormat::Docx => "docx",
                OfficeDocumentFormat::Xlsx => "xlsx",
                OfficeDocumentFormat::Pptx => "pptx",
            };
            let prepared = execution
                .prepare_cancellable(
                    ExecutionSpec::ControlledRead(ControlledReadSpec {
                        reader_id: "office.inspect".into(),
                        arguments: serde_json::json!({"format": format}),
                        inputs: frozen.inputs,
                    }),
                    cancellation,
                )
                .await
                .map_err(|error| task_error(error.code.as_str(), error.message))?;
            drop(frozen.retentions);
            Ok(PreparedExecutionHandle { prepared })
        }
        .await;
        let _ = files.collect_snapshots().await;
        result
    }
}
