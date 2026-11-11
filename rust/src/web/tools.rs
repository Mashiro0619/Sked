use std::sync::Arc;

use async_trait::async_trait;
use futures::future::BoxFuture;
use serde_json::{Value, json};

use super::{WEB_SERVICE, WebError, WebErrorCode, WebFetchRequest, WebFetchResult, WebService};
use crate::{
    plugins::{Plugin, PluginContext, PluginDescriptor, PluginError, ServiceLease},
    runtime::{HostModelContent, HostToolResult, RuntimeError, ToolDescriptor, ToolOutcome},
    tooling::{TOOL_SERVICE, ToolCall, ToolContribution, ToolHandler, ToolResult, ToolRunContext},
};

pub struct WebToolPlugin;

#[async_trait]
impl Plugin for WebToolPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.web.tools",
            contract_version: 1,
            provides: vec![],
            dependencies: vec![WEB_SERVICE.key(), TOOL_SERVICE.key()],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let web = context.require(WEB_SERVICE)?;
        let tools = context.require(TOOL_SERVICE)?;
        tools.register_scoped(
            &context,
            vec![ToolContribution {
                descriptor: fetch_descriptor(),
                handler: Arc::new(WebFetchHandler { web }),
                bootstrap: false,
            }],
        )?;
        Ok(())
    }
}

struct WebFetchHandler {
    web: ServiceLease<WebService>,
}

impl ToolHandler for WebFetchHandler {
    fn execute(
        &self,
        call: ToolCall,
        context: Arc<dyn ToolRunContext>,
    ) -> BoxFuture<'static, Result<ToolResult, RuntimeError>> {
        let web = self.web.clone();
        Box::pin(async move {
            let request = parse_request(&call.arguments)?;
            let fetched = match web.fetch(request, call.cancellation.clone()).await {
                Ok(fetched) => fetched,
                Err(error) => return Ok(ToolResult::Pending(fetch_error(error))),
            };

            // Scoped admission retains the handler and its provider generation
            // through both this settlement and the catalog's final settlement.
            // Keep all content retentions alive until the original result and
            // its bytes have been saved to conversation storage.
            let pending = fetch_result(&fetched).map(ToolResult::Pending);
            let settled = context.settle(call, pending).await;
            drop(fetched);

            // Shutdown retries collection and returns its final result.
            // Cleanup does not change the tool payload already saved above.
            let _ = web.collect_snapshots().await;

            // Runtime settlement records abort_error before a journal failure
            // escapes, so the catalog observes it without saving a second result.
            settled
                .map(ToolResult::DomainOwned)
                .map_err(RuntimeError::Invalid)
        })
    }
}

fn fetch_descriptor() -> ToolDescriptor {
    ToolDescriptor {
        name: "web.fetch".into(),
        description: concat!(
            "Read a public HTTP(S) URL. Returns extracted page text and a resolved link index, ",
            "or the complete downloaded file, as durable model content. Call web.fetch with ",
            "a returned link URL to follow it or download an attachment. Read further text ",
            "using content.read with contentId and offset from nextOffset. Source includes ",
            "original and final URLs, fetch time, response metadata, and site-declared ",
            "publication dates with evidence; HTTP Last-Modified is separate."
        )
        .into(),
        parameters: json!({
            "type": "object",
            "properties": {
                "url": {
                    "type": "string",
                    "description": "Absolute public HTTP(S) URL to read or download."
                }
            },
            "required": ["url"],
            "additionalProperties": false
        }),
    }
}

fn parse_request(arguments: &Value) -> Result<WebFetchRequest, RuntimeError> {
    let fields = arguments
        .as_object()
        .ok_or_else(|| RuntimeError::Invalid("web.fetch 参数必须是对象".into()))?;
    if fields.keys().any(|key| key != "url") {
        return Err(RuntimeError::Invalid("web.fetch 包含未知参数".into()));
    }
    let url = fields
        .get("url")
        .and_then(Value::as_str)
        .ok_or_else(|| RuntimeError::Invalid("url: 必须提供字符串".into()))?;
    Ok(WebFetchRequest { url: url.into() })
}

fn fetch_result(fetched: &WebFetchResult) -> Result<HostToolResult, RuntimeError> {
    let model_content = fetched
        .content
        .iter()
        .map(|content| {
            let version = &content.snapshot.content_version;
            let byte_length = version
                .byte_length
                .ok_or_else(|| RuntimeError::Invalid("网页内容快照缺少字节长度".into()))?;
            let sha256 = version
                .sha256
                .clone()
                .ok_or_else(|| RuntimeError::Invalid("网页内容快照缺少 SHA-256 摘要".into()))?;
            Ok(HostModelContent::Snapshot {
                snapshot_id: content.snapshot.id.clone(),
                name: content.name.clone(),
                media_type: content.media_type.clone(),
                byte_length,
                sha256,
                text_range: content.text_range,
            })
        })
        .collect::<Result<Vec<_>, RuntimeError>>()?;
    let payload = json!({"status": "read", "source": &fetched.source});
    Ok(HostToolResult {
        model_payload: payload.clone(),
        details: payload,
        outcome: ToolOutcome::Success,
        model_content,
    })
}

fn fetch_error(error: WebError) -> HostToolResult {
    let cancelled = error.code == WebErrorCode::Cancelled;
    let payload = json!({
        "status": if cancelled { "cancelled" } else { "error" },
        "code": error.code,
        "message": error.message
    });
    HostToolResult {
        model_payload: payload.clone(),
        details: payload,
        outcome: if cancelled {
            ToolOutcome::Cancelled
        } else {
            ToolOutcome::Error
        },
        model_content: Vec::new(),
    }
}
