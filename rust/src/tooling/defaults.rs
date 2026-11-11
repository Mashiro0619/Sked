use std::sync::Arc;

use async_trait::async_trait;
use futures::future::BoxFuture;

use super::{
    RuntimeToolGroup, TOOL_SERVICE, ToolCall, ToolContribution, ToolHandler, ToolRegistryError,
    ToolResult, ToolRunContext, ToolService, native,
};
use crate::{
    plugins::{Plugin, PluginContext, PluginDescriptor, PluginError},
    runtime::{RuntimeError, ToolDescriptor},
};

const BUSINESS_SOURCE: &str = "sked.default.business-tools";
const NATIVE_SOURCE: &str = "sked.default.native-tools";

struct RuntimeToolHandler(RuntimeToolGroup);

impl ToolHandler for RuntimeToolHandler {
    fn execute(
        &self,
        call: ToolCall,
        context: Arc<dyn ToolRunContext>,
    ) -> BoxFuture<'static, Result<ToolResult, RuntimeError>> {
        context.invoke_runtime(self.0, call)
    }
}

fn builtin_group(name: &str) -> Option<RuntimeToolGroup> {
    match name {
        "ask_user" | "update_plan" => Some(RuntimeToolGroup::Interaction),
        "conversation.get" | "conversation.history" | "conversation.read" | "content.read" => {
            Some(RuntimeToolGroup::Conversation)
        }
        "skills.search"
        | "skills.load"
        | "skills.get"
        | "skills.apply"
        | "memories.search"
        | "memories.get"
        | "memories.apply"
        | "knowledge.undo"
        | "knowledge.changes.get" => Some(RuntimeToolGroup::Knowledge),
        _ => None,
    }
}

fn is_bootstrap(name: &str) -> bool {
    matches!(
        name,
        "ask_user"
            | "update_plan"
            | "capabilities.describe"
            | "skills.search"
            | "skills.load"
            | "conversation.get"
            | "conversation.history"
            | "conversation.read"
            | "content.read"
    )
}

impl ToolService {
    /// The host's public catalog is one replaceable contribution. Native
    /// definitions retain precedence as in the original runtime assembly.
    pub fn replace_business_tools(&self, tools: Vec<ToolDescriptor>) {
        let handler: Arc<dyn ToolHandler> =
            Arc::new(RuntimeToolHandler(RuntimeToolGroup::Business));
        let contributions = tools
            .into_iter()
            .filter(|tool| builtin_group(&tool.name).is_none())
            .map(|descriptor| ToolContribution {
                bootstrap: is_bootstrap(&descriptor.name),
                descriptor,
                handler: handler.clone(),
            })
            .collect();
        self.replace_legacy_business_source(BUSINESS_SOURCE, contributions);
    }
}

/// Preserve descriptor ordering while routing the shipped groups to the
/// existing per-run implementations through a captured invocation context.
pub fn default_tool_service(tools: Vec<ToolDescriptor>) -> Result<ToolService, ToolRegistryError> {
    let service = ToolService::default();
    service.replace_business_tools(tools);
    let contributions = native::descriptors()
        .into_iter()
        .map(|descriptor| {
            let group = builtin_group(&descriptor.name).expect("native tool has a runtime group");
            ToolContribution {
                bootstrap: is_bootstrap(&descriptor.name),
                descriptor,
                handler: Arc::new(RuntimeToolHandler(group)),
            }
        })
        .collect();
    service.replace_runtime_source(NATIVE_SOURCE, contributions)?;
    Ok(service)
}

pub struct DefaultToolPlugin {
    tools: Vec<ToolDescriptor>,
}

impl DefaultToolPlugin {
    pub fn new(tools: Vec<ToolDescriptor>) -> Self {
        Self { tools }
    }
}

#[async_trait]
impl Plugin for DefaultToolPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.tools",
            contract_version: 1,
            provides: vec![TOOL_SERVICE.key()],
            dependencies: vec![],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let service = default_tool_service(self.tools.clone())
            .map_err(|error| PluginError::new(error.to_string()))?;
        let closing = service.clone();
        context.on_dispose(move || {
            Box::pin(async move {
                closing.close();
                Ok(())
            })
        })?;
        context.provide(TOOL_SERVICE, service)
    }
}
