use std::io::{Cursor, Read};

use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio_util::sync::CancellationToken;

use super::*;
use crate::storage::services::PersistenceStore;

pub(super) enum PreparedToolContent {
    Copy {
        reader: Box<dyn Read + Send>,
        metadata: AttachmentMetadata,
        reference: ToolContentRef,
    },
    Saved {
        content_id: String,
        format: Option<String>,
        offset: u64,
        length: u64,
    },
}

impl RuntimeManager {
    pub(super) async fn prepare_tool_content(
        &self,
        message_id: &str,
        offered: Vec<HostModelContent>,
        cancellation: &CancellationToken,
    ) -> Result<Vec<PreparedToolContent>> {
        let mut prepared = Vec::new();
        for (index, offer) in offered.into_iter().enumerate() {
            if cancellation.is_cancelled() {
                return Err(RuntimeError::Cancelled("工具内容保存已取消".into()));
            }
            let id = format!("{message_id}:content:{index}");
            let attachment_id = format!("tool-{:x}", Sha256::digest(id.as_bytes()));
            let (reader, metadata, reference): (Box<dyn Read + Send>, _, _) = match offer {
                HostModelContent::Text { text, name } => {
                    let bytes = text.into_bytes();
                    let metadata = AttachmentMetadata {
                        id: attachment_id.clone(),
                        name,
                        media_type: "text/plain".into(),
                        byte_length: bytes.len() as u64,
                        sha256: format!("{:x}", Sha256::digest(&bytes)),
                        created_at: now_ms(),
                    };
                    let reference = ToolContentRef {
                        id,
                        attachment_id: metadata.id.clone(),
                        kind: ToolContentKind::Text,
                        ..Default::default()
                    };
                    (Box::new(Cursor::new(bytes)), metadata, reference)
                }
                HostModelContent::Snapshot {
                    snapshot_id,
                    name,
                    media_type,
                    byte_length,
                    sha256,
                    text_range,
                } => {
                    let media_type = media_type.trim().to_ascii_lowercase();
                    let files = self
                        .inner
                        .files
                        .as_ref()
                        .ok_or_else(|| RuntimeError::Invalid("文件快照服务不可用".into()))?;
                    let lease = files
                        .lease_snapshot(snapshot_id.clone(), cancellation.clone())
                        .await
                        .map_err(|error| RuntimeError::Invalid(error.to_string()))?;
                    let captured = lease.metadata();
                    if captured.id != snapshot_id
                        || captured.content_version.byte_length != Some(byte_length)
                        || captured
                            .content_version
                            .sha256
                            .as_deref()
                            .is_none_or(|digest| !digest.eq_ignore_ascii_case(&sha256))
                    {
                        return Err(RuntimeError::Invalid(
                            "工具内容与原不可变快照的长度或摘要不一致".into(),
                        ));
                    }
                    if captured.media_type.as_deref().is_some_and(|captured| {
                        !captured.trim().is_empty()
                            && !captured.eq_ignore_ascii_case("application/octet-stream")
                            && !captured.eq_ignore_ascii_case(&media_type)
                    }) {
                        return Err(RuntimeError::Invalid(
                            "工具内容的媒体类型与原快照不一致".into(),
                        ));
                    }
                    if text_range.is_some_and(|range| {
                        range
                            .offset
                            .checked_add(range.length)
                            .is_none_or(|end| end > byte_length)
                    }) {
                        return Err(RuntimeError::Invalid("工具文本范围超过原快照长度".into()));
                    }
                    let metadata = AttachmentMetadata {
                        id: attachment_id,
                        name,
                        media_type,
                        byte_length,
                        sha256: sha256.to_ascii_lowercase(),
                        created_at: now_ms(),
                    };
                    let reference = ToolContentRef {
                        id,
                        attachment_id: metadata.id.clone(),
                        kind: if text_range.is_some() {
                            ToolContentKind::Text
                        } else {
                            ToolContentKind::Native
                        },
                        source_snapshot_id: Some(snapshot_id),
                        source_resource: captured.source.clone(),
                        source_version: captured.source_version.clone(),
                        text_range,
                    };
                    (Box::new(lease), metadata, reference)
                }
            };
            if metadata.name.trim().is_empty() || metadata.media_type.trim().is_empty() {
                return Err(RuntimeError::Invalid("工具内容缺少名称或媒体类型".into()));
            }
            prepared.push(PreparedToolContent::Copy {
                reader,
                metadata,
                reference,
            });
        }
        Ok(prepared)
    }

    pub(super) async fn read_saved_content(
        &self,
        accepted: &AcceptedRun,
        call_id: &str,
        args: Value,
    ) -> Result<Value> {
        let fields = args
            .as_object()
            .ok_or_else(|| RuntimeError::Invalid("工具参数必须是对象".into()))?;
        if fields
            .keys()
            .any(|key| !matches!(key.as_str(), "contentId" | "format" | "offset" | "length"))
        {
            return Err(RuntimeError::Invalid("content.read 包含未知参数".into()));
        }
        let content_id = fields
            .get("contentId")
            .and_then(Value::as_str)
            .filter(|id| !id.is_empty())
            .ok_or_else(|| RuntimeError::Invalid("contentId: 内容身份不能为空".into()))?
            .to_owned();
        let format = fields
            .get("format")
            .map(|value| {
                value
                    .as_str()
                    .filter(|value| matches!(*value, "text" | "native"))
                    .map(str::to_owned)
                    .ok_or_else(|| RuntimeError::Invalid("format: 使用 text 或 native".into()))
            })
            .transpose()?;
        let number = |key: &str, fallback: u64| -> Result<u64> {
            fields.get(key).map_or(Ok(fallback), |value| {
                value
                    .as_u64()
                    .ok_or_else(|| RuntimeError::Invalid(format!("{key}: 必须是非负整数")))
            })
        };
        let offset = number("offset", 0)?;
        let length = number("length", 32768)?;
        if length == 0 {
            return Err(RuntimeError::Invalid("length: 必须大于零".into()));
        }
        let result = HostToolResult {
            model_payload: json!({"status":"read", "sourceContentId":content_id}),
            details: json!({"sourceContentId":content_id}),
            ..Default::default()
        };
        self.save_prepared_tool_result(
            &accepted.conversation_id,
            &accepted.run_id,
            "content.read",
            call_id,
            result,
            vec![PreparedToolContent::Saved {
                content_id,
                format,
                offset,
                length,
            }],
            accepted.control.cancellation.clone(),
        )
        .await
    }
}

fn find_content<'a>(snapshot: &'a ConversationSnapshot, id: &str) -> Option<&'a ToolContentRef> {
    snapshot
        .messages
        .iter()
        .chain(
            snapshot
                .history_versions
                .iter()
                .flat_map(|version| &version.messages),
        )
        .flat_map(|message| &message.tool_content_refs)
        .find(|reference| reference.id == id)
}

pub(super) fn read_content_text(
    store: &dyn PersistenceStore,
    metadata: &AttachmentMetadata,
    reference: &ToolContentRef,
    cancellation: &CancellationToken,
) -> crate::storage::Result<String> {
    let range = reference.text_range.unwrap_or(ToolContentRange {
        offset: 0,
        length: metadata.byte_length,
    });
    let bytes = store.read_attachment_range(metadata, range.offset, range.length, cancellation)?;
    if bytes.len() as u64 != range.length {
        return Err(StorageError::Invalid("工具内容范围超过原文件长度".into()));
    }
    String::from_utf8(bytes)
        .map_err(|_| StorageError::Invalid("工具文本内容不是完整 UTF-8 正文".into()))
}

pub(super) fn admit_tool_content(
    store: &mut dyn PersistenceStore,
    snapshot: &ConversationSnapshot,
    message_id: &str,
    prepared: &mut [PreparedToolContent],
    cancellation: &CancellationToken,
) -> crate::storage::Result<(Vec<ToolContentRef>, Vec<AttachmentMetadata>)> {
    let mut references = Vec::new();
    let mut attachments = Vec::new();
    for (index, input) in prepared.iter_mut().enumerate() {
        let (reference, metadata) = match input {
            PreparedToolContent::Copy {
                reader,
                metadata,
                reference,
            } => {
                let mut metadata = metadata.clone();
                if let Some(previous) = snapshot
                    .attachments
                    .iter()
                    .find(|saved| saved.id == metadata.id)
                {
                    metadata.created_at = previous.created_at;
                    if previous != &metadata {
                        return Err(StorageError::Conflict("工具内容身份已绑定其他文件".into()));
                    }
                }
                let metadata =
                    store.copy_tool_attachment(reader.as_mut(), metadata, cancellation)?;
                if reference.kind == ToolContentKind::Text {
                    read_content_text(store, &metadata, reference, cancellation)?;
                }
                (reference.clone(), metadata)
            }
            PreparedToolContent::Saved {
                content_id,
                format,
                offset,
                length,
            } => {
                let original = find_content(snapshot, content_id)
                    .ok_or_else(|| StorageError::NotFound(format!("contentId: {content_id}")))?;
                let metadata = snapshot
                    .attachments
                    .iter()
                    .find(|metadata| metadata.id == original.attachment_id)
                    .ok_or_else(|| StorageError::NotFound(original.attachment_id.clone()))?
                    .clone();
                let kind = match format.as_deref() {
                    Some("text") => ToolContentKind::Text,
                    Some("native") => ToolContentKind::Native,
                    _ => original.kind,
                };
                let text_range = if kind == ToolContentKind::Text {
                    let bytes = store.read_attachment_range(
                        &metadata,
                        *offset,
                        (*length).max(4),
                        cancellation,
                    )?;
                    let consumed = match std::str::from_utf8(&bytes) {
                        Ok(_) => bytes.len(),
                        Err(error)
                            if error.error_len().is_none()
                                && offset.saturating_add(bytes.len() as u64)
                                    < metadata.byte_length =>
                        {
                            error.valid_up_to()
                        }
                        Err(_) => {
                            return Err(StorageError::Invalid(
                                "所选内容范围不是 UTF-8 文本，请使用有效的字节偏移".into(),
                            ));
                        }
                    };
                    if consumed == 0 && *offset < metadata.byte_length {
                        return Err(StorageError::Invalid(
                            "内容范围未包含完整 UTF-8 字符".into(),
                        ));
                    }
                    Some(ToolContentRange {
                        offset: *offset,
                        length: consumed as u64,
                    })
                } else {
                    if *offset != 0 {
                        return Err(StorageError::Invalid(
                            "原生媒体内容必须从完整文件发送".into(),
                        ));
                    }
                    store.read_attachment_range(&metadata, 0, 0, cancellation)?;
                    None
                };
                (
                    ToolContentRef {
                        id: format!("{message_id}:content:{index}"),
                        kind,
                        text_range,
                        ..original.clone()
                    },
                    metadata,
                )
            }
        };
        references.push(reference);
        attachments.push(metadata);
    }
    Ok((references, attachments))
}

pub(super) fn attach_content_payload(
    payload: &mut Value,
    references: &[ToolContentRef],
    attachments: &[AttachmentMetadata],
) {
    if references.is_empty() {
        return;
    }
    if !payload.is_object() {
        *payload = json!({"result":payload.take()});
    }
    payload["modelContent"] =
        json!(references.iter().zip(attachments).map(|(reference, metadata)| {
        let next_offset = reference.text_range.and_then(|range| {
            let end = range.offset.checked_add(range.length)?;
            (end < metadata.byte_length).then_some(end)
        });
        json!({"contentId":reference.id,"name":metadata.name,"mediaType":metadata.media_type,
            "byteLength":metadata.byte_length,"sha256":metadata.sha256,"kind":reference.kind,
            "textRange":reference.text_range,"nextOffset":next_offset,
            "readTool":"content.read"})
    }).collect::<Vec<_>>());
}

pub(crate) fn content_delivery_error(result: &mut HostToolResult, error: impl ToString) {
    let error = error.to_string();
    if !result.model_payload.is_object() {
        result.model_payload = json!({"result":result.model_payload.take()});
    }
    result.model_payload["contentDelivery"] = json!({"status":"failed", "message":error});
    if !result.details.is_object() {
        result.details = json!({"result":result.details.take()});
    }
    result.details["contentDelivery"] = json!({"status":"failed", "message":error});
}
