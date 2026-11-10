use base64::{Engine, engine::general_purpose::STANDARD};
use rig::message::{
    Document, DocumentData, DocumentSourceKind, Message as ProviderMessage, UserContent,
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
                            archive_attachment_source(&mut image.data, attachments, false)
                        }
                        UserContent::Audio(audio) => {
                            archive_attachment_source(&mut audio.data, attachments, true)
                        }
                        UserContent::Document(Document {
                            data: DocumentData::File(source),
                            ..
                        }) => archive_attachment_source(source, attachments, false),
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
    audio: bool,
) {
    if attachment_source_id(source).is_some() {
        return;
    }
    let digest = match source {
        DocumentSourceKind::Raw(bytes) => Some(format!("{:x}", Sha256::digest(bytes))),
        DocumentSourceKind::Base64(data) => STANDARD
            .decode(data.as_bytes())
            .ok()
            .map(|bytes| format!("{:x}", Sha256::digest(bytes))),
        _ => None,
    };
    if let Some(metadata) = digest.as_ref().and_then(|digest| {
        attachments
            .iter()
            .find(|attachment| &attachment.sha256 == digest)
    }) {
        let marker = format!("sked-attachment://{}", metadata.id);
        *source = if audio {
            DocumentSourceKind::Base64(marker)
        } else {
            DocumentSourceKind::Url(marker)
        };
    }
}
