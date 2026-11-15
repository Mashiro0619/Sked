use std::{
    collections::{BTreeMap, HashSet},
    path::Path,
};

use tokio_util::sync::CancellationToken;

use super::{
    AgentCore,
    execution_contracts::{PythonTaskInput, TaskInputSourceKind},
};
use crate::{
    execution::{InputSnapshot, ResourceVersion},
    files::{FileResourceKind, FileResourceRef, FileService, FileVersion, SnapshotRetention},
    storage::StorageError,
};

#[flutter_rust_bridge::frb(ignore)]
pub(super) struct FrozenTaskInputs {
    pub inputs: Vec<InputSnapshot>,
    pub paths: BTreeMap<String, String>,
    pub retentions: Vec<SnapshotRetention>,
}

pub(super) async fn freeze_task_inputs(
    core: &AgentCore,
    files: &FileService,
    conversation_id: String,
    requested: Vec<PythonTaskInput>,
    cancellation: CancellationToken,
) -> Result<FrozenTaskInputs, String> {
    let mut names = HashSet::new();
    if requested.iter().any(|input| !names.insert(&input.name)) {
        return Err(task_error(
            "invalidSpec",
            "Task input names must be unique.",
        ));
    }
    drop(names);
    let input_files = files.clone();
    let input_cancellation = cancellation.clone();
    core.storage()
        .call(move |store| {
            let conversation = store
                .read_uncached(&conversation_id)?
                .ok_or_else(|| StorageError::NotFound(conversation_id.clone()))?;
            let mut inputs = Vec::new();
            let mut paths = BTreeMap::new();
            let mut retentions = Vec::new();
            for input in requested {
                let mut messages = conversation.messages.iter().chain(
                    conversation
                        .history_versions
                        .iter()
                        .flat_map(|version| &version.messages),
                );
                let (attachment_id, source_kind) = match input.source.kind {
                    TaskInputSourceKind::Content => {
                        let reference = messages
                            .flat_map(|message| &message.tool_content_refs)
                            .find(|reference| reference.id == input.source.id)
                            .ok_or_else(|| StorageError::NotFound(input.source.id.clone()))?;
                        (&reference.attachment_id, "content")
                    }
                    TaskInputSourceKind::Attachment => {
                        if !messages
                            .any(|message| message.attachment_ids.contains(&input.source.id))
                        {
                            return Err(StorageError::NotFound(input.source.id.clone()));
                        }
                        (&input.source.id, "attachment")
                    }
                };
                let attachment = conversation
                    .attachments
                    .iter()
                    .find(|attachment| &attachment.id == attachment_id)
                    .ok_or_else(|| StorageError::NotFound(attachment_id.clone()))?;
                let source = local_resource(&store.attachment_path(attachment)?)?;
                // Keep collection outside the storage job until the complete
                // saved attachment has been copied and sealed.
                let (snapshot, retention) = futures::executor::block_on(
                    input_files.snapshot_retained(source, input_cancellation.clone(), |_| {}),
                )
                .map_err(|error| StorageError::Invalid(error.to_string()))?;
                if snapshot.content_version.byte_length != Some(attachment.byte_length)
                    || !snapshot
                        .content_version
                        .sha256
                        .as_ref()
                        .is_some_and(|digest| digest.eq_ignore_ascii_case(&attachment.sha256))
                {
                    return Err(StorageError::Invalid(
                        "The task input differs from its saved attachment.".into(),
                    ));
                }
                let mut version = resource_version(snapshot.content_version);
                version.resource_id = snapshot.id;
                paths.insert(input.name, snapshot.content.value.clone());
                inputs.push(InputSnapshot {
                    source: ResourceVersion {
                        resource_id: format!(
                            "conversation:{conversation_id}:{source_kind}:{}",
                            input.source.id
                        ),
                        version: attachment.sha256.clone(),
                        digest: Some(attachment.sha256.clone()),
                        byte_length: Some(attachment.byte_length),
                    },
                    snapshot: version,
                    mounted_path: snapshot.content.value,
                });
                retentions.push(retention);
            }
            Ok(FrozenTaskInputs {
                inputs,
                paths,
                retentions,
            })
        })
        .await
        .map_err(|error| {
            task_error(
                if core.closing.is_cancelled() || cancellation.is_cancelled() {
                    "cancelledBeforeStart"
                } else {
                    "storageFailure"
                },
                error.to_string(),
            )
        })
}

fn local_resource(path: &Path) -> Result<FileResourceRef, StorageError> {
    let kind = if cfg!(windows) {
        FileResourceKind::WindowsPath
    } else if cfg!(target_os = "android") {
        FileResourceKind::AndroidPath
    } else {
        return Err(StorageError::Invalid(
            "Local task inputs are unavailable on this platform.".into(),
        ));
    };
    Ok(FileResourceRef {
        kind,
        value: path
            .to_str()
            .ok_or_else(|| StorageError::Invalid("The attachment path is not Unicode.".into()))?
            .to_owned(),
    })
}

pub(super) fn task_error(code: &str, message: impl Into<String>) -> String {
    serde_json::json!({"code": code, "message": message.into()}).to_string()
}

pub(super) fn resource_version(version: FileVersion) -> ResourceVersion {
    ResourceVersion {
        resource_id: version.resource_id,
        version: version.version,
        digest: version.sha256,
        byte_length: version.byte_length,
    }
}
