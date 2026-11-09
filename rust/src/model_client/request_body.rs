use std::{fs::File, io};

use base64::{Engine, engine::general_purpose::STANDARD};
use futures::{Stream, StreamExt};
use rig::http_client::Bytes;
use serde_json::Value;
use sha2::{Digest, Sha256};
use tokio::io::AsyncReadExt;
use tokio_util::sync::CancellationToken;

/// An already-open private file remains readable while collection removes an
/// unrelated reference. It never exposes a path to the provider.
pub struct RequestFile {
    pub token: String,
    pub file: File,
    pub byte_length: u64,
    pub sha256: String,
    pub prefix: String,
}

enum BodyPart {
    Bytes(Vec<u8>),
    File(RequestFile),
}

pub struct PreparedRequestBody {
    parts: Vec<BodyPart>,
    pub content_length: u64,
}

impl PreparedRequestBody {
    pub fn json(body: Value) -> Result<Self, String> {
        Self::with_files(body, Vec::new())
    }

    pub fn with_files(body: Value, files: Vec<RequestFile>) -> Result<Self, String> {
        let bytes = serde_json::to_vec(&body).map_err(|error| error.to_string())?;
        let mut replacements = Vec::new();
        for file in files {
            let marker = serde_json::to_vec(&file.token).map_err(|error| error.to_string())?;
            let offset = bytes
                .windows(marker.len())
                .position(|part| part == marker)
                .ok_or_else(|| "附件请求占位符缺失".to_string())?;
            if bytes.windows(marker.len()).rposition(|part| part == marker) != Some(offset) {
                return Err("附件请求占位符重复".into());
            }
            replacements.push((offset, marker.len(), file));
        }
        replacements.sort_by_key(|(offset, _, _)| *offset);
        let mut parts = Vec::new();
        let mut cursor = 0;
        for (offset, marker_length, file) in replacements {
            if offset < cursor {
                return Err("附件请求占位符重叠".into());
            }
            parts.push(BodyPart::Bytes(bytes[cursor..offset].to_vec()));
            let mut prefix = serde_json::to_vec(&file.prefix).map_err(|error| error.to_string())?;
            prefix.pop();
            parts.push(BodyPart::Bytes(prefix));
            parts.push(BodyPart::File(file));
            parts.push(BodyPart::Bytes(vec![b'"']));
            cursor = offset + marker_length;
        }
        parts.push(BodyPart::Bytes(bytes[cursor..].to_vec()));
        let mut content_length = 0_u64;
        for part in &parts {
            let length = match part {
                BodyPart::Bytes(bytes) => bytes.len() as u64,
                BodyPart::File(file) => file
                    .byte_length
                    .checked_add(2)
                    .and_then(|length| (length / 3).checked_mul(4))
                    .ok_or_else(|| "附件请求长度溢出".to_string())?,
            };
            content_length = content_length
                .checked_add(length)
                .ok_or_else(|| "附件请求长度溢出".to_string())?;
        }
        Ok(Self {
            parts,
            content_length,
        })
    }

    pub fn into_stream(
        self,
        cancellation: CancellationToken,
    ) -> impl Stream<Item = io::Result<Bytes>> + Send + 'static {
        async_stream::try_stream! {
            for part in self.parts {
                check_cancelled(&cancellation)?;
                match part {
                    BodyPart::Bytes(bytes) => {
                        if !bytes.is_empty() { yield Bytes::from(bytes); }
                    }
                    BodyPart::File(expected) => {
                        let mut file = tokio::fs::File::from_std(expected.file);
                        let mut buffer = vec![0_u8; 65536];
                        let mut carry = Vec::with_capacity(65538);
                        let mut length = 0_u64;
                        let mut digest = Sha256::new();
                        loop {
                            let count = tokio::select! {
                                biased;
                                _ = cancellation.cancelled() => Err(cancelled()),
                                result = file.read(&mut buffer) => result,
                            }?;
                            if count == 0 { break; }
                            length += count as u64;
                            if length > expected.byte_length {
                                Err(io::Error::new(io::ErrorKind::InvalidData, "attachment_corrupt: 附件长度已改变"))?;
                            }
                            digest.update(&buffer[..count]);
                            carry.extend_from_slice(&buffer[..count]);
                            let complete = carry.len() / 3 * 3;
                            if complete > 0 {
                                yield Bytes::from(STANDARD.encode(&carry[..complete]));
                                carry.drain(..complete);
                            }
                        }
                        check_cancelled(&cancellation)?;
                        if length != expected.byte_length ||
                            !expected.sha256.eq_ignore_ascii_case(&format!("{:x}", digest.finalize())) {
                            Err(io::Error::new(io::ErrorKind::InvalidData, "attachment_corrupt: 附件长度或摘要已改变"))?;
                        }
                        if !carry.is_empty() { yield Bytes::from(STANDARD.encode(&carry)); }
                    }
                }
            }
        }
    }

    /// Scripted transports consume the exact stream used by real HTTP uploads.
    pub async fn collect(self, cancellation: CancellationToken) -> io::Result<Bytes> {
        let stream = self.into_stream(cancellation);
        futures::pin_mut!(stream);
        let mut bytes = Vec::new();
        while let Some(chunk) = stream.next().await {
            bytes.extend_from_slice(&chunk?);
        }
        Ok(bytes.into())
    }
}

fn cancelled() -> io::Error {
    io::Error::new(io::ErrorKind::Interrupted, "模型请求已取消")
}
fn check_cancelled(cancellation: &CancellationToken) -> io::Result<()> {
    if cancellation.is_cancelled() {
        Err(cancelled())
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[tokio::test]
    async fn streamed_file_preserves_json_length_and_rejects_corruption() {
        let directory = std::env::temp_dir().join(format!("sked-body-{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&directory).unwrap();
        let path = directory.join("payload.bin");
        let payload: Vec<u8> = (0..65539).map(|index| (index % 251) as u8).collect();
        std::fs::write(&path, &payload).unwrap();
        let digest = format!("{:x}", Sha256::digest(&payload));
        let body = json!({"input":[{"role":"user","content":[{
            "type":"input_file", "filename":"资料 \"one\".pdf", "file_data":"body-file"
        }]}]});
        let file = || RequestFile {
            token: "body-file".into(),
            file: File::open(&path).unwrap(),
            byte_length: payload.len() as u64,
            sha256: digest.clone(),
            prefix: "data:application/pdf;base64,".into(),
        };
        let plan = PreparedRequestBody::with_files(body.clone(), vec![file()]).unwrap();
        let expected_length = plan.content_length;
        let bytes = plan.collect(CancellationToken::new()).await.unwrap();
        assert_eq!(bytes.len() as u64, expected_length);
        let decoded: Value = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(
            decoded["input"][0]["content"][0]["filename"],
            "资料 \"one\".pdf"
        );
        assert_eq!(
            decoded["input"][0]["content"][0]["file_data"],
            format!("data:application/pdf;base64,{}", STANDARD.encode(&payload))
        );

        let plan = PreparedRequestBody::with_files(body.clone(), vec![file()]).unwrap();
        let cancellation = CancellationToken::new();
        cancellation.cancel();
        assert_eq!(
            plan.collect(cancellation).await.unwrap_err().kind(),
            io::ErrorKind::Interrupted
        );

        let mut corrupt = payload.clone();
        corrupt[32768] ^= 1;
        std::fs::write(&path, corrupt).unwrap();
        let plan = PreparedRequestBody::with_files(body, vec![file()]).unwrap();
        assert_eq!(
            plan.collect(CancellationToken::new())
                .await
                .unwrap_err()
                .kind(),
            io::ErrorKind::InvalidData
        );
        std::fs::remove_dir_all(directory).unwrap();
    }
}
