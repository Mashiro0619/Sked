mod credentials;
pub mod offline;
mod request_body;
mod transport;
mod types;

pub use request_body::{PreparedRequestBody, RequestFile};
pub use types::*;

use std::sync::{Arc, Mutex};

use futures::StreamExt;
use rig::{
    AgentBuilder, DynModel,
    agent::{
        AgentHook, CompletionCallAction, CompletionCallEvent, DispatchAction, DispatchEvent,
        HookContext, InvalidToolCallAction, InvalidToolCallContext, InvalidToolCallReason,
        ModelTurnAction, ModelTurnFinished, MultiTurnStreamItem,
    },
    completion::{PromptError, Usage},
    http_client::{DynHttpClient, ReqwestClient, Uri},
    message::{AssistantContent, AssistantMessage, Message, ToolName},
    operation::Completion,
    providers::openai::OpenAIConfig,
    streaming::{Item, StreamEvent},
    tool::{DynamicTool, ToolExecutionError, ToolOutput},
};
use serde_json::{Value, json};
use tokio::sync::mpsc::{UnboundedSender, unbounded_channel};
use tokio_util::sync::CancellationToken;

use crate::{runtime::ToolDescriptor, storage::models::TokenUsage};
use credentials::{CredentialGuard, CredentialStream};
use transport::EndpointTransport;

#[derive(Clone)]
pub struct RigModelClient {
    transport: DynHttpClient,
    network: Option<Result<reqwest::Client, String>>,
}

impl Default for RigModelClient {
    fn default() -> Self {
        let network = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .build()
            .map_err(|error| error.to_string());
        let adapter = match &network {
            Ok(client) => ReqwestClient::from(client.clone()),
            Err(_) => ReqwestClient::default(),
        };
        Self {
            transport: DynHttpClient::new(adapter),
            network: Some(network),
        }
    }
}

impl RigModelClient {
    pub fn with_transport(transport: DynHttpClient) -> Self {
        Self {
            transport,
            network: None,
        }
    }

    pub async fn run(
        &self,
        config: &ConnectionConfig,
        preamble: String,
        prompt: Message,
        history: Vec<Value>,
        tools: Vec<ToolDescriptor>,
        executor: Arc<dyn ModelToolExecutor>,
        cancellation: CancellationToken,
        events: UnboundedSender<ModelEvent>,
    ) -> ModelRunResult {
        let guard = CredentialGuard::new(&config.api_key);
        let (raw_events, mut receiver) = unbounded_channel();
        let event_guard = guard.clone();
        let forward = async move {
            let mut text = CredentialStream::new(event_guard.clone());
            let mut reasoning = CredentialStream::new(event_guard.clone());
            while let Some(mut event) = receiver.recv().await {
                match &mut event {
                    ModelEvent::Text(delta) => {
                        let delta = text.push(delta);
                        if !delta.is_empty() {
                            let _ = events.send(ModelEvent::Text(delta));
                        }
                        continue;
                    }
                    ModelEvent::Reasoning(delta) => {
                        let delta = reasoning.push(delta);
                        if !delta.is_empty() {
                            let _ = events.send(ModelEvent::Reasoning(delta));
                        }
                        continue;
                    }
                    ModelEvent::Reset => {
                        text.clear();
                        reasoning.clear();
                    }
                    ModelEvent::RequestStarted { history, .. } => history
                        .iter_mut()
                        .for_each(|value| event_guard.value(value)),
                    ModelEvent::AssistantCommitted { message } => {
                        for delta in [text.finish()] {
                            if !delta.is_empty() {
                                let _ = events.send(ModelEvent::Text(delta));
                            }
                        }
                        for delta in [reasoning.finish()] {
                            if !delta.is_empty() {
                                let _ = events.send(ModelEvent::Reasoning(delta));
                            }
                        }
                        event_guard.value(message);
                        text.clear();
                        reasoning.clear();
                    }
                    ModelEvent::ToolCall {
                        id,
                        name,
                        arguments,
                    } => {
                        *id = event_guard.text(id);
                        *name = event_guard.text(name);
                        event_guard.value(arguments);
                    }
                    ModelEvent::ToolResult { id, message } => {
                        *id = event_guard.text(id);
                        event_guard.value(message);
                    }
                    ModelEvent::Usage { raw, .. } => event_guard.value(raw),
                }
                let _ = events.send(event);
            }
            for delta in [text.finish()] {
                if !delta.is_empty() {
                    let _ = events.send(ModelEvent::Text(delta));
                }
            }
            for delta in [reasoning.finish()] {
                if !delta.is_empty() {
                    let _ = events.send(ModelEvent::Reasoning(delta));
                }
            }
        };
        let run = self.run_inner(
            config,
            preamble,
            prompt,
            history.clone(),
            tools,
            executor,
            cancellation.clone(),
            raw_events,
        );
        let (result, ()) = tokio::join!(run, forward);
        let mut result = match result {
            Ok(result) => result,
            Err(error) => ModelRunResult {
                history,
                cancelled: cancellation.is_cancelled(),
                error: Some(error),
                ..Default::default()
            },
        };
        result
            .history
            .iter_mut()
            .for_each(|value| guard.value(value));
        result.text = guard.text(&result.text);
        result.error = result.error.map(|error| guard.error(&error));
        result
    }

    async fn run_inner(
        &self,
        config: &ConnectionConfig,
        preamble: String,
        prompt: Message,
        history: Vec<Value>,
        tools: Vec<ToolDescriptor>,
        executor: Arc<dyn ModelToolExecutor>,
        cancellation: CancellationToken,
        events: UnboundedSender<ModelEvent>,
    ) -> Result<ModelRunResult, String> {
        let guard = CredentialGuard::new(&config.api_key);
        let endpoint: Uri = config
            .full_endpoint
            .parse()
            .map_err(|e| format!("模型接口地址无效：{e}"))?;
        if !matches!(endpoint.scheme_str(), Some("http" | "https"))
            || endpoint.authority().is_none()
        {
            return Err("模型接口必须是完整 HTTP 或 HTTPS 地址".into());
        }
        let mut input = history.clone();
        input.push(serde_json::to_value(&prompt).map_err(|error| error.to_string())?);
        if input.iter().any(|value| guard.contains_value(value)) {
            return Err("会话内容包含当前连接凭据，已停止请求".into());
        }
        let transport = EndpointTransport {
            inner: self.transport.clone(),
            endpoint,
            cancellation: cancellation.clone(),
            executor: executor.clone(),
            protocol: config.protocol,
            network: self.network.clone(),
        };
        let client = OpenAIConfig::new(config.api_key.clone()).connect(transport);
        let model: DynModel<Completion> = match config.protocol {
            ProviderProtocol::ChatCompletions => client.chat(config.model.clone()).into(),
            ProviderProtocol::Responses => client.responses(config.model.clone()).into(),
        };
        let native_history: Vec<Message> = history
            .iter()
            .cloned()
            .map(serde_json::from_value)
            .collect::<Result<_, _>>()
            .map_err(|e| format!("会话模型历史无法读取：{e}"))?;
        let state = Arc::new(Mutex::new(RunObservation {
            history: native_history.clone(),
            dispatch: None,
        }));
        let mut dynamic_tools = Vec::with_capacity(tools.len());
        for tool in tools {
            let name = ToolName::new(wire_tool_name(&tool.name)).map_err(|e| e.to_string())?;
            let logical_name = tool.name.clone();
            let state = state.clone();
            let executor = executor.clone();
            let cancellation = cancellation.clone();
            let tool_guard = guard.clone();
            dynamic_tools.push(DynamicTool::new(
                name,
                tool.description,
                tool.parameters,
                move |arguments| {
                    let dispatch = state
                        .lock()
                        .expect("model observation mutex poisoned")
                        .dispatch
                        .take();
                    let executor = executor.clone();
                    let cancellation = cancellation.clone();
                    let logical_name = logical_name.clone();
                    let guard = tool_guard.clone();
                    Box::pin(async move {
                        let (_, call_id) = dispatch.ok_or_else(|| {
                            ToolExecutionError::invalid_args("工具调度缺少调用标识")
                        })?;
                        if cancellation.is_cancelled() {
                            return Ok(ToolOutput::json(
                                json!({"status":"cancelled", "message":"用户已停止本次运行"}),
                            ));
                        }
                        if guard.contains_value(&arguments) {
                            return Err(ToolExecutionError::invalid_args(
                                "工具参数包含当前连接凭据，已拒绝执行",
                            ));
                        }
                        // Await the native receipt even after cancellation. The host
                        // decides whether a transaction was already accepted.
                        executor
                            .execute(logical_name, call_id, arguments, cancellation)
                            .await
                            .map(|mut value| {
                                guard.value(&mut value);
                                ToolOutput::json(value)
                            })
                            .map_err(|error| ToolExecutionError::invalid_args(guard.error(&error)))
                    })
                },
            ));
        }
        let mut builder = AgentBuilder::new(model)
            .preamble(preamble)
            .default_max_turns(usize::MAX)
            .dynamic_tools(dynamic_tools)
            .add_hook(RunHook {
                state: state.clone(),
                events: events.clone(),
                cancellation: cancellation.clone(),
                executor,
                guard,
            });
        if let Some(effort) = config.reasoning_effort.as_ref().filter(|e| !e.is_empty()) {
            builder = builder.additional_params(match config.protocol {
                ProviderProtocol::ChatCompletions => json!({"reasoning_effort": effort}),
                ProviderProtocol::Responses => json!({"reasoning": {"effort": effort}}),
            });
        }
        let agent = builder.build();
        let mut stream = agent
            .prompt(prompt)
            .history(native_history)
            .max_turns(usize::MAX)
            .tool_concurrency(1)
            .stream();
        let mut text = String::new();
        let mut usage = TokenUsage::default();
        while let Some(item) = stream.next().await {
            match item {
                Ok(MultiTurnStreamItem::StreamAssistantItem(Item::Event(StreamEvent::Text {
                    text: delta,
                    ..
                }))) => {
                    text.push_str(&delta);
                    let _ = events.send(ModelEvent::Text(delta));
                }
                Ok(MultiTurnStreamItem::StreamAssistantItem(Item::Event(
                    StreamEvent::Reasoning { text, .. },
                ))) => {
                    let _ = events.send(ModelEvent::Reasoning(text));
                }
                Ok(MultiTurnStreamItem::ToolCall { tool_call }) => {
                    let _ = events.send(ModelEvent::ToolCall {
                        id: tool_call.id.to_string(),
                        name: logical_tool_name(tool_call.function.name.as_str()),
                        arguments: Value::Object(tool_call.function.arguments),
                    });
                }
                Ok(MultiTurnStreamItem::ToolResult { tool_result }) => {
                    let id = tool_result.call.to_string();
                    let message = serde_json::to_value(Message::tool_results(vec![tool_result]))
                        .map_err(|e| e.to_string())?;
                    let _ = events.send(ModelEvent::ToolResult { id, message });
                }
                Ok(MultiTurnStreamItem::CompletionCall(call)) => {
                    usage = token_usage(call.usage);
                    let _ = events.send(ModelEvent::Usage {
                        index: call.call_index,
                        usage: usage.clone(),
                        raw: call.raw,
                    });
                    text.clear();
                }
                Ok(MultiTurnStreamItem::ModelTurnRetried { .. }) => {
                    text.clear();
                    let _ = events.send(ModelEvent::Reset);
                }
                Ok(MultiTurnStreamItem::FinalResponse(response)) => {
                    let mut full_history = history;
                    full_history.extend(
                        response
                            .messages
                            .iter()
                            .map(serde_json::to_value)
                            .collect::<Result<Vec<_>, _>>()
                            .map_err(|e| e.to_string())?,
                    );
                    return Ok(ModelRunResult {
                        history: full_history,
                        text: response.output(),
                        usage: token_usage(response.usage),
                        cancelled: cancellation.is_cancelled(),
                        paused_for_compaction: false,
                        error: None,
                    });
                }
                Err(error) => {
                    let history = match &error {
                        PromptError::Cancelled { chat_history, .. }
                        | PromptError::UnknownToolCall { chat_history, .. }
                        | PromptError::MaxTurns { chat_history, .. } => chat_history.clone(),
                        _ => state
                            .lock()
                            .expect("model observation mutex poisoned")
                            .history
                            .clone(),
                    };
                    let paused_for_compaction = matches!(&error, PromptError::Cancelled { reason, .. } if reason == "sked_context_compaction");
                    return Ok(ModelRunResult {
                        history: history
                            .iter()
                            .map(serde_json::to_value)
                            .collect::<Result<_, _>>()
                            .map_err(|e| e.to_string())?,
                        text,
                        usage,
                        cancelled: cancellation.is_cancelled(),
                        paused_for_compaction,
                        error: Some(error.to_string()),
                    });
                }
                _ => {}
            }
        }
        Err("模型流在终态前结束".into())
    }
}

struct RunObservation {
    history: Vec<Message>,
    /// Rig dispatch is sequential, so the hook and the following DynamicTool
    /// callback share exactly one model-issued call identity.
    dispatch: Option<(String, String)>,
}

struct RunHook {
    state: Arc<Mutex<RunObservation>>,
    events: UnboundedSender<ModelEvent>,
    cancellation: CancellationToken,
    executor: Arc<dyn ModelToolExecutor>,
    guard: CredentialGuard,
}

impl AgentHook for RunHook {
    async fn on_completion_call(
        &self,
        _ctx: &HookContext,
        event: CompletionCallEvent<'_>,
    ) -> CompletionCallAction {
        let history: Vec<Message> = event
            .history
            .iter()
            .map(|message| (**message).clone())
            .chain(std::iter::once(event.prompt.clone()))
            .collect();
        self.state
            .lock()
            .expect("model observation mutex poisoned")
            .history = history.clone();
        if self.cancellation.is_cancelled() {
            return CompletionCallAction::stop("用户已停止本次运行");
        }
        let serialized: Vec<Value> = history
            .iter()
            .map(|message| {
                let mut value = serde_json::to_value(message).expect("message serialization");
                self.guard.value(&mut value);
                value
            })
            .collect();
        match self
            .executor
            .prepare_model(serialized, event.turn - 1)
            .await
        {
            Ok(true) => return CompletionCallAction::stop("sked_context_compaction"),
            Err(error) => return CompletionCallAction::stop(error),
            Ok(false) => {}
        }
        if self.executor.pause_before_model() {
            return CompletionCallAction::stop("sked_context_compaction");
        }
        let _ = self.events.send(ModelEvent::RequestStarted {
            index: event.turn - 1,
            history: history
                .iter()
                .map(|m| serde_json::to_value(m).expect("message serialization"))
                .collect(),
        });
        match self.executor.active_tools() {
            Some(names) => CompletionCallAction::patch(
                rig::run::patch::RequestPatch::new()
                    .active_tools(names.iter().map(|name| wire_tool_name(name))),
            ),
            None => CompletionCallAction::Continue,
        }
    }

    async fn on_dispatch(&self, _ctx: &HookContext, event: DispatchEvent<'_>) -> DispatchAction {
        if let (Some(name), Some(call)) = (event.tool_name(), event.call_id) {
            self.state
                .lock()
                .expect("model observation mutex poisoned")
                .dispatch = Some((name.into(), call.to_string()));
        }
        DispatchAction::Proceed
    }

    async fn on_invalid_tool_call(
        &self,
        _ctx: &HookContext,
        event: &InvalidToolCallContext,
    ) -> Option<InvalidToolCallAction> {
        if matches!(
            event.reason,
            InvalidToolCallReason::MalformedArguments { .. }
        ) {
            return None;
        }
        Some(InvalidToolCallAction::skip(format!(
            "toolName: {} 不是本次请求已公开的工具。请按 capabilities.describe 或 skills.load 发现工具后纠正调用。当前可用：{}。本组尚未执行的调用须在纠正后重新提出。",
            logical_tool_name(&event.tool_name),
            event
                .available_tools
                .iter()
                .map(|name| logical_tool_name(name))
                .collect::<Vec<_>>()
                .join(", ")
        )))
    }

    async fn on_model_turn_finished(
        &self,
        _ctx: &HookContext,
        event: ModelTurnFinished<'_>,
    ) -> ModelTurnAction {
        let has_content = event.content.iter().any(|content| match content {
            AssistantContent::Text(text) => !text.text.trim().is_empty(),
            content => !content.is_blank(),
        });
        if !has_content {
            return ModelTurnAction::stop("模型返回了空回复");
        }
        let message = Message::Assistant(AssistantMessage::new(event.content.clone()));
        self.state
            .lock()
            .expect("model observation mutex poisoned")
            .history
            .push(message.clone());
        let _ = self.events.send(ModelEvent::AssistantCommitted {
            message: serde_json::to_value(message).expect("message serialization"),
        });
        ModelTurnAction::Continue
    }
}

pub fn token_usage(usage: Usage) -> TokenUsage {
    TokenUsage {
        input_tokens: usage.input_tokens,
        output_tokens: usage.output_tokens,
        total_tokens: usage.total_tokens,
        cached_input_tokens: usage.cached_input_tokens,
        reasoning_tokens: usage.reasoning_tokens,
        cost: usage.cost.map(|cost| cost.total),
        cost_status: usage.cost.map(|cost| {
            if cost.is_complete() {
                "complete"
            } else {
                "partial"
            }
            .into()
        }),
    }
}

pub fn wire_tool_name(name: &str) -> String {
    name.replace('_', "_u").replace('.', "__")
}

pub fn logical_tool_name(name: &str) -> String {
    let mut decoded = String::new();
    let mut chars = name.chars();
    while let Some(ch) = chars.next() {
        if ch == '_' {
            match chars.next() {
                Some('_') => decoded.push('.'),
                Some('u') => decoded.push('_'),
                Some(other) => {
                    decoded.push('_');
                    decoded.push(other);
                }
                None => decoded.push('_'),
            }
        } else {
            decoded.push(ch);
        }
    }
    decoded
}
