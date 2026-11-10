use std::sync::Arc;

use rig::message::Message;
use serde_json::Value;
use tokio::sync::mpsc::{UnboundedSender, unbounded_channel};
use tokio_util::sync::CancellationToken;

use super::{ModelProvider, ModelRequest};
use crate::{
    model_client::{
        ConnectionConfig, ModelEvent, ModelRunResult, ModelToolExecutor, RigModelClient,
        credentials::{CredentialGuard, CredentialStream},
    },
    plugins::ServiceDefinition,
    runtime::ToolDescriptor,
};

pub const MODEL_SERVICE: ServiceDefinition<ModelService> = ServiceDefinition::new("sked.model", 1);

/// A model invocation retains its connection snapshot and original runtime
/// executor while this shared boundary filters streamed and final output.
#[derive(Clone)]
pub struct ModelService {
    provider: Arc<dyn ModelProvider>,
}

impl ModelService {
    pub fn new(provider: Arc<dyn ModelProvider>) -> Self {
        Self { provider }
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
                    ModelEvent::AssistantCommitted {
                        message,
                        tool_call_ids,
                    } => {
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
                        for id in tool_call_ids {
                            *id = event_guard.text(id);
                        }
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
                    ModelEvent::Usage { usage, raw, .. } => {
                        usage.cost_status = usage
                            .cost_status
                            .as_deref()
                            .map(|status| event_guard.error(status));
                        event_guard.value(raw);
                    }
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
        let run = self.provider.run(ModelRequest {
            config: config.clone(),
            preamble,
            prompt,
            history: history.clone(),
            tools,
            executor,
            cancellation: cancellation.clone(),
            events: raw_events,
        });
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
        result.usage.cost_status = result
            .usage
            .cost_status
            .as_deref()
            .map(|status| guard.error(status));
        if let Some(failure) = &mut result.provider_failure {
            failure.code = guard.error(&failure.code);
            failure.response_message = failure
                .response_message
                .as_deref()
                .and_then(|message| guard.diagnostic(message, 8192));
            failure.response_code = failure
                .response_code
                .as_deref()
                .and_then(|code| guard.diagnostic(code, 256));
            failure.response_body = failure
                .response_body
                .as_deref()
                .and_then(|body| guard.diagnostic(body, 32768));
            failure.request_id = failure
                .request_id
                .as_deref()
                .and_then(|id| guard.diagnostic(id, 256));
        }
        result.error = match &result.provider_failure {
            Some(failure) => Some(failure.code.clone()),
            None => result.error.map(|error| guard.error(&error)),
        };
        result
    }
}

impl From<RigModelClient> for ModelService {
    fn from(client: RigModelClient) -> Self {
        Self::new(Arc::new(client))
    }
}
