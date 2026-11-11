use std::{
    io::Read,
    sync::{Arc, Mutex},
};

use async_trait::async_trait;
use tokio_util::{sync::CancellationToken, task::TaskTracker};

use super::{
    HttpWebProvider, RawWebResponse, Result, WebContent, WebError, WebErrorCode, WebFetchRequest,
    WebFetchResult, WebLink, WebProvider, WebSource, extract, http,
};
use crate::{
    files::{FILES_SERVICE, FileService},
    plugins::{Plugin, PluginContext, PluginDescriptor, PluginError, ServiceDefinition},
    storage::models::ToolContentRange,
};

pub const WEB_SERVICE: ServiceDefinition<WebService> = ServiceDefinition::new("sked.web", 1);

const FIRST_TEXT_PAGE: usize = 32 * 1024;

struct Inner {
    provider: Arc<dyn WebProvider>,
    files: FileService,
    accepting: Mutex<bool>,
    cancellation: CancellationToken,
    tasks: TaskTracker,
    runtime: tokio::runtime::Handle,
}

#[derive(Clone)]
pub struct WebService {
    inner: Arc<Inner>,
}

impl WebService {
    pub fn new(provider: Arc<dyn WebProvider>, files: FileService) -> Result<Self> {
        let runtime = tokio::runtime::Handle::try_current().map_err(|error| {
            WebError::new(
                WebErrorCode::Unavailable,
                format!("The web runtime is unavailable: {error}"),
            )
        })?;
        Ok(Self {
            inner: Arc::new(Inner {
                provider,
                files,
                accepting: Mutex::new(true),
                cancellation: CancellationToken::new(),
                tasks: TaskTracker::new(),
                runtime,
            }),
        })
    }

    pub fn available(&self) -> bool {
        *self.inner.accepting.lock().expect("web admission poisoned")
            && self.inner.provider.available()
    }

    pub async fn fetch(
        &self,
        request: WebFetchRequest,
        cancellation: CancellationToken,
    ) -> Result<WebFetchResult> {
        http::fetch_url(&request.url)?;
        http::check_cancelled(&cancellation)?;
        let tracked = {
            let accepting = self.inner.accepting.lock().expect("web admission poisoned");
            if !*accepting || !self.inner.provider.available() {
                return Err(unavailable());
            }
            self.inner.tasks.token()
        };
        let request_cancellation = cancellation.child_token();
        // Dropping a waiter cancels its owned operation. The tracked driver
        // remains alive to finish file cleanup and all blocking extraction.
        let _cancel_waiter = request_cancellation.clone().drop_guard();
        let inner = self.inner.clone();
        self.inner
            .runtime
            .spawn(async move {
                let _tracked = tracked;
                let mut result = {
                    let work = fetch_content(&inner, request, request_cancellation.clone());
                    tokio::pin!(work);
                    tokio::select! {
                        biased;
                        _ = inner.cancellation.cancelled() => {
                            request_cancellation.cancel();
                            work.await
                        },
                        result = &mut work => result,
                    }
                };
                if let Err(error) = &mut result {
                    // A failed extraction/finish has already dropped partial
                    // results, so this pass can reclaim their private snapshots.
                    if let Err(cleanup) = collect(&inner).await {
                        error
                            .message
                            .push_str(&format!("; snapshot cleanup failed: {cleanup}"));
                    }
                }
                result
            })
            .await
            .map_err(join_error)?
    }

    /// The tool calls this after dropping its returned snapshot retentions.
    /// Shutdown retries collection and reports any failure that remains.
    /// An already persisted tool result keeps its successful outcome.
    pub async fn collect_snapshots(&self) -> Result<()> {
        let tracked = {
            let accepting = self.inner.accepting.lock().expect("web admission poisoned");
            if !*accepting {
                return Ok(());
            }
            self.inner.tasks.token()
        };
        let inner = self.inner.clone();
        self.inner
            .runtime
            .spawn(async move {
                let _tracked = tracked;
                collect(&inner).await
            })
            .await
            .map_err(join_error)?
    }

    pub async fn shutdown(&self) -> Result<()> {
        {
            let mut accepting = self.inner.accepting.lock().expect("web admission poisoned");
            *accepting = false;
            self.inner.tasks.close();
        }
        self.inner.cancellation.cancel();
        self.inner.tasks.wait().await;
        collect(&self.inner).await
    }
}

async fn collect(inner: &Inner) -> Result<()> {
    inner
        .files
        .collect_snapshots()
        .await
        .map_err(WebError::from)
}

async fn fetch_content(
    inner: &Inner,
    request: WebFetchRequest,
    cancellation: CancellationToken,
) -> Result<WebFetchResult> {
    let requested_url = http::fetch_url(&request.url)?;
    let mut raw = inner.provider.fetch(request, cancellation.clone()).await?;
    http::check_cancelled(&cancellation)?;
    validate_response(&raw, requested_url.as_str())?;
    let Some(kind) = extract::content_kind(&raw.source) else {
        return Ok(WebFetchResult {
            content: vec![WebContent {
                name: raw.source.name.clone(),
                media_type: native_media_type(&raw.source),
                snapshot: raw.snapshot,
                text_range: None,
                retention: raw.retention,
            }],
            source: raw.source,
        });
    };
    let mut reader = inner
        .files
        .lease_snapshot(raw.snapshot.id.clone(), cancellation.clone())
        .await?;
    let source = raw.source.clone();
    let decoding_cancellation = cancellation.clone();
    let extracted = inner
        .runtime
        .spawn_blocking(move || {
            let mut bytes = Vec::new();
            let mut buffer = vec![0_u8; crate::files::BUFFER_SIZE];
            loop {
                http::check_cancelled(&decoding_cancellation)?;
                let read = reader.read(&mut buffer).map_err(|error| {
                    WebError::new(
                        WebErrorCode::Storage,
                        format!("The downloaded snapshot could not be read: {error}"),
                    )
                })?;
                if read == 0 {
                    break;
                }
                bytes.try_reserve(read).map_err(|_| {
                    WebError::new(
                        WebErrorCode::Decode,
                        "The complete web document could not fit in available memory.",
                    )
                })?;
                bytes.extend_from_slice(&buffer[..read]);
            }
            extract::extract(&bytes, &source, kind, &decoding_cancellation)
        })
        .await
        .map_err(join_error)??;
    http::check_cancelled(&cancellation)?;
    raw.source.title = extracted.title;
    raw.source.publications = extracted.publications;
    let is_html = kind == extract::ContentKind::Html;
    let name = if is_html {
        format!("{}.txt", raw.source.name)
    } else {
        raw.source.name.clone()
    };
    let content_type = if is_html {
        "text/plain".into()
    } else {
        native_media_type(&raw.source)
    };
    let mut content = vec![
        seal_text(
            &inner.files,
            name,
            content_type,
            &extracted.text,
            &cancellation,
        )
        .await?,
    ];
    if !extracted.links.is_empty() {
        let links_cancellation = cancellation.clone();
        let links = inner
            .runtime
            .spawn_blocking(move || encode_links(extracted.links, &links_cancellation))
            .await
            .map_err(join_error)??;
        content.push(
            seal_text(
                &inner.files,
                "links.ndjson".into(),
                "application/x-ndjson".into(),
                &links,
                &cancellation,
            )
            .await?,
        );
    }
    http::check_cancelled(&cancellation)?;
    Ok(WebFetchResult {
        source: raw.source,
        content,
    })
}

fn validate_response(raw: &RawWebResponse, requested_url: &str) -> Result<()> {
    if http::fetch_url(&raw.source.original_url)?.as_str() != requested_url
        || raw.snapshot.id != raw.retention.id()
        || raw.snapshot.content_version.byte_length != Some(raw.source.byte_length)
        || raw
            .snapshot
            .content_version
            .sha256
            .as_deref()
            .is_none_or(|digest| !digest.eq_ignore_ascii_case(&raw.source.sha256))
        || raw.source.name.is_empty()
        || raw
            .source
            .name
            .chars()
            .any(|character| character <= '\u{1f}' || matches!(character, '/' | '\\'))
    {
        return Err(WebError::new(
            WebErrorCode::Storage,
            "The web provider returned inconsistent source or snapshot evidence.",
        ));
    }
    http::fetch_url(&raw.source.final_url)?;
    Ok(())
}

async fn seal_text(
    files: &FileService,
    name: String,
    media_type: String,
    text: &str,
    cancellation: &CancellationToken,
) -> Result<WebContent> {
    http::check_cancelled(cancellation)?;
    let id = files.begin_content(cancellation.clone()).await?;
    let result: Result<WebContent> = async {
        let mut offset = 0_u64;
        for chunk in text.as_bytes().chunks(crate::files::BUFFER_SIZE) {
            http::check_cancelled(cancellation)?;
            offset = files
                .append_content(id.clone(), offset, chunk.to_vec(), cancellation.clone())
                .await?;
        }
        let (snapshot, retention) = files
            .finish_content_retained(id.clone(), cancellation.clone())
            .await?;
        let mut end = text.len().min(FIRST_TEXT_PAGE);
        while !text.is_char_boundary(end) {
            end -= 1;
        }
        Ok(WebContent {
            name,
            media_type,
            snapshot,
            retention,
            text_range: Some(ToolContentRange {
                offset: 0,
                length: end as u64,
            }),
        })
    }
    .await;
    match result {
        Ok(content) => Ok(content),
        Err(mut error) => {
            if let Err(cleanup) = files.discard_content(id).await {
                error
                    .message
                    .push_str(&format!("; staged text cleanup failed: {cleanup}"));
            }
            Err(error)
        }
    }
}

fn encode_links(links: Vec<WebLink>, cancellation: &CancellationToken) -> Result<String> {
    let mut text = String::new();
    for link in links {
        http::check_cancelled(cancellation)?;
        let encoded = serde_json::to_string(&link)
            .map_err(|error| WebError::new(WebErrorCode::Decode, error.to_string()))?;
        text.try_reserve(encoded.len().saturating_add(1))
            .map_err(|_| {
                WebError::new(
                    WebErrorCode::Decode,
                    "The complete link index could not fit in available memory.",
                )
            })?;
        text.push_str(&encoded);
        text.push('\n');
    }
    Ok(text)
}

fn media_type(value: &str) -> String {
    value
        .split(';')
        .next()
        .unwrap_or_default()
        .trim()
        .to_ascii_lowercase()
}

fn native_media_type(source: &WebSource) -> String {
    if let Some(value) = &source.content_type {
        let value = media_type(value);
        let parts: Vec<_> = value.split('/').collect();
        if parts.len() == 2
            && parts.iter().all(|part| {
                !part.is_empty()
                    && part.bytes().all(|byte| {
                        byte.is_ascii_lowercase()
                            || byte.is_ascii_digit()
                            || b"!#$&^_.+-".contains(&byte)
                    })
            })
            && value != "application/octet-stream"
        {
            return value;
        }
    }
    // Generic or missing HTTP declarations use the same ordinary filename
    // evidence as device files. The original header remains in WebSource.
    match source
        .name
        .rsplit('.')
        .next()
        .unwrap_or_default()
        .to_ascii_lowercase()
        .as_str()
    {
        "pdf" => "application/pdf",
        "doc" | "dot" => "application/msword",
        "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "xls" | "xlt" => "application/vnd.ms-excel",
        "xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "ppt" | "pps" => "application/vnd.ms-powerpoint",
        "pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "webp" => "image/webp",
        "gif" => "image/gif",
        "svg" => "image/svg+xml",
        "mp3" => "audio/mpeg",
        "wav" => "audio/wav",
        "m4a" => "audio/mp4",
        "ogg" => "audio/ogg",
        "flac" => "audio/flac",
        _ => "application/octet-stream",
    }
    .into()
}

fn join_error(error: tokio::task::JoinError) -> WebError {
    WebError::new(
        WebErrorCode::Unavailable,
        format!("The owned web task could not complete: {error}"),
    )
}

fn unavailable() -> WebError {
    WebError::new(
        WebErrorCode::Unavailable,
        "The web service is unavailable or closing.",
    )
}

pub struct DefaultWebPlugin;

#[async_trait]
impl Plugin for DefaultWebPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.web",
            contract_version: 1,
            provides: vec![WEB_SERVICE.key()],
            dependencies: vec![FILES_SERVICE.key()],
        }
    }

    async fn setup(&self, context: PluginContext) -> std::result::Result<(), PluginError> {
        let files = (*context.require(FILES_SERVICE)?).clone();
        let provider = HttpWebProvider::new(files.clone())
            .map_err(|error| PluginError::new(error.to_string()))?;
        let service = WebService::new(Arc::new(provider), files)
            .map_err(|error| PluginError::new(error.to_string()))?;
        let closing = service.clone();
        context.on_quiesce(move || {
            Box::pin(async move {
                closing
                    .shutdown()
                    .await
                    .map_err(|error| PluginError::new(error.to_string()))
            })
        })?;
        context.provide(WEB_SERVICE, service)
    }
}
