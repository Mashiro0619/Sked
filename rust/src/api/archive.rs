use super::AgentCore;
use crate::storage::StorageError;

fn archive_error(error: StorageError) -> String {
    let code = match error {
        StorageError::Conflict(_) => "archive_conflict",
        StorageError::Invalid(_) | StorageError::Json(_) => "archive_invalid",
        StorageError::NotFound(_) => "archive_missing",
        _ => "archive_unavailable",
    };
    format!("{code}:{error}")
}

impl AgentCore {
    /// Exports native portable records for the shared Dart backup transport.
    /// Omitted selections include all saved records; empty selections include none.
    pub async fn export_archive_json(
        &self,
        conversation_ids: Option<Vec<String>>,
        knowledge_keys: Option<Vec<String>>,
    ) -> Result<String, String> {
        if self.closed.is_cancelled() {
            return Err("Agent core is closed".into());
        }
        self.storage()
            .call(move |store| store.export_archive_json(conversation_ids, knowledge_keys))
            .await
            .map_err(archive_error)
    }

    /// Restores fixed new-format targets under the application's maintenance lease.
    pub async fn import_archive_json(
        &self,
        json: String,
        restore_id: String,
    ) -> Result<(), String> {
        if self.closed.is_cancelled() {
            return Err("Agent core is closed".into());
        }
        self.storage()
            .call(move |store| store.import_archive_json(&json, &restore_id, super::now()))
            .await
            .map_err(archive_error)?;
        self.resync();
        Ok(())
    }

    /// Confirms every target's durable marker using the native serializer.
    pub async fn archive_restore_state(
        &self,
        json: String,
        restore_id: String,
    ) -> Result<bool, String> {
        if self.closed.is_cancelled() {
            return Err("Agent core is closed".into());
        }
        self.storage()
            .call(move |store| store.archive_restore_state(&json, &restore_id))
            .await
            .map_err(archive_error)
    }

    /// Distinguishes an absent restore binary from a corrupt or unreadable one.
    pub async fn attachment_restore_state(
        &self,
        metadata: super::models::ViewAttachmentMetadata,
    ) -> Result<bool, String> {
        let metadata = metadata.try_into()?;
        match self
            .storage()
            .call(move |store| store.verify_attachment(&metadata))
            .await
        {
            Ok(()) => Ok(true),
            Err(StorageError::Io(error)) if error.kind() == std::io::ErrorKind::NotFound => {
                Ok(false)
            }
            Err(StorageError::Invalid(message)) => Err(format!("archive_conflict:{message}")),
            Err(error) => Err(archive_error(error)),
        }
    }
}
