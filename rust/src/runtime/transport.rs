use futures::future::BoxFuture;
use serde_json::Value;
use tokio_util::sync::CancellationToken;

use super::*;
use crate::model_client::{
    ConnectionIdentity, ModelToolExecutor, PreparedRequestBody, ProviderProtocol, RequestFile,
};

include!("attachment_media.rs");

struct TransportExecutor {
    manager: RuntimeManager,
    conversation_id: String,
    run_id: Option<String>,
    connection: ConnectionIdentity,
    inner: Arc<dyn ModelToolExecutor>,
}

impl RuntimeManager {
    pub(super) fn transport_executor(
        &self,
        conversation_id: String,
        run_id: Option<String>,
        config: ConnectionConfig,
        inner: Arc<dyn ModelToolExecutor>,
    ) -> Arc<dyn ModelToolExecutor> {
        Arc::new(TransportExecutor {
            manager: self.clone(),
            conversation_id,
            run_id,
            connection: ConnectionIdentity::from_config(&config),
            inner,
        })
    }

    async fn authorize_connection(
        &self,
        conversation_id: String,
        run_id: Option<String>,
        connection: ConnectionIdentity,
        cancellation: CancellationToken,
    ) -> std::result::Result<(), String> {
        if cancellation.is_cancelled() {
            return Err("用户已停止本次运行".into());
        }
        let snapshot = self
            .read(&conversation_id)
            .await
            .map_err(|error| error.to_string())?;
        if snapshot.conversation.archived
            || run_id
                .as_ref()
                .is_some_and(|id| snapshot.conversation.run_id.as_ref() != Some(id))
        {
            return Err("HTTP 请求所属会话已改变".into());
        }
        let mode = snapshot.conversation.mode;
        if connection.endpoint.starts_with("https://") || mode == PermissionMode::Full {
            return Ok(());
        }
        let approved = self
            .inner
            .host
            .authorize_connection(
                HostConnectionRequest {
                    conversation_id: conversation_id.clone(),
                    run_id: run_id.clone(),
                    connection,
                    permission_mode: mode,
                },
                cancellation.clone(),
            )
            .await
            .map_err(|error| error.to_string())?;
        if cancellation.is_cancelled() {
            return Err("用户已停止本次运行".into());
        }
        let current = self
            .read(&conversation_id)
            .await
            .map_err(|error| error.to_string())?;
        if current.conversation.archived
            || run_id
                .as_ref()
                .is_some_and(|id| current.conversation.run_id.as_ref() != Some(id))
        {
            return Err("HTTP 请求所属会话已改变".into());
        }
        if current.conversation.mode == PermissionMode::Full {
            return Ok(());
        }
        if current.conversation.mode != mode {
            return Err("权限模式已改变，请重新确认 HTTP 传输".into());
        }
        if !approved {
            return Err("HTTP 传输未获允许，请求未发送".into());
        }
        Ok(())
    }
}

impl ModelToolExecutor for TransportExecutor {
    fn validate_input(
        &self,
        input: Vec<Value>,
        protocol: ProviderProtocol,
    ) -> BoxFuture<'static, std::result::Result<(), String>> {
        let manager = self.manager.clone();
        let id = self.conversation_id.clone();
        Box::pin(async move {
            let snapshot = manager.read(&id).await.map_err(|error| error.to_string())?;
            for value in input {
                let message: rig::message::Message =
                    serde_json::from_value(value).map_err(|error| error.to_string())?;
                if let rig::message::Message::User { content } = message {
                    for content in content {
                        let Some(source) = context::attachment_source(&content) else {
                            continue;
                        };
                        let Some(id) = context::attachment_source_id(source) else {
                            continue;
                        };
                        let metadata = snapshot
                            .attachments
                            .iter()
                            .find(|attachment| attachment.id == id)
                            .ok_or_else(|| format!("attachment_missing: 附件 {id} 不存在"))?;
                        let media = metadata.media_type.as_str();
                        let allowed = match &content {
                            rig::message::UserContent::Image(_) => matches!(
                                media,
                                "image/png" | "image/jpeg" | "image/gif" | "image/webp"
                            ),
                            rig::message::UserContent::Audio(_) => {
                                protocol == ProviderProtocol::ChatCompletions
                                    && matches!(media, "audio/mpeg" | "audio/wav" | "audio/x-wav")
                            }
                            rig::message::UserContent::Document(_) => {
                                media == "application/pdf"
                                    || (protocol == ProviderProtocol::Responses
                                        && RESPONSES_FILE_MEDIA_TYPES.contains(&media))
                            }
                            _ => false,
                        };
                        if !allowed {
                            return Err(format!(
                                "provider.unsupportedAttachment: {}",
                                metadata.name
                            ));
                        }
                    }
                }
            }
            Ok(())
        })
    }

    fn execute(
        &self,
        name: String,
        call_id: String,
        arguments: Value,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<Value, String>> {
        self.inner.execute(name, call_id, arguments, cancellation)
    }

    fn authorize_request(
        &self,
        connection: ConnectionIdentity,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<(), String>> {
        let manager = self.manager.clone();
        let id = self.conversation_id.clone();
        let run_id = self.run_id.clone();
        let expected = self.connection.clone();
        Box::pin(async move {
            if connection != expected {
                return Err("模型连接在授权前发生改变".into());
            }
            manager
                .authorize_connection(id, run_id, connection, cancellation)
                .await
        })
    }

    fn pause_before_model(&self) -> bool {
        self.inner.pause_before_model()
    }

    fn prepare_request_body(
        &self,
        body: Value,
        protocol: ProviderProtocol,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<PreparedRequestBody, String>> {
        let manager = self.manager.clone();
        let conversation_id = self.conversation_id.clone();
        let expected = self.connection.protocol;
        Box::pin(async move {
            if protocol != expected {
                return Err("附件请求协议已改变".into());
            }
            manager
                .prepare_attachment_request(conversation_id, body, protocol, cancellation)
                .await
        })
    }

    fn active_tools(&self) -> Option<Vec<String>> {
        self.inner.active_tools()
    }

    fn prepare_model(
        &self,
        history: Vec<Value>,
        request_index: usize,
    ) -> BoxFuture<'static, std::result::Result<bool, String>> {
        self.inner.prepare_model(history, request_index)
    }
}

#[derive(Clone, Copy)]
enum AttachmentPart {
    ChatImage,
    ResponseImage,
    Audio,
    ChatFile,
    ResponseFile,
}

impl RuntimeManager {
    async fn prepare_attachment_request(
        &self,
        conversation_id: String,
        mut body: Value,
        protocol: ProviderProtocol,
        cancellation: CancellationToken,
    ) -> std::result::Result<PreparedRequestBody, String> {
        let root = if protocol == ProviderProtocol::Responses {
            "input"
        } else {
            "messages"
        };
        let mut markers = Vec::new();
        if let Some(messages) = body.get(root).and_then(Value::as_array) {
            for (message_index, message) in messages.iter().enumerate() {
                if message.get("role").and_then(Value::as_str) != Some("user") {
                    continue;
                }
                let Some(parts) = message.get("content").and_then(Value::as_array) else {
                    continue;
                };
                for (part_index, part) in parts.iter().enumerate() {
                    let source = match part.get("type").and_then(Value::as_str) {
                        Some("image_url") => part
                            .pointer("/image_url/url")
                            .and_then(Value::as_str)
                            .map(|value| (AttachmentPart::ChatImage, value)),
                        Some("input_image") => part
                            .get("image_url")
                            .and_then(Value::as_str)
                            .map(|value| (AttachmentPart::ResponseImage, value)),
                        Some("input_audio") => part
                            .pointer("/input_audio/data")
                            .and_then(Value::as_str)
                            .map(|value| (AttachmentPart::Audio, value)),
                        Some("file") => part
                            .pointer("/file/file_data")
                            .and_then(Value::as_str)
                            .map(|value| (AttachmentPart::ChatFile, value)),
                        Some("input_file") => part
                            .get("file_url")
                            .and_then(Value::as_str)
                            .map(|value| (AttachmentPart::ResponseFile, value)),
                        _ => None,
                    };
                    if let Some((kind, source)) = source {
                        if let Some(id) = source.strip_prefix("sked-attachment://") {
                            markers.push((
                                format!("/{root}/{message_index}/content/{part_index}"),
                                kind,
                                id.to_owned(),
                            ));
                        }
                    }
                }
            }
        }
        if markers.is_empty() {
            return PreparedRequestBody::json(body);
        }
        let snapshot = self
            .read(&conversation_id)
            .await
            .map_err(|error| error.to_string())?;
        let mut files = Vec::new();
        for (pointer, kind, id) in markers {
            if cancellation.is_cancelled() {
                return Err("模型请求已取消".into());
            }
            let metadata = snapshot
                .attachments
                .iter()
                .find(|attachment| attachment.id == id)
                .ok_or_else(|| format!("attachment_missing: 附件 {id} 不存在"))?
                .clone();
            let media = metadata.media_type.as_str();
            let allowed = match kind {
                AttachmentPart::ChatImage | AttachmentPart::ResponseImage => matches!(
                    media,
                    "image/png" | "image/jpeg" | "image/gif" | "image/webp"
                ),
                AttachmentPart::Audio => {
                    protocol == ProviderProtocol::ChatCompletions
                        && matches!(media, "audio/mpeg" | "audio/wav" | "audio/x-wav")
                }
                AttachmentPart::ChatFile => media == "application/pdf",
                AttachmentPart::ResponseFile => RESPONSES_FILE_MEDIA_TYPES.contains(&media),
            };
            if !allowed {
                return Err(format!("provider.unsupportedAttachment: {}", metadata.name));
            }
            let requested = metadata.clone();
            let file = self
                .inner
                .storage
                .call(move |store| {
                    std::fs::File::open(store.attachment_path(&requested)?)
                        .map_err(StorageError::from)
                })
                .await
                .map_err(|error| error.to_string())?;
            let token = format!("sked-body-{}", new_id());
            let part = body
                .pointer_mut(&pointer)
                .ok_or_else(|| "附件内容块已改变".to_string())?;
            match kind {
                AttachmentPart::ChatImage => {
                    part["image_url"]["url"] = Value::String(token.clone())
                }
                AttachmentPart::ResponseImage => part["image_url"] = Value::String(token.clone()),
                AttachmentPart::Audio => {
                    part["input_audio"]["data"] = Value::String(token.clone());
                    part["input_audio"]["format"] =
                        Value::String(if media == "audio/mpeg" { "mp3" } else { "wav" }.into());
                }
                AttachmentPart::ChatFile => {
                    part["file"]["file_data"] = Value::String(token.clone());
                    part["file"]["filename"] = Value::String(metadata.name.clone());
                }
                AttachmentPart::ResponseFile => {
                    let fields = part
                        .as_object_mut()
                        .ok_or_else(|| "附件内容块格式无效".to_string())?;
                    fields.remove("file_url");
                    fields.insert("file_data".into(), Value::String(token.clone()));
                    fields.insert("filename".into(), Value::String(metadata.name.clone()));
                }
            }
            files.push(RequestFile {
                token,
                file,
                byte_length: metadata.byte_length,
                sha256: metadata.sha256,
                prefix: if matches!(kind, AttachmentPart::Audio) {
                    String::new()
                } else {
                    format!("data:{};base64,", metadata.media_type)
                },
            });
        }
        PreparedRequestBody::with_files(body, files)
    }
}
