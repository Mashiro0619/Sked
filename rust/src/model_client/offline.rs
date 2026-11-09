//! Offline acceptance replaces HTTP replies while keeping Rig's protocol
//! decoders, Agent loop, native tools, and storage on the production path.

use std::{
    collections::VecDeque,
    sync::{Arc, Mutex},
};

use futures::stream;
use rig::http_client::{
    Bytes, Error, HeaderMap, HttpClientExt, LazyBody, MultipartForm, Request, Response, Result,
    StatusCode, StreamingResponse,
};

#[derive(Debug, Clone)]
pub struct ScriptedReply {
    pub status: u16,
    pub content_type: String,
    pub body: String,
}

impl ScriptedReply {
    pub fn sse(body: impl Into<String>) -> Self {
        Self {
            status: 200,
            content_type: "text/event-stream".into(),
            body: body.into(),
        }
    }

    pub fn json(body: impl Into<String>) -> Self {
        Self {
            status: 200,
            content_type: "application/json".into(),
            body: body.into(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct CapturedRequest {
    pub endpoint: String,
    pub body: Vec<u8>,
}

#[derive(Clone, Default)]
pub struct ScriptedTransport {
    replies: Arc<Mutex<VecDeque<ScriptedReply>>>,
    requests: Arc<Mutex<Vec<CapturedRequest>>>,
}

impl ScriptedTransport {
    pub fn new(replies: impl IntoIterator<Item = ScriptedReply>) -> Self {
        Self {
            replies: Arc::new(Mutex::new(replies.into_iter().collect())),
            ..Self::default()
        }
    }

    pub fn requests(&self) -> Vec<CapturedRequest> {
        self.requests
            .lock()
            .expect("scripted request mutex poisoned")
            .clone()
    }

    fn take(&self, req: Request<Bytes>) -> Result<ScriptedReply> {
        self.requests
            .lock()
            .expect("scripted request mutex poisoned")
            .push(CapturedRequest {
                endpoint: req.uri().to_string(),
                body: req.body().to_vec(),
            });
        let reply = self
            .replies
            .lock()
            .expect("scripted reply mutex poisoned")
            .pop_front()
            .ok_or_else(|| {
                Error::instance(std::io::Error::new(
                    std::io::ErrorKind::UnexpectedEof,
                    "离线模型回包已用完",
                ))
            })?;
        let status = StatusCode::from_u16(reply.status).map_err(Error::instance)?;
        if !status.is_success() {
            return Err(Error::non_success_with_details(
                status,
                HeaderMap::new(),
                reply.body,
            ));
        }
        Ok(reply)
    }
}

impl HttpClientExt for ScriptedTransport {
    fn send<T, U>(
        &self,
        req: Request<T>,
    ) -> impl Future<Output = Result<Response<LazyBody<U>>>> + Send + 'static
    where
        T: Into<Bytes> + Send,
        U: From<Bytes> + Send + 'static,
    {
        let reply = self.take(req.map(Into::into));
        async move {
            let reply = reply?;
            let body: LazyBody<U> = Box::pin(async move { Ok(U::from(Bytes::from(reply.body))) });
            Ok(Response::builder()
                .status(reply.status)
                .header("content-type", reply.content_type)
                .body(body)?)
        }
    }

    fn send_multipart<U>(
        &self,
        _req: Request<MultipartForm>,
    ) -> impl Future<Output = Result<Response<LazyBody<U>>>> + Send + 'static
    where
        U: From<Bytes> + Send + 'static,
    {
        async {
            Err(Error::instance(std::io::Error::new(
                std::io::ErrorKind::Unsupported,
                "离线回包未声明文件上传",
            )))
        }
    }

    fn send_streaming<T>(
        &self,
        req: Request<T>,
    ) -> impl Future<Output = Result<StreamingResponse>> + Send
    where
        T: Into<Bytes> + Send,
    {
        let reply = self.take(req.map(Into::into));
        async move {
            let reply = reply?;
            let chunks: Vec<_> = reply
                .body
                .split_inclusive('\n')
                .map(|line| Ok(Bytes::copy_from_slice(line.as_bytes())))
                .collect();
            Ok(Response::builder()
                .status(reply.status)
                .header("content-type", reply.content_type)
                .body(Box::pin(stream::iter(chunks)) as _)?)
        }
    }
}
