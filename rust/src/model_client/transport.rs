use std::sync::Arc;

use futures::{StreamExt, stream};
use rig::http_client::{
    Bytes, DynHttpClient, Error, HttpClientExt, LazyBody, MultipartForm, Request, Response, Result,
    StreamingResponse, Uri,
};
use tokio_util::sync::CancellationToken;

use super::{ModelToolExecutor, PreparedRequestBody, ProviderProtocol};

/// Rig owns protocol structure. Native attachment files are streamed into that
/// structure while this adapter preserves the exact configured endpoint.
#[derive(Clone)]
pub(super) struct EndpointTransport {
    pub inner: DynHttpClient,
    pub endpoint: Uri,
    pub cancellation: CancellationToken,
    pub executor: Arc<dyn ModelToolExecutor>,
    pub protocol: ProviderProtocol,
    pub network: Option<std::result::Result<reqwest::Client, String>>,
}

fn failure(message: impl Into<String>) -> Error {
    Error::instance(std::io::Error::other(message.into()))
}

fn cancelled() -> Error {
    Error::instance(std::io::Error::new(
        std::io::ErrorKind::Interrupted,
        "模型请求已取消",
    ))
}

impl EndpointTransport {
    async fn prepare(&self, req: Request<Bytes>) -> Result<Request<PreparedRequestBody>> {
        if self.cancellation.is_cancelled() {
            return Err(cancelled());
        }
        let (mut parts, body) = req.into_parts();
        let body = serde_json::from_slice(&body).map_err(Error::instance)?;
        let body = self
            .executor
            .prepare_request_body(body, self.protocol, self.cancellation.clone())
            .await
            .map_err(failure)?;
        if self.cancellation.is_cancelled() {
            return Err(cancelled());
        }
        parts.headers.insert(
            "content-length",
            body.content_length
                .to_string()
                .parse()
                .map_err(Error::instance)?,
        );
        Ok(Request::from_parts(parts, body))
    }

    async fn send_network(&self, req: Request<PreparedRequestBody>) -> Result<reqwest::Response> {
        let client = self
            .network
            .as_ref()
            .ok_or_else(|| failure("HTTP client is unavailable"))?
            .as_ref()
            .map_err(|message| failure(message.clone()))?;
        let (parts, body) = req.into_parts();
        let request = reqwest::Request::try_from(Request::from_parts(
            parts,
            reqwest::Body::wrap_stream(body.into_stream(self.cancellation.clone())),
        ))
        .map_err(Error::instance)?;
        let response = tokio::select! {
            biased;
            _ = self.cancellation.cancelled() => return Err(cancelled()),
            response = client.execute(request) => response.map_err(Error::instance)?,
        };
        if !response.status().is_success() {
            let status = response.status();
            let headers = response.headers().clone();
            let body = tokio::select! {
                biased;
                _ = self.cancellation.cancelled() => return Err(cancelled()),
                body = response.text() => body.map_err(Error::instance)?,
            };
            return Err(Error::non_success_with_details(status, headers, body));
        }
        Ok(response)
    }

    async fn scripted(&self, req: Request<PreparedRequestBody>) -> Result<Request<Bytes>> {
        let (parts, body) = req.into_parts();
        let body = body
            .collect(self.cancellation.clone())
            .await
            .map_err(Error::instance)?;
        Ok(Request::from_parts(parts, body))
    }
}

impl HttpClientExt for EndpointTransport {
    fn send<T, U>(
        &self,
        mut req: Request<T>,
    ) -> impl Future<Output = Result<Response<LazyBody<U>>>> + Send + 'static
    where
        T: Into<Bytes> + Send,
        U: From<Bytes> + Send + 'static,
    {
        *req.uri_mut() = self.endpoint.clone();
        let req = req.map(Into::<Bytes>::into);
        let transport = self.clone();
        async move {
            let req = transport.prepare(req).await?;
            let cancellation = transport.cancellation.clone();
            if transport.network.is_some() {
                let response = transport.send_network(req).await?;
                let mut head = Response::builder()
                    .status(response.status())
                    .version(response.version());
                *head.headers_mut().expect("response headers") = response.headers().clone();
                let body: LazyBody<U> = Box::pin(async move {
                    tokio::select! {
                        biased;
                        _ = cancellation.cancelled() => Err(cancelled()),
                        bytes = response.bytes() => bytes.map(U::from).map_err(Error::instance),
                    }
                });
                return head.body(body).map_err(Error::Protocol);
            }
            let req = transport.scripted(req).await?;
            let response = tokio::select! {
                biased;
                _ = cancellation.cancelled() => return Err(cancelled()),
                response = transport.inner.send::<_, U>(req) => response?,
            };
            let (parts, body) = response.into_parts();
            let body: LazyBody<U> = Box::pin(async move {
                tokio::select! {
                    biased;
                    _ = cancellation.cancelled() => Err(cancelled()),
                    value = body => value,
                }
            });
            Ok(Response::from_parts(parts, body))
        }
    }

    fn send_multipart<U>(
        &self,
        mut req: Request<MultipartForm>,
    ) -> impl Future<Output = Result<Response<LazyBody<U>>>> + Send + 'static
    where
        U: From<Bytes> + Send + 'static,
    {
        *req.uri_mut() = self.endpoint.clone();
        let transport = self.clone();
        async move {
            if let Some(Err(error)) = &transport.network {
                return Err(failure(error.clone()));
            }
            let cancellation = transport.cancellation;
            let response = tokio::select! {
                biased;
                _ = cancellation.cancelled() => return Err(cancelled()),
                response = transport.inner.send_multipart::<U>(req) => response?,
            };
            let (parts, body) = response.into_parts();
            let body: LazyBody<U> = Box::pin(async move {
                tokio::select! {
                    biased;
                    _ = cancellation.cancelled() => Err(cancelled()),
                    value = body => value,
                }
            });
            Ok(Response::from_parts(parts, body))
        }
    }

    fn send_streaming<T>(
        &self,
        mut req: Request<T>,
    ) -> impl Future<Output = Result<StreamingResponse>> + Send
    where
        T: Into<Bytes> + Send,
    {
        *req.uri_mut() = self.endpoint.clone();
        let req = req.map(Into::<Bytes>::into);
        let transport = self.clone();
        async move {
            let req = transport.prepare(req).await?;
            let cancellation = transport.cancellation.clone();
            let response = if transport.network.is_some() {
                let response = transport.send_network(req).await?;
                let mut head = Response::builder()
                    .status(response.status())
                    .version(response.version());
                *head.headers_mut().expect("response headers") = response.headers().clone();
                head.body(Box::pin(
                    response
                        .bytes_stream()
                        .map(|chunk| chunk.map_err(Error::instance)),
                ) as _)
                    .map_err(Error::Protocol)?
            } else {
                let req = transport.scripted(req).await?;
                tokio::select! {
                    biased;
                    _ = cancellation.cancelled() => return Err(cancelled()),
                    response = transport.inner.send_streaming(req) => response?,
                }
            };
            let (parts, body) = response.into_parts();
            let body = stream::unfold(
                (body, cancellation, false),
                |(mut body, cancellation, finished)| async move {
                    if finished {
                        return None;
                    }
                    tokio::select! {
                        biased;
                        _ = cancellation.cancelled() => Some((Err(cancelled()), (body, cancellation, true))),
                        chunk = body.next() => chunk.map(|chunk| (chunk, (body, cancellation, false))),
                    }
                },
            );
            Ok(Response::from_parts(parts, Box::pin(body) as _))
        }
    }
}
