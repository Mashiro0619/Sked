use std::path::PathBuf;

use async_trait::async_trait;
use serde_json::Value;

use super::PERSISTENCE_SERVICE;
use crate::{
    plugins::{
        Plugin, PluginContext, PluginDescriptor, PluginError, UiContributionDefinition,
        UiContributionSlot,
    },
    storage::StorageWorker,
};

/// The shipped provider retains one worker and the existing JSONL, SQLite,
/// attachment-reference and durable-receipt implementations.
pub struct DefaultPersistencePlugin;

#[async_trait]
impl Plugin for DefaultPersistencePlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.storage",
            contract_version: 1,
            provides: vec![PERSISTENCE_SERVICE.key()],
            dependencies: vec![],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let root = context
            .config()
            .get("directory")
            .and_then(Value::as_str)
            .ok_or_else(|| PluginError::new("Storage provider requires its data directory"))?;
        let root = PathBuf::from(root);
        let worker = tokio::task::spawn_blocking(move || StorageWorker::open(root))
            .await
            .map_err(|error| PluginError::new(error.to_string()))?
            .map_err(|error| PluginError::new(error.to_string()))?;
        let service = worker.service();
        context.on_dispose(move || {
            Box::pin(async move {
                tokio::task::spawn_blocking(move || worker.shutdown())
                    .await
                    .map_err(|error| PluginError::new(error.to_string()))?
                    .map_err(|error| PluginError::new(error.to_string()))
            })
        })?;
        context.contribute_ui(UiContributionDefinition::builtin(
            UiContributionSlot::InspectorSection,
            "sked.inspector.attachments",
            20,
        ))?;
        context.provide(PERSISTENCE_SERVICE, service)
    }
}
