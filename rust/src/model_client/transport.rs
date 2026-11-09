use futures::{StreamExt, stream};
use rig::http_client::{
    Bytes, DynHttpClient, Error, HttpClientExt, LazyBody, MultipartForm, Request, Response, Result,
    StreamingResponse, Uri,
};
use tokio_util::sync::CancellationToken;

/// Rig owns protocol encoding; this transport owns the user-configured complete
/// endpoint and cancellation of network work. Query parameters remain intact.
#[derive(Clone)]
pub(super) struct EndpointTransport {
    pub inner: DynHttpClient,
    pub endpoint: Uri,
    pub cancellation: CancellationToken,
}

fn cancelled() -> Error {
    Error::instance(std::io::Error::new(
        std::io::ErrorKind::Interrupted,
        "模型请求已取消",
    ))
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
        let inner = self.inner.clone();
        let cancellation = self.cancellation.clone();
        async move {
            let response = tokio::select! {
                biased;
                _ = cancellation.cancelled() => return Err(cancelled()),
                response = inner.send::<_, U>(req) => response?,
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
        let inner = self.inner.clone();
        let cancellation = self.cancellation.clone();
        async move {
            let response = tokio::select! {
                biased;
                _ = cancellation.cancelled() => return Err(cancelled()),
                response = inner.send_multipart::<U>(req) => response?,
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
        let inner = self.inner.clone();
        let cancellation = self.cancellation.clone();
        async move {
            let response = tokio::select! {
                biased;
                _ = cancellation.cancelled() => return Err(cancelled()),
                response = inner.send_streaming(req) => response?,
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
