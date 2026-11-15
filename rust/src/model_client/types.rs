use futures::future::BoxFuture;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::sync::{Arc, Mutex};
use tokio::sync::oneshot;
use tokio_util::sync::CancellationToken;

use crate::storage::models::{ModelSelection, TokenUsage};

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ProviderProtocol {
    #[default]
    ChatCompletions,
    Responses,
}

impl ProviderProtocol {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::ChatCompletions => "chatCompletions",
            Self::Responses => "responses",
        }
    }
}

/// Credentials are supplied by the secure Dart host for a captured run and are
/// deliberately excluded from persistence and Debug output.
#[derive(Clone)]
pub struct ConnectionConfig {
    pub protocol: ProviderProtocol,
    pub full_endpoint: String,
    pub model: String,
    pub model_config_id: String,
    pub connection_fingerprint: String,
    pub api_key: String,
    pub reasoning_effort: Option<String>,
    pub max_context_tokens: Option<u64>,
    pub auto_compact_at_tokens: Option<u64>,
    pub environment: Value,
}

impl std::fmt::Debug for ConnectionConfig {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ConnectionConfig")
            .field("protocol", &self.protocol)
            .field("model", &self.model)
            .field("reasoning_effort", &self.reasoning_effort)
            .finish_non_exhaustive()
    }
}

impl ConnectionConfig {
    pub fn selection(&self) -> ModelSelection {
        ModelSelection {
            model_id: self.model_config_id.clone(),
            reasoning_effort: self.reasoning_effort.clone(),
            protocol: Some(self.protocol.as_str().into()),
        }
    }
}

/// Ephemeral transport identity. Credentials are represented only by a digest.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConnectionIdentity {
    pub endpoint: String,
    pub protocol: ProviderProtocol,
    pub model: String,
    pub fingerprint: String,
}

impl ConnectionIdentity {
    pub fn from_config(config: &ConnectionConfig) -> Self {
        Self {
            endpoint: config.full_endpoint.clone(),
            protocol: config.protocol,
            model: config.model.clone(),
            fingerprint: format!("{:x}", Sha256::digest(config.api_key.as_bytes())),
        }
    }
}

#[derive(Debug, Clone)]
pub enum ModelEvent {
    Text(String),
    Reasoning(String),
    Reset,
    RequestStarted {
        index: usize,
        history: Vec<Value>,
    },
    AssistantCommitted {
        message: Value,
        tool_call_ids: Vec<String>,
        acknowledged: Option<ModelEventAcknowledgement>,
    },
    ToolCall {
        id: String,
        name: String,
        arguments: Value,
    },
    ToolResult {
        id: String,
        message: Value,
    },
    Usage {
        index: usize,
        usage: TokenUsage,
        raw: Value,
    },
}

/// Cloned event views share one completion. Dropping every view closes the
/// channel, so a vanished persistence consumer cannot admit tool execution.
#[derive(Debug, Clone)]
pub struct ModelEventAcknowledgement(Arc<Mutex<Option<oneshot::Sender<Result<(), String>>>>>);

impl ModelEventAcknowledgement {
    pub fn channel() -> (Self, oneshot::Receiver<Result<(), String>>) {
        let (sender, receiver) = oneshot::channel();
        (Self(Arc::new(Mutex::new(Some(sender)))), receiver)
    }

    pub fn complete(&self, result: Result<(), String>) {
        if let Some(sender) = self
            .0
            .lock()
            .expect("model acknowledgement poisoned")
            .take()
        {
            let _ = sender.send(result);
        }
    }
}

#[derive(Debug, Clone, Default)]
pub struct ModelRunResult {
    /// Full provider history including the input history and accepted prompt.
    pub history: Vec<Value>,
    pub text: String,
    pub usage: TokenUsage,
    pub cancelled: bool,
    pub paused_for_compaction: bool,
    pub error: Option<String>,
    pub provider_failure: Option<crate::storage::models::ProviderFailure>,
}

pub trait ModelToolExecutor: Send + Sync {
    fn requires_tool_call_acknowledgement(&self) -> bool {
        false
    }

    fn validate_input(
        &self,
        _input: Vec<Value>,
        _protocol: ProviderProtocol,
    ) -> BoxFuture<'static, Result<(), String>> {
        Box::pin(async { Ok(()) })
    }

    /// Keep message order and count while projecting application-owned media
    /// into the input accepted by this protocol. Stored history stays original.
    fn project_input(
        &self,
        input: Vec<Value>,
        _protocol: ProviderProtocol,
    ) -> BoxFuture<'static, Result<Vec<Value>, String>> {
        Box::pin(async move { Ok(input) })
    }

    fn execute(
        &self,
        name: String,
        call_id: String,
        arguments: Value,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<Value, String>>;

    fn authorize_request(
        &self,
        connection: ConnectionIdentity,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<(), String>> {
        Box::pin(async move {
            if connection.endpoint.starts_with("https://") {
                Ok(())
            } else {
                Err("HTTP 传输没有有效的用户许可".into())
            }
        })
    }

    /// Resolve application-owned attachment markers after the request gate.
    fn prepare_request_body(
        &self,
        body: Value,
        _protocol: ProviderProtocol,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<super::PreparedRequestBody, String>> {
        Box::pin(async move { super::PreparedRequestBody::json(body) })
    }

    fn pause_before_model(&self) -> bool {
        false
    }
    fn active_tools(&self) -> Option<Vec<String>> {
        None
    }
    fn prepare_model(
        &self,
        _history: Vec<Value>,
        _request_index: usize,
    ) -> BoxFuture<'static, Result<bool, String>> {
        Box::pin(async { Ok(false) })
    }
}
