use async_trait::async_trait;
use futures::future::BoxFuture;
use rig::http_client::DynHttpClient;

use super::{MODEL_SERVICE, ModelProvider, ModelRequest, ModelService};
use crate::{
    model_client::{
        ModelRunResult, RigModelClient,
        offline::{ScriptedReply, ScriptedTransport},
    },
    plugins::{Plugin, PluginContext, PluginDescriptor, PluginError},
};

impl ModelProvider for RigModelClient {
    fn run(&self, request: ModelRequest) -> BoxFuture<'static, Result<ModelRunResult, String>> {
        let client = self.clone();
        Box::pin(async move {
            client
                .run_inner(
                    &request.config,
                    request.preamble,
                    request.prompt,
                    request.history,
                    request.tools,
                    request.executor,
                    request.cancellation,
                    request.events,
                )
                .await
        })
    }
}

/// Builds the shipped Rig implementation for each plugin instance. Offline
/// replies replace its HTTP transport while keeping the same execution gates.
#[derive(Default)]
pub struct DefaultModelPlugin {
    offline_replies: Option<Vec<ScriptedReply>>,
}

impl DefaultModelPlugin {
    pub fn new(offline_replies: Option<Vec<ScriptedReply>>) -> Self {
        Self { offline_replies }
    }
}

#[async_trait]
impl Plugin for DefaultModelPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.model",
            contract_version: 1,
            provides: vec![MODEL_SERVICE.key()],
            dependencies: vec![],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let client = match &self.offline_replies {
            Some(replies) => RigModelClient::with_transport(DynHttpClient::new(
                ScriptedTransport::new(replies.clone()),
            )),
            None => RigModelClient::default(),
        };
        context.provide(MODEL_SERVICE, ModelService::from(client))
    }
}
