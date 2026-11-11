use std::{
    collections::HashSet,
    io,
    pin::Pin,
    time::{SystemTime, UNIX_EPOCH},
};

use async_compression::tokio::bufread::{BrotliDecoder, GzipDecoder, ZlibDecoder};
use futures::{TryStreamExt, future::BoxFuture};
use reqwest::{Client, Response, Url, header};
use tokio::io::{AsyncRead, AsyncReadExt, BufReader};
use tokio_util::io::StreamReader;
use tokio_util::sync::CancellationToken;

use super::{
    RawWebResponse, Result, WebError, WebErrorCode, WebFetchRequest, WebProvider, WebSource,
};
use crate::files::FileService;

/// An anonymous client uses the same rustls platform verifier as model traffic,
/// but never obtains a model connection, browser session or credential headers.
#[derive(Clone)]
pub struct HttpWebProvider {
    client: Client,
    files: FileService,
}

impl HttpWebProvider {
    pub fn new(files: FileService) -> Result<Self> {
        let client = Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .referer(false)
            .no_gzip()
            .no_brotli()
            .no_deflate()
            .no_zstd()
            .user_agent("Sked/Agent web reader")
            .build()
            .map_err(network_error)?;
        Ok(Self { client, files })
    }
}

impl WebProvider for HttpWebProvider {
    fn available(&self) -> bool {
        self.files.available()
    }

    fn fetch(
        &self,
        request: WebFetchRequest,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<RawWebResponse>> {
        let provider = self.clone();
        Box::pin(async move { provider.fetch_inner(request, cancellation).await })
    }
}

impl HttpWebProvider {
    async fn fetch_inner(
        &self,
        request: WebFetchRequest,
        cancellation: CancellationToken,
    ) -> Result<RawWebResponse> {
        let mut current = fetch_url(&request.url)?;
        let mut visited = HashSet::new();
        loop {
            check_cancelled(&cancellation)?;
            if !visited.insert(current.as_str().to_owned()) {
                return Err(WebError::new(
                    WebErrorCode::Http,
                    "The website redirected to a URL already visited by this request.",
                ));
            }
            let response = tokio::select! {
                biased;
                _ = cancellation.cancelled() => return Err(WebError::cancelled()),
                response = self.client.get(current.clone())
                    .header(header::ACCEPT_ENCODING, "gzip, br, deflate")
                    .send() => response.map_err(network_error)?,
            };
            if matches!(response.status().as_u16(), 301 | 302 | 303 | 307 | 308) {
                let location = response
                    .headers()
                    .get(header::LOCATION)
                    .ok_or_else(|| {
                        WebError::new(WebErrorCode::Http, "The redirect has no Location header.")
                    })?
                    .to_str()
                    .map_err(|_| {
                        WebError::new(WebErrorCode::Http, "The redirect URL is invalid.")
                    })?;
                let target = current.join(location).map_err(|error| {
                    WebError::new(
                        WebErrorCode::InvalidUrl,
                        format!("Invalid redirect URL: {error}"),
                    )
                })?;
                let next = fetch_url(target.as_str())?;
                // No response body or connection lease is carried into another
                // origin. Every request uses this client's anonymous headers.
                drop(response);
                current = next;
                continue;
            }
            return self.download(request.url, response, cancellation).await;
        }
    }

    async fn download(
        &self,
        original_url: String,
        response: Response,
        cancellation: CancellationToken,
    ) -> Result<RawWebResponse> {
        let headers = response.headers();
        let content_type = text_header(headers, header::CONTENT_TYPE);
        let content_encoding = encoding_header(headers)?;
        let codings = content_codings(content_encoding.as_deref())?;
        let name = response_name(
            headers
                .get(header::CONTENT_DISPOSITION)
                .and_then(|value| value.to_str().ok()),
            response.url(),
            content_type.as_deref(),
        );
        let mut source = WebSource {
            original_url,
            final_url: response.url().as_str().to_owned(),
            status_code: response.status().as_u16(),
            fetched_at_ms: 0,
            content_type,
            content_encoding,
            name,
            byte_length: 0,
            sha256: String::new(),
            http_last_modified: text_header(headers, header::LAST_MODIFIED),
            etag: text_header(headers, header::ETAG),
            title: None,
            publications: Vec::new(),
        };
        let content_id = self.files.begin_content(cancellation.clone()).await?;
        let result: Result<RawWebResponse> = async {
            let mut body = decoded_body(response, &codings);
            let mut buffer = vec![0_u8; crate::files::BUFFER_SIZE];
            let mut offset = 0_u64;
            loop {
                let count = tokio::select! {
                    biased;
                    _ = cancellation.cancelled() => return Err(WebError::cancelled()),
                    count = body.read(&mut buffer) => count.map_err(body_error)?,
                };
                if count == 0 {
                    break;
                }
                check_cancelled(&cancellation)?;
                offset = self
                    .files
                    .append_content(
                        content_id.clone(),
                        offset,
                        buffer[..count].to_vec(),
                        cancellation.clone(),
                    )
                    .await?;
            }
            let (snapshot, retention) = self
                .files
                .finish_content_retained(content_id.clone(), cancellation.clone())
                .await?;
            check_cancelled(&cancellation)?;
            source.byte_length = snapshot.content_version.byte_length.ok_or_else(|| {
                WebError::new(
                    WebErrorCode::Storage,
                    "The downloaded snapshot has no byte length.",
                )
            })?;
            source.sha256 = snapshot.content_version.sha256.clone().ok_or_else(|| {
                WebError::new(
                    WebErrorCode::Storage,
                    "The downloaded snapshot has no digest.",
                )
            })?;
            source.fetched_at_ms = now_ms()?;
            Ok(RawWebResponse {
                source,
                snapshot,
                retention,
            })
        }
        .await;
        match result {
            Ok(downloaded) => Ok(downloaded),
            Err(mut error) => {
                if let Err(cleanup) = self.files.discard_content(content_id).await {
                    error
                        .message
                        .push_str(&format!("; staged content cleanup failed: {cleanup}"));
                }
                Err(error)
            }
        }
    }
}

pub(super) fn fetch_url(value: &str) -> Result<Url> {
    let mut url = Url::parse(value.trim()).map_err(|error| {
        WebError::new(
            WebErrorCode::InvalidUrl,
            format!("Invalid web URL: {error}"),
        )
    })?;
    if !matches!(url.scheme(), "http" | "https")
        || url.host_str().is_none()
        || !url.username().is_empty()
        || url.password().is_some()
    {
        return Err(WebError::new(
            WebErrorCode::InvalidUrl,
            "Use an HTTP(S) URL with a host and without embedded credentials.",
        ));
    }
    url.set_fragment(None);
    Ok(url)
}

pub(super) fn check_cancelled(cancellation: &CancellationToken) -> Result<()> {
    if cancellation.is_cancelled() {
        Err(WebError::cancelled())
    } else {
        Ok(())
    }
}

fn text_header(headers: &header::HeaderMap, name: header::HeaderName) -> Option<String> {
    headers.get(name)?.to_str().ok().map(str::to_owned)
}

fn encoding_header(headers: &header::HeaderMap) -> Result<Option<String>> {
    let mut values = Vec::new();
    for value in headers.get_all(header::CONTENT_ENCODING).iter() {
        values.push(value.to_str().map_err(|_| {
            WebError::new(
                WebErrorCode::Http,
                "The Content-Encoding header is invalid.",
            )
        })?);
    }
    Ok((!values.is_empty()).then(|| values.join(", ")))
}

fn content_codings(value: Option<&str>) -> Result<Vec<String>> {
    let mut codings = Vec::new();
    for part in value.into_iter().flat_map(|value| value.split(',')) {
        let coding = part.trim().to_ascii_lowercase();
        match coding.as_str() {
            "" | "identity" => {}
            "gzip" | "x-gzip" | "br" | "deflate" => codings.push(coding),
            _ => {
                return Err(WebError::new(
                    WebErrorCode::Decode,
                    "The server declared an unsupported HTTP content encoding.",
                ));
            }
        }
    }
    Ok(codings)
}

fn decoded_body(response: Response, codings: &[String]) -> Pin<Box<dyn AsyncRead + Send>> {
    let stream = response
        .bytes_stream()
        .map_err(|error| io::Error::other(error.without_url()));
    let mut body: Pin<Box<dyn AsyncRead + Send>> = Box::pin(StreamReader::new(stream));
    // Content-Encoding lists the applied encodings in application order.
    // Reversing the list restores the complete original entity bytes.
    for coding in codings.iter().rev() {
        let reader = BufReader::new(body);
        body = match coding.as_str() {
            "gzip" | "x-gzip" => {
                let mut decoder = GzipDecoder::new(reader);
                decoder.multiple_members(true);
                Box::pin(decoder)
            }
            "br" => {
                let mut decoder = BrotliDecoder::new(reader);
                decoder.multiple_members(true);
                Box::pin(decoder)
            }
            "deflate" => {
                let mut decoder = ZlibDecoder::new(reader);
                decoder.multiple_members(true);
                Box::pin(decoder)
            }
            _ => unreachable!("validated HTTP content encoding"),
        };
    }
    body
}

fn response_name(disposition: Option<&str>, url: &Url, content_type: Option<&str>) -> String {
    if let Some(disposition) = disposition {
        let parameters = header_parameters(disposition);
        if let Some(value) = parameters
            .iter()
            .find_map(|(name, value)| name.eq_ignore_ascii_case("filename*").then_some(value))
        {
            if let Some((charset, tail)) = value.split_once('\'') {
                if let Some((_, encoded)) = tail.split_once('\'') {
                    if let (Some(encoding), Some(bytes)) = (
                        encoding_rs::Encoding::for_label(charset.as_bytes()),
                        percent_decode(encoded),
                    ) {
                        let (name, _, malformed) = encoding.decode(&bytes);
                        if !malformed {
                            if let Some(name) = safe_name(&name) {
                                return name;
                            }
                        }
                    }
                }
            }
        }
        if let Some(name) = parameters.iter().find_map(|(name, value)| {
            name.eq_ignore_ascii_case("filename")
                .then(|| safe_name(value))
                .flatten()
        }) {
            return name;
        }
    }
    if let Some(segment) = url.path_segments().and_then(|segments| segments.last()) {
        if let Some(bytes) = percent_decode(segment) {
            if let Ok(name) = std::str::from_utf8(&bytes) {
                if let Some(name) = safe_name(name) {
                    return name;
                }
            }
        }
    }
    if content_type.is_some_and(|value| {
        value
            .split(';')
            .next()
            .unwrap_or_default()
            .trim()
            .eq_ignore_ascii_case("text/html")
    }) {
        "page.html".into()
    } else {
        "download".into()
    }
}

fn safe_name(value: &str) -> Option<String> {
    let name = value.rsplit(['/', '\\']).next()?.trim();
    if name.is_empty() || matches!(name, "." | "..") {
        return None;
    }
    Some(
        name.chars()
            .map(|character| {
                if character <= '\u{1f}' {
                    '_'
                } else {
                    character
                }
            })
            .collect(),
    )
}

fn header_parameters(value: &str) -> Vec<(String, String)> {
    let mut parts = Vec::new();
    let mut start = 0;
    let mut quoted = false;
    let mut escaped = false;
    for (index, character) in value.char_indices() {
        if escaped {
            escaped = false;
            continue;
        }
        if quoted && character == '\\' {
            escaped = true;
            continue;
        }
        if character == '"' {
            quoted = !quoted;
        }
        if character == ';' && !quoted {
            parts.push(&value[start..index]);
            start = index + 1;
        }
    }
    parts.push(&value[start..]);
    parts
        .into_iter()
        .skip(1)
        .filter_map(|part| {
            let (name, value) = part.split_once('=')?;
            let value = value.trim();
            let value = if value.starts_with('"') && value.ends_with('"') && value.len() >= 2 {
                let mut decoded = String::new();
                let mut escaped = false;
                for character in value[1..value.len() - 1].chars() {
                    if !escaped && character == '\\' {
                        escaped = true;
                        continue;
                    }
                    decoded.push(character);
                    escaped = false;
                }
                decoded
            } else {
                value.to_owned()
            };
            Some((name.trim().to_owned(), value))
        })
        .collect()
}

fn percent_decode(value: &str) -> Option<Vec<u8>> {
    let mut bytes = Vec::with_capacity(value.len());
    let mut input = value.as_bytes().iter().copied();
    while let Some(byte) = input.next() {
        if byte == b'%' {
            let high = (input.next()? as char).to_digit(16)?;
            let low = (input.next()? as char).to_digit(16)?;
            bytes.push((high * 16 + low) as u8);
        } else {
            bytes.push(byte);
        }
    }
    Some(bytes)
}

fn now_ms() -> Result<i64> {
    let elapsed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|error| {
            WebError::new(
                WebErrorCode::Unavailable,
                format!("The system clock is unavailable: {error}"),
            )
        })?;
    i64::try_from(elapsed.as_millis()).map_err(|_| {
        WebError::new(
            WebErrorCode::Unavailable,
            "The system clock exceeds the timestamp range.",
        )
    })
}

fn network_error(error: reqwest::Error) -> WebError {
    WebError::new(
        WebErrorCode::Network,
        format!("Web request failed: {}", error.without_url()),
    )
}

fn body_error(error: io::Error) -> WebError {
    let code = if error
        .get_ref()
        .is_some_and(|source| source.is::<reqwest::Error>())
    {
        WebErrorCode::Network
    } else {
        WebErrorCode::Decode
    };
    WebError::new(
        code,
        format!("The response body could not be completely read and decoded: {error}"),
    )
}
