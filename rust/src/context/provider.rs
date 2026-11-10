use async_trait::async_trait;

use super::{CONTEXT_SERVICE, ContextService};
use crate::{
    model_client::services::MODEL_SERVICE,
    plugins::{Plugin, PluginContext, PluginDescriptor, PluginError},
    storage::services::PERSISTENCE_SERVICE,
};

#[derive(Default)]
pub struct DefaultContextPlugin;

#[async_trait]
impl Plugin for DefaultContextPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.context".into(),
            contract_version: 1,
            provides: vec![CONTEXT_SERVICE.key()],
            dependencies: vec![PERSISTENCE_SERVICE.key(), MODEL_SERVICE.key()],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let storage = context.require(PERSISTENCE_SERVICE)?;
        let model = context.require(MODEL_SERVICE)?;
        // Every invocation is awaited by the dependent runtime. Its quiesce
        // drains those calls before this provider's dependencies are released.
        context.provide(
            CONTEXT_SERVICE,
            ContextService::with_default_provider((*storage).clone(), (*model).clone()),
        )
    }
}
