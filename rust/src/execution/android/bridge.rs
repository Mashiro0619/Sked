use serde::{Deserialize, de::DeserializeOwned};
use serde_json::{Value, json};
use tokio::task::JoinHandle;
use tokio_util::sync::CancellationToken;

use super::{error, join_error};
use crate::execution::{ExecutionError, ExecutionErrorCode, Result};

#[derive(Deserialize)]
struct Reply<T> {
    ok: bool,
    value: Option<T>,
    error: Option<ExecutionError>,
}

pub(super) fn decode<T: DeserializeOwned>(response: &str) -> Result<T> {
    let reply: Reply<T> = serde_json::from_str(response).map_err(|failure| {
        error(
            ExecutionErrorCode::OutcomeUnknown,
            format!("The Android execution response cannot be read: {failure}"),
        )
    })?;
    if reply.ok {
        reply.value.ok_or_else(|| {
            error(
                ExecutionErrorCode::OutcomeUnknown,
                "The Android execution response has no result.",
            )
        })
    } else {
        Err(reply.error.ok_or_else(|| {
            error(
                ExecutionErrorCode::OutcomeUnknown,
                "The Android execution response has no failure detail.",
            )
        })?)
    }
}

fn raw<T: DeserializeOwned>(request: Value) -> Result<T> {
    let result = crate::android::python_call(&request.to_string())
        .map_err(|failure| error(ExecutionErrorCode::OutcomeUnknown, failure))?;
    decode(&result)
}

pub(super) struct Call {
    id: String,
    done: CancellationToken,
    cancellation: JoinHandle<Result<()>>,
}

impl Call {
    pub async fn begin(
        id: String,
        directory: String,
        cwd_fd: i32,
        cancellation: CancellationToken,
    ) -> Result<Self> {
        let registered = id.clone();
        tokio::task::spawn_blocking(move || {
            raw::<Value>(json!({
                "op": "beginCall",
                "callId": registered,
                "runDirectory": directory,
                "cwdFd": cwd_fd,
            }))
        })
        .await
        .map_err(join_error)??;
        let done = CancellationToken::new();
        let ended = done.clone();
        let cancelling_id = id.clone();
        let cancellation = tokio::spawn(async move {
            tokio::select! {
                _ = ended.cancelled() => Ok(()),
                _ = cancellation.cancelled() => cancel(cancelling_id).await,
            }
        });
        Ok(Self {
            id,
            done,
            cancellation,
        })
    }

    pub async fn request<T: DeserializeOwned + Send + 'static>(
        &self,
        op: &'static str,
    ) -> Result<T> {
        let id = self.id.clone();
        tokio::task::spawn_blocking(move || raw(json!({"op":op,"callId":id})))
            .await
            .map_err(join_error)?
    }

    pub async fn cancel(&self) -> Result<()> {
        cancel(self.id.clone()).await
    }

    pub async fn finish(self) -> Result<()> {
        self.done.cancel();
        let cancelled = self.cancellation.await.map_err(join_error);
        let id = self.id;
        let ended =
            tokio::task::spawn_blocking(move || raw::<Value>(json!({"op":"endCall","callId":id})))
                .await
                .map_err(join_error)?;
        cancelled??;
        ended.map(|_| ())
    }
}

async fn cancel(id: String) -> Result<()> {
    let (send, receive) = tokio::sync::oneshot::channel();
    std::thread::Builder::new()
        .name("sked-python-cancel".into())
        .spawn(move || {
            let _ = send.send(crate::android::cancel_python_call(&id));
        })
        .map_err(super::io_error)?;
    receive
        .await
        .map_err(|failure| error(ExecutionErrorCode::OutcomeUnknown, failure.to_string()))?
        .map_err(|failure| error(ExecutionErrorCode::OutcomeUnknown, failure))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Ready {
    pub pid: i32,
    pub process_group: i32,
}

#[derive(Deserialize)]
pub(super) struct Started {
    pub started: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Closed {
    pub started: bool,
    pub cancelled: bool,
    pub group_gone: bool,
    pub error: Option<String>,
}
