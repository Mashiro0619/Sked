use base64::{Engine, engine::general_purpose::STANDARD};
use rig::message::{
    Document, DocumentData, DocumentMediaType, DocumentSourceKind, Message as ProviderMessage,
    UserContent,
};
use serde_json::Value;
use sha2::{Digest, Sha256};

use crate::storage::models::AttachmentMetadata;

pub(crate) fn archive_history(
    values: Vec<Value>,
    attachments: &[AttachmentMetadata],
) -> crate::storage::Result<Vec<Value>> {
    values
        .into_iter()
        .map(|value| {
            let mut message: ProviderMessage = serde_json::from_value(value)?;
            if let ProviderMessage::User { content } = &mut message {
                for content in content {
                    match content {
                        UserContent::Image(image) => {
                            archive_attachment_source(&mut image.data, attachments, false);
                        }
                        UserContent::Audio(audio) => {
                            archive_attachment_source(&mut audio.data, attachments, true);
                        }
                        UserContent::Document(Document {
                            data: DocumentData::File(source),
                            media_type,
                            ..
                        }) => {
                            if archive_attachment_source(
                                source,
                                attachments,
                                *media_type == Some(DocumentMediaType::PDF),
                            ) {
                                *media_type = Some(DocumentMediaType::PDF);
                            }
                        }
                        _ => {}
                    }
                }
            }
            Ok(serde_json::to_value(message)?)
        })
        .collect()
}

pub(crate) fn attachment_source(content: &UserContent) -> Option<&DocumentSourceKind> {
    match content {
        UserContent::Image(image) => Some(&image.data),
        UserContent::Audio(audio) => Some(&audio.data),
        UserContent::Document(Document {
            data: DocumentData::File(source),
            ..
        }) => Some(source),
        _ => None,
    }
}

pub(crate) fn attachment_source_id(source: &DocumentSourceKind) -> Option<&str> {
    match source {
        DocumentSourceKind::Url(value) | DocumentSourceKind::Base64(value) => {
            value.strip_prefix("sked-attachment://")
        }
        _ => None,
    }
}

fn archive_attachment_source(
    source: &mut DocumentSourceKind,
    attachments: &[AttachmentMetadata],
    use_base64: bool,
) -> bool {
    let original_id = attachment_source_id(source).map(str::to_owned);
    let digest = match source {
        _ if original_id.is_some() => None,
        DocumentSourceKind::Raw(bytes) => Some(format!("{:x}", Sha256::digest(bytes))),
        DocumentSourceKind::Base64(data) => STANDARD
            .decode(data.as_bytes())
            .ok()
            .map(|bytes| format!("{:x}", Sha256::digest(bytes))),
        _ => None,
    };
    let metadata = attachments.iter().find(|attachment| {
        original_id.as_ref().map_or_else(
            || digest.as_ref() == Some(&attachment.sha256),
            |id| &attachment.id == id,
        )
    });
    let pdf = metadata.is_some_and(|metadata| metadata.media_type == "application/pdf");
    if let Some(id) = original_id.or_else(|| metadata.map(|metadata| metadata.id.clone())) {
        let marker = format!("sked-attachment://{id}");
        // Normalize existing URL markers as well as legacy inline content.
        // JSONL keeps the marker itself, never the encoded file bytes.
        *source = if use_base64 || pdf {
            DocumentSourceKind::Base64(marker)
        } else {
            DocumentSourceKind::Url(marker)
        };
    }
    pdf
}
