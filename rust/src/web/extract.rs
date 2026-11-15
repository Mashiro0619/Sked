use std::collections::{HashMap, HashSet};

use encoding_rs::{DecoderResult, Encoding, UTF_8, UTF_16BE, UTF_16LE};
use html5ever::{
    driver::{ParseOpts, parse_document},
    tendril::{StrTendril, TendrilSink},
    tree_builder::TreeBuilderOpts,
};
use reqwest::Url;
use scraper::{ElementRef, Html, HtmlTreeSink, Node};
use serde_json::Value;
use tokio_util::sync::CancellationToken;

use super::{
    ExtractedWebContent, Result, WebError, WebErrorCode, WebLink, WebPublication, WebSource,
};

const DECODE_CHUNK_BYTES: usize = 64 * 1024;

#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum ContentKind {
    Html,
    Text,
}

pub(super) fn content_kind(source: &WebSource) -> Option<ContentKind> {
    let media_type = source.content_type.as_deref()?.split(';').next()?.trim();
    let media_type = media_type.to_ascii_lowercase();
    if matches!(media_type.as_str(), "text/html" | "application/xhtml+xml") {
        return Some(ContentKind::Html);
    }
    if media_type.starts_with("text/")
        || (media_type.starts_with("application/")
            && (media_type.ends_with("+json") || media_type.ends_with("+xml")))
        || matches!(
            media_type.as_str(),
            "application/json"
                | "application/xml"
                | "application/javascript"
                | "application/ecmascript"
                | "application/x-javascript"
                | "application/x-ndjson"
                | "application/ndjson"
                | "application/jsonl"
                | "application/yaml"
                | "application/x-yaml"
                | "application/toml"
        )
    {
        return Some(ContentKind::Text);
    }
    None
}

pub(super) fn extract(
    bytes: &[u8],
    source: &WebSource,
    kind: ContentKind,
    cancellation: &CancellationToken,
) -> Result<ExtractedWebContent> {
    check_cancelled(cancellation)?;
    let (encoding, bom_length) = source_encoding(bytes, source, kind, cancellation)?;
    let mut content = ExtractedWebContent {
        text: String::new(),
        links: Vec::new(),
        title: None,
        publications: Vec::new(),
    };
    if kind == ContentKind::Text {
        decode_chunks(&bytes[bom_length..], encoding, cancellation, |chunk| {
            content.text.push_str(chunk);
            Ok(())
        })?;
    } else {
        let options = ParseOpts {
            tree_builder: TreeBuilderOpts {
                scripting_enabled: false,
                ..Default::default()
            },
            ..Default::default()
        };
        let mut parser = parse_document(HtmlTreeSink::new(Html::new_document()), options);
        decode_chunks(&bytes[bom_length..], encoding, cancellation, |chunk| {
            parser.process(StrTendril::from_slice(chunk));
            Ok(())
        })?;
        check_cancelled(cancellation)?;
        let document = parser.finish();
        check_cancelled(cancellation)?;
        let final_url = Url::parse(&source.final_url)
            .map_err(|error| WebError::new(WebErrorCode::InvalidUrl, error.to_string()))?;
        let base = document_base(&document, &final_url, cancellation)?;
        let mut links = Links::default();
        let metadata = metadata(&document, source, &base, &mut links, cancellation)?;
        content.title = metadata.title;
        content.publications = metadata.publications;
        content.text = body_text(&document, &base, &mut links, cancellation)?;
        content.links = links.values;
    }
    check_cancelled(cancellation)?;
    Ok(content)
}

fn check_cancelled(cancellation: &CancellationToken) -> Result<()> {
    if cancellation.is_cancelled() {
        Err(WebError::cancelled())
    } else {
        Ok(())
    }
}

fn decode_error(message: impl Into<String>) -> WebError {
    WebError::new(WebErrorCode::Decode, message)
}

fn source_encoding(
    bytes: &[u8],
    source: &WebSource,
    kind: ContentKind,
    cancellation: &CancellationToken,
) -> Result<(&'static Encoding, usize)> {
    if let Some(bom) = Encoding::for_bom(bytes) {
        return Ok(bom);
    }
    if let Some(label) = source.content_type.as_deref().and_then(charset_parameter) {
        return Ok((declared_encoding(&label)?, 0));
    }
    if kind == ContentKind::Html
        && let Some(label) = html_charset(bytes, cancellation)?
    {
        let encoding = declared_encoding(&label)?;
        // HTML's meta declaration cannot switch an ASCII-compatible byte stream
        // to UTF-16; a UTF-16 entity is identified by its BOM or HTTP charset.
        return Ok((
            if encoding == UTF_16LE || encoding == UTF_16BE {
                UTF_8
            } else {
                encoding
            },
            0,
        ));
    }
    Ok((UTF_8, 0))
}

fn declared_encoding(label: &str) -> Result<&'static Encoding> {
    Encoding::for_label_no_replacement(label.as_bytes())
        .ok_or_else(|| decode_error(format!("Unsupported declared charset: {label}")))
}

fn decode_chunks(
    bytes: &[u8],
    encoding: &'static Encoding,
    cancellation: &CancellationToken,
    mut consume: impl FnMut(&str) -> Result<()>,
) -> Result<()> {
    let mut decoder = encoding.new_decoder_without_bom_handling();
    let mut output = String::new();
    let mut offset: usize = 0;
    loop {
        check_cancelled(cancellation)?;
        let end = bytes.len().min(offset.saturating_add(DECODE_CHUNK_BYTES));
        let last = end == bytes.len();
        let mut remaining = &bytes[offset..end];
        loop {
            check_cancelled(cancellation)?;
            output.clear();
            let capacity = decoder
                .max_utf8_buffer_length_without_replacement(remaining.len())
                .ok_or_else(|| decode_error("The decoded text cannot fit in memory."))?;
            output
                .try_reserve(capacity)
                .map_err(|error| decode_error(error.to_string()))?;
            let (result, read) =
                decoder.decode_to_string_without_replacement(remaining, &mut output, last);
            if matches!(result, DecoderResult::Malformed(..)) {
                return Err(decode_error(format!(
                    "The response contains invalid {} byte sequences.",
                    encoding.name()
                )));
            }
            consume(&output)?;
            remaining = &remaining[read..];
            if result == DecoderResult::InputEmpty {
                break;
            }
        }
        offset = end;
        if last {
            return check_cancelled(cancellation);
        }
    }
}

// HTTP and meta content attributes use the same quoted charset parameter.
fn charset_parameter(value: &str) -> Option<String> {
    quoted_fields(value).find_map(|field| {
        let (name, value) = field.split_once('=')?;
        if !name.trim().eq_ignore_ascii_case("charset") {
            return None;
        }
        let value = value.trim();
        Some(
            value
                .strip_prefix('"')
                .and_then(|value| value.strip_suffix('"'))
                .or_else(|| {
                    value
                        .strip_prefix('\'')
                        .and_then(|value| value.strip_suffix('\''))
                })
                .unwrap_or(value)
                .to_owned(),
        )
    })
}

fn quoted_fields(mut remaining: &str) -> impl Iterator<Item = &str> {
    std::iter::from_fn(move || {
        if remaining.is_empty() {
            return None;
        }
        let mut quote = None;
        let mut escaped = false;
        let mut parentheses = 0usize;
        for (index, character) in remaining.char_indices() {
            if escaped {
                escaped = false;
            } else if character == '\\' {
                escaped = true;
            } else if let Some(delimiter) = quote {
                if character == delimiter {
                    quote = None;
                }
            } else {
                match character {
                    '\'' | '"' => quote = Some(character),
                    '(' => parentheses += 1,
                    ')' => parentheses = parentheses.saturating_sub(1),
                    ';' if parentheses == 0 => {
                        let field = &remaining[..index];
                        remaining = &remaining[index + 1..];
                        return Some(field);
                    }
                    _ => {}
                }
            }
        }
        let field = remaining;
        remaining = "";
        Some(field)
    })
}

// Inspect actual head tags before decoding. Comments, raw-text elements and
// template contents cannot introduce a document charset declaration.
fn html_charset(bytes: &[u8], cancellation: &CancellationToken) -> Result<Option<String>> {
    let mut offset = 0;
    let mut raw_text: Option<&[u8]> = None;
    let mut templates = 0usize;
    while offset < bytes.len() {
        if offset % 4096 == 0 {
            check_cancelled(cancellation)?;
        }
        if bytes[offset] != b'<' {
            offset += 1;
            continue;
        }
        let start = offset;
        offset += 1;
        if raw_text.is_none() && bytes[start..].starts_with(b"<!--") {
            offset = start + 4;
            while offset < bytes.len() && !bytes[offset..].starts_with(b"-->") {
                if offset % 4096 == 0 {
                    check_cancelled(cancellation)?;
                }
                offset += 1;
            }
            offset = bytes.len().min(offset + 3);
            continue;
        }
        let closing = bytes.get(offset) == Some(&b'/');
        if raw_text.is_some() && !closing {
            continue;
        }
        if closing {
            offset += 1;
        }
        let name_start = offset;
        while bytes
            .get(offset)
            .is_some_and(|byte| !byte.is_ascii_whitespace() && !matches!(*byte, b'/' | b'>' | b'<'))
        {
            offset += 1;
        }
        let name = &bytes[name_start..offset];
        if let Some(raw_name) = raw_text {
            if !closing || !name.eq_ignore_ascii_case(raw_name) {
                continue;
            }
            raw_text = None;
        }
        let mut quote = None;
        while offset < bytes.len() {
            if offset % 4096 == 0 {
                check_cancelled(cancellation)?;
            }
            let byte = bytes[offset];
            offset += 1;
            if let Some(delimiter) = quote {
                if byte == delimiter {
                    quote = None;
                }
            } else if matches!(byte, b'\'' | b'"') {
                quote = Some(byte);
            } else if byte == b'>' {
                break;
            }
        }
        if name.eq_ignore_ascii_case(b"template") {
            if closing {
                templates = templates.saturating_sub(1);
            } else {
                templates += 1;
            }
        }
        if !closing
            && [b"script".as_slice(), b"style", b"title", b"noframes"]
                .iter()
                .any(|raw_name| name.eq_ignore_ascii_case(raw_name))
        {
            raw_text = Some(name);
        }
        if templates != 0 {
            continue;
        }
        if name.eq_ignore_ascii_case(b"body") || (closing && name.eq_ignore_ascii_case(b"head")) {
            break;
        }
        if !closing && name.eq_ignore_ascii_case(b"meta") {
            let tag: String = bytes[start..offset]
                .iter()
                .map(|byte| char::from(*byte))
                .collect();
            let fragment = Html::parse_fragment(&tag);
            for element in fragment.root_element().descendent_elements() {
                if element.value().name() != "meta" {
                    continue;
                }
                if let Some(charset) = element.attr("charset") {
                    return Ok(Some(charset.to_owned()));
                }
                if element
                    .attr("http-equiv")
                    .is_some_and(|value| value.eq_ignore_ascii_case("content-type"))
                    && let Some(charset) = element.attr("content").and_then(charset_parameter)
                {
                    return Ok(Some(charset));
                }
            }
        }
    }
    check_cancelled(cancellation)?;
    Ok(None)
}

fn visit_elements<'a>(
    document: &'a Html,
    cancellation: &CancellationToken,
    mut visit: impl FnMut(ElementRef<'a>) -> Result<bool>,
) -> Result<()> {
    let mut cursor = Some(document.tree.root());
    while let Some(node) = cursor {
        check_cancelled(cancellation)?;
        let descend = match ElementRef::wrap(node) {
            Some(element) => visit(element)?,
            None => true,
        };
        if descend && let Some(child) = node.first_child() {
            cursor = Some(child);
            continue;
        }
        let mut current = node;
        cursor = loop {
            if let Some(sibling) = current.next_sibling() {
                break Some(sibling);
            }
            let Some(parent) = current.parent() else {
                break None;
            };
            current = parent;
        };
    }
    Ok(())
}

fn http_url(base: &Url, reference: &str) -> Option<Url> {
    let url = base.join(reference.trim()).ok()?;
    matches!(url.scheme(), "http" | "https").then_some(url)
}

fn in_head(element: ElementRef<'_>) -> bool {
    element
        .ancestors()
        .filter_map(ElementRef::wrap)
        .any(|ancestor| ancestor.value().name() == "head")
}

fn document_base(
    document: &Html,
    final_url: &Url,
    cancellation: &CancellationToken,
) -> Result<Url> {
    let mut base = None;
    visit_elements(document, cancellation, |element| {
        if element.value().name() == "template" {
            return Ok(false);
        }
        if base.is_none() && element.value().name() == "base" && in_head(element) {
            base = element
                .attr("href")
                .and_then(|href| http_url(final_url, href));
        }
        Ok(true)
    })?;
    Ok(base.unwrap_or_else(|| final_url.clone()))
}

#[derive(Default)]
struct TextWriter {
    value: String,
    pending_breaks: usize,
    pending_space: bool,
    flow_start: usize,
}

impl TextWriter {
    fn line_break(&mut self, count: usize) {
        self.pending_breaks = self.pending_breaks.max(count);
        self.pending_space = false;
    }

    fn flush_breaks(&mut self) {
        if self.value.len() > self.flow_start {
            let existing = self
                .value
                .bytes()
                .rev()
                .take_while(|byte| *byte == b'\n')
                .count();
            for _ in existing..self.pending_breaks {
                self.value.push('\n');
            }
        }
        self.pending_breaks = 0;
    }

    fn text(&mut self, text: &str, pre: bool, cancellation: &CancellationToken) -> Result<()> {
        if pre {
            self.flush_breaks();
            self.pending_space = false;
        }
        for (index, character) in text.chars().enumerate() {
            if index % 4096 == 0 {
                check_cancelled(cancellation)?;
            }
            if pre {
                self.value.push(character);
            } else if html_space(character) {
                self.pending_space = true;
            } else {
                self.flush_breaks();
                if self.pending_space
                    && self.value.len() > self.flow_start
                    && !self.value.ends_with([' ', '\n', '\t'])
                {
                    self.value.push(' ');
                }
                self.pending_space = false;
                self.value.push(character);
            }
        }
        Ok(())
    }

    fn explicit_break(&mut self) {
        self.flush_breaks();
        self.value.push('\n');
        self.pending_space = false;
    }

    fn start_cell(&mut self, first: bool) -> usize {
        if first {
            self.flush_breaks();
        } else {
            self.pending_breaks = 0;
            self.value.push('\t');
        }
        self.pending_space = false;
        let previous = self.flow_start;
        self.flow_start = self.value.len();
        previous
    }

    fn end_cell(&mut self, previous: usize) {
        self.pending_breaks = 0;
        self.pending_space = false;
        self.flow_start = previous;
    }
}

fn html_space(character: char) -> bool {
    matches!(character, ' ' | '\t' | '\n' | '\r' | '\u{000c}')
}

fn normalized(text: &str, cancellation: &CancellationToken) -> Result<String> {
    let mut writer = TextWriter::default();
    writer.text(text, false, cancellation)?;
    Ok(writer.value)
}

#[derive(Clone, Copy)]
struct Rendering {
    visible: bool,
    pre: bool,
}

#[derive(Default)]
struct InlineStyle {
    display_none: bool,
    visible: Option<bool>,
    pre: Option<bool>,
}

fn inline_style(element: ElementRef<'_>) -> InlineStyle {
    let mut declarations: HashMap<String, (String, bool)> = HashMap::new();
    for field in quoted_fields(element.attr("style").unwrap_or_default()) {
        let Some((name, value)) = field.split_once(':') else {
            continue;
        };
        let name = name.trim().to_ascii_lowercase();
        if !matches!(
            name.as_str(),
            "display" | "content-visibility" | "visibility" | "white-space"
        ) {
            continue;
        }
        let value = value.trim().to_ascii_lowercase();
        let (value, important) = match value.strip_suffix("!important") {
            Some(value) => (value.trim().to_owned(), true),
            None => (value, false),
        };
        if declarations
            .get(&name)
            .is_some_and(|(_, previous_important)| *previous_important && !important)
        {
            continue;
        }
        declarations.insert(name, (value, important));
    }
    let value = |name: &str| declarations.get(name).map(|(value, _)| value.as_str());
    InlineStyle {
        display_none: value("display") == Some("none")
            || value("content-visibility") == Some("hidden"),
        visible: match value("visibility") {
            Some("hidden" | "collapse") => Some(false),
            Some("visible") => Some(true),
            _ => None,
        },
        pre: match value("white-space") {
            Some("pre" | "pre-wrap" | "break-spaces") => Some(true),
            Some("normal" | "nowrap") => Some(false),
            _ => None,
        },
    }
}

struct Anchor {
    link: usize,
    text_start: usize,
    fallback: String,
}

struct Frame {
    previous: Rendering,
    skipped: bool,
    anchor: Option<Anchor>,
    cell_flow: Option<usize>,
}

struct ListCounter {
    next: Option<i64>,
    step: i64,
}

fn block_break(name: &str) -> usize {
    match name {
        "address" | "article" | "aside" | "blockquote" | "div" | "dl" | "fieldset"
        | "figcaption" | "figure" | "footer" | "form" | "h1" | "h2" | "h3" | "h4" | "h5" | "h6"
        | "header" | "hr" | "main" | "nav" | "ol" | "p" | "pre" | "section" | "table" | "ul" => 2,
        "dd" | "dt" | "li" | "summary" => 1,
        _ => 0,
    }
}

fn body_text(
    document: &Html,
    base: &Url,
    links: &mut Links,
    cancellation: &CancellationToken,
) -> Result<String> {
    let mut writer = TextWriter::default();
    let mut rendering = Rendering {
        visible: true,
        pre: false,
    };
    let mut frames: Vec<Frame> = Vec::new();
    let mut lists: Vec<ListCounter> = Vec::new();
    let mut rows: Vec<usize> = Vec::new();
    let mut cursor = Some(document.tree.root());
    let mut closing = false;
    while let Some(node) = cursor {
        check_cancelled(cancellation)?;
        let mut descend = true;
        if !closing {
            match node.value() {
                Node::Text(text) if rendering.visible => {
                    writer.text(text, rendering.pre, cancellation)?;
                }
                Node::Element(_) => {
                    let element = ElementRef::wrap(node).expect("element node");
                    let name = element.value().name();
                    let style = inline_style(element);
                    let skipped = matches!(
                        name,
                        "head"
                            | "script"
                            | "style"
                            | "template"
                            | "input"
                            | "textarea"
                            | "select"
                            | "datalist"
                    ) || element.attr("hidden").is_some()
                        || element
                            .attr("aria-hidden")
                            .is_some_and(|value| value.eq_ignore_ascii_case("true"))
                        || style.display_none;
                    let mut frame = Frame {
                        previous: rendering,
                        skipped,
                        anchor: None,
                        cell_flow: None,
                    };
                    descend = !skipped;
                    if !skipped {
                        rendering.visible = style.visible.unwrap_or(rendering.visible);
                        rendering.pre = style.pre.unwrap_or(rendering.pre || name == "pre");
                        let breaks = block_break(name);
                        if breaks != 0 {
                            writer.line_break(breaks);
                        }
                        if matches!(name, "ol" | "ul") {
                            let reversed = element.attr("reversed").is_some();
                            let start = if name == "ol" {
                                let explicit = element
                                    .attr("start")
                                    .and_then(|value| value.trim().parse().ok());
                                let default = if reversed {
                                    let mut count = 0i64;
                                    for child in element.child_elements() {
                                        check_cancelled(cancellation)?;
                                        if child.value().name() == "li" {
                                            count += 1;
                                        }
                                    }
                                    count
                                } else {
                                    1
                                };
                                Some(explicit.unwrap_or(default))
                            } else {
                                None
                            };
                            lists.push(ListCounter {
                                next: start,
                                step: if reversed { -1 } else { 1 },
                            });
                        }
                        if name == "tr" {
                            writer.line_break(1);
                            rows.push(0);
                        }
                        if matches!(name, "td" | "th") {
                            let first = rows.last().is_none_or(|count| *count == 0);
                            frame.cell_flow = Some(writer.start_cell(first));
                            if let Some(count) = rows.last_mut() {
                                *count += 1;
                            }
                        }
                        if name == "li" {
                            let marker = if let Some(counter) = lists.last_mut()
                                && let Some(next) = counter.next
                            {
                                let value = element
                                    .attr("value")
                                    .and_then(|value| value.trim().parse().ok())
                                    .unwrap_or(next);
                                counter.next = Some(value.saturating_add(counter.step));
                                format!("{value}. ")
                            } else {
                                "- ".to_owned()
                            };
                            if rendering.visible {
                                writer.text(&marker, false, cancellation)?;
                            }
                        }
                        if rendering.visible {
                            if name == "br" {
                                writer.explicit_break();
                            }
                            collect_resources(element, base, links, cancellation)?;
                            if name == "a"
                                && let Some(href) = link_href(element)
                                && let Some(link) = links.add(
                                    base,
                                    href,
                                    "",
                                    element.attr("download"),
                                    element.attr("type"),
                                )
                            {
                                frame.anchor = Some(Anchor {
                                    link,
                                    text_start: writer.value.len(),
                                    fallback: element
                                        .attr("aria-label")
                                        .or_else(|| element.attr("title"))
                                        .unwrap_or_default()
                                        .to_owned(),
                                });
                            }
                            if name == "img"
                                && let Some(alt) = element.attr("alt")
                            {
                                writer.text(alt, rendering.pre, cancellation)?;
                            }
                        }
                    }
                    frames.push(frame);
                }
                _ => {}
            }
            if descend && let Some(child) = node.first_child() {
                cursor = Some(child);
                continue;
            }
        }
        if let Some(element) = ElementRef::wrap(node) {
            let frame = frames.pop().expect("matching open element");
            let name = element.value().name();
            if !frame.skipped {
                if let Some(anchor) = frame.anchor {
                    let text = normalized(&writer.value[anchor.text_start..], cancellation)?;
                    links.label(
                        anchor.link,
                        if text.is_empty() {
                            anchor.fallback
                        } else {
                            text
                        },
                    );
                }
                if let Some(previous) = frame.cell_flow {
                    writer.end_cell(previous);
                }
                if matches!(name, "ol" | "ul") {
                    lists.pop();
                }
                if name == "tr" {
                    if rows.pop().is_some_and(|count| count != 0) {
                        writer.explicit_break();
                    }
                } else {
                    let breaks = block_break(name);
                    if breaks != 0 {
                        writer.line_break(breaks);
                    }
                }
            }
            rendering = frame.previous;
        }
        if let Some(sibling) = node.next_sibling() {
            cursor = Some(sibling);
            closing = false;
        } else {
            cursor = node.parent();
            closing = true;
        }
    }
    Ok(writer.value)
}

#[derive(Default)]
struct Links {
    values: Vec<WebLink>,
    indices: HashMap<String, usize>,
}

impl Links {
    fn add(
        &mut self,
        base: &Url,
        reference: &str,
        text: &str,
        download_name: Option<&str>,
        media_type: Option<&str>,
    ) -> Option<usize> {
        let url = http_url(base, reference)?;
        let url = url.as_str().to_owned();
        let index = if let Some(index) = self.indices.get(&url) {
            *index
        } else {
            let index = self.values.len();
            self.values.push(WebLink {
                url: url.clone(),
                text: String::new(),
                download_name: None,
                media_type: None,
            });
            self.indices.insert(url, index);
            index
        };
        let link = &mut self.values[index];
        if link.text.is_empty() {
            link.text = text.to_owned();
        }
        if link.download_name.is_none() {
            link.download_name = download_name
                .filter(|name| !name.is_empty())
                .map(str::to_owned);
        }
        if link.media_type.is_none() {
            link.media_type = media_type
                .filter(|value| !value.is_empty())
                .map(str::to_owned);
        }
        Some(index)
    }

    fn label(&mut self, index: usize, text: String) {
        if self.values[index].text.is_empty() {
            self.values[index].text = text;
        }
    }
}

fn link_href<'a>(element: ElementRef<'a>) -> Option<&'a str> {
    if let Some(href) = element.attr("href") {
        return Some(href);
    }
    let element = element.value();
    if element.name.ns.as_str() != "http://www.w3.org/2000/svg" {
        return None;
    }
    element.attrs.iter().find_map(|(name, value)| {
        (name.ns.as_str() == "http://www.w3.org/1999/xlink" && name.local.as_str() == "href")
            .then_some(&**value)
    })
}

fn collect_resources(
    element: ElementRef<'_>,
    base: &Url,
    links: &mut Links,
    cancellation: &CancellationToken,
) -> Result<()> {
    let name = element.value().name();
    let label = element
        .attr("alt")
        .or_else(|| element.attr("title"))
        .unwrap_or_default();
    let media_type = element.attr("type");
    let attributes: &[&str] = match name {
        "area" => &["href"],
        "img" => &["src", "data-src", "data-original", "data-lazy-src"],
        "source" | "audio" | "embed" | "iframe" => &["src"],
        "video" => &["src", "poster"],
        "object" => &["data"],
        "image" => &["href"],
        _ => &[],
    };
    for &attribute in attributes {
        let reference = if attribute == "href" {
            link_href(element)
        } else {
            element.attr(attribute)
        };
        if let Some(reference) = reference {
            links.add(base, reference, label, element.attr("download"), media_type);
        }
    }
    if matches!(name, "img" | "source") {
        for attribute in ["srcset", "data-srcset"] {
            if let Some(value) = element.attr(attribute) {
                for reference in srcset_urls(value) {
                    check_cancelled(cancellation)?;
                    links.add(base, reference, label, None, media_type);
                }
            }
        }
    }
    Ok(())
}

fn srcset_urls(mut remaining: &str) -> impl Iterator<Item = &str> {
    std::iter::from_fn(move || {
        remaining =
            remaining.trim_start_matches(|character| html_space(character) || character == ',');
        if remaining.is_empty() {
            return None;
        }
        let end = remaining.find(html_space).unwrap_or(remaining.len());
        let url = &remaining[..end];
        remaining = &remaining[end..];
        if url.ends_with(',') {
            return Some(url.trim_end_matches(','));
        }
        let mut parentheses = 0usize;
        let mut descriptor_end = remaining.len();
        for (index, character) in remaining.char_indices() {
            match character {
                '(' => parentheses += 1,
                ')' => parentheses = parentheses.saturating_sub(1),
                ',' if parentheses == 0 => {
                    descriptor_end = index + 1;
                    break;
                }
                _ => {}
            }
        }
        remaining = &remaining[descriptor_end..];
        Some(url)
    })
}

struct Metadata {
    title: Option<String>,
    publications: Vec<WebPublication>,
}

fn metadata(
    document: &Html,
    source: &WebSource,
    base: &Url,
    links: &mut Links,
    cancellation: &CancellationToken,
) -> Result<Metadata> {
    let mut metadata = Metadata {
        title: None,
        publications: Vec::new(),
    };
    let mut pages = HashSet::new();
    for reference in [&source.original_url, &source.final_url] {
        if let Some(url) = http_url(base, reference) {
            pages.insert(page_url(url));
        }
    }
    let mut scripts = Vec::new();
    visit_elements(document, cancellation, |element| {
        let name = element.value().name();
        if name == "template" {
            return Ok(false);
        }
        if name == "script" {
            if element
                .attr("type")
                .is_some_and(|value| value.trim().eq_ignore_ascii_case("application/ld+json"))
            {
                scripts.push(element);
            }
            return Ok(false);
        }
        if !matches!(name, "title" | "meta" | "link") || !in_head(element) {
            return Ok(true);
        }
        if name == "title" && metadata.title.is_none() {
            let mut title = TextWriter::default();
            for text in element.text() {
                title.text(text, false, cancellation)?;
            }
            if !title.value.is_empty() {
                metadata.title = Some(title.value);
            }
        }
        if name == "link" {
            let relations: Vec<_> = element
                .attr("rel")
                .unwrap_or_default()
                .split_ascii_whitespace()
                .collect();
            if let Some(href) = element.attr("href") {
                if relations
                    .iter()
                    .any(|rel| rel.eq_ignore_ascii_case("canonical"))
                    && let Some(url) = http_url(base, href)
                {
                    pages.insert(page_url(url));
                }
                if relations.iter().any(|rel| {
                    ["alternate", "icon", "image_src"]
                        .iter()
                        .any(|kind| rel.eq_ignore_ascii_case(kind))
                }) {
                    links.add(
                        base,
                        href,
                        element.attr("title").unwrap_or_default(),
                        None,
                        element.attr("type"),
                    );
                }
            }
        }
        if name == "meta" {
            for attribute in ["property", "name", "itemprop"] {
                let Some(field) = element.attr(attribute) else {
                    continue;
                };
                let Some(value) = element.attr("content") else {
                    continue;
                };
                if is_publication_field(field) && !value.trim().is_empty() {
                    metadata.publications.push(WebPublication {
                        value: value.to_owned(),
                        evidence: format!("meta[{attribute}=\"{field}\"]@content"),
                    });
                }
                if matches!(
                    field.to_ascii_lowercase().as_str(),
                    "og:image" | "og:image:url" | "og:image:secure_url" | "twitter:image"
                ) {
                    links.add(base, value, "", None, None);
                }
            }
        }
        Ok(true)
    })?;
    let mut articles = Vec::new();
    let mut primary_ids = HashSet::new();
    for (index, script) in scripts.into_iter().enumerate() {
        check_cancelled(cancellation)?;
        let mut text = String::new();
        for part in script.text() {
            check_cancelled(cancellation)?;
            text.push_str(part);
        }
        if let Ok(value) = serde_json::from_str::<Value>(&text) {
            collect_articles(
                &value,
                format!("script[type=\"application/ld+json\"][{}] $", index + 1),
                base,
                &pages,
                &mut primary_ids,
                &mut articles,
                cancellation,
            )?;
        }
        check_cancelled(cancellation)?;
    }
    let single_article = articles.len() == 1;
    for article in articles {
        let primary = article.primary
            || article
                .id
                .as_ref()
                .is_some_and(|id| primary_ids.contains(id));
        let identity = if primary {
            article.explicit_page_identity
        } else {
            article.identity
        };
        if identity != PageIdentity::Other
            && (primary || identity == PageIdentity::Current || single_article)
        {
            metadata.publications.extend(article.publications);
        }
    }
    let mut seen = HashSet::new();
    metadata.publications.retain(|publication| {
        seen.insert((publication.value.clone(), publication.evidence.clone()))
    });
    Ok(metadata)
}

fn is_publication_field(field: &str) -> bool {
    matches!(
        field.to_ascii_lowercase().as_str(),
        "article:published_time"
            | "og:published_time"
            | "datepublished"
            | "citation_publication_date"
            | "citation_date"
            | "dc.date.issued"
            | "dcterms.issued"
            | "pubdate"
            | "publishdate"
            | "publication_date"
            | "publish_time"
            | "pubtime"
            | "parsely-pub-date"
            | "bt:pubdate"
    )
}

fn page_url(mut url: Url) -> String {
    url.set_fragment(None);
    url.into()
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum PageIdentity {
    Current,
    Other,
    Unspecified,
}

struct Article {
    identity: PageIdentity,
    explicit_page_identity: PageIdentity,
    id: Option<String>,
    primary: bool,
    publications: Vec<WebPublication>,
}

fn schema_type(value: &Value, expected: &[&str]) -> bool {
    let matches = |value: &Value| {
        value.as_str().is_some_and(|name| {
            let name = name
                .strip_prefix("https://schema.org/")
                .or_else(|| name.strip_prefix("http://schema.org/"))
                .unwrap_or(name);
            expected.contains(&name)
        })
    };
    value.get("@type").is_some_and(|value| match value {
        Value::Array(values) => values.iter().any(matches),
        _ => matches(value),
    })
}

fn identity_urls(value: &Value, base: &Url) -> Vec<Url> {
    let mut urls = Vec::new();
    let mut pending = vec![value];
    while let Some(value) = pending.pop() {
        match value {
            Value::String(reference) => {
                if let Some(url) = http_url(base, reference) {
                    urls.push(url);
                }
            }
            Value::Array(values) => pending.extend(values.iter()),
            Value::Object(object) => {
                if let Some(value) = object.get("@id").or_else(|| object.get("url")) {
                    pending.push(value);
                }
            }
            _ => {}
        }
    }
    urls
}

fn page_identity(
    value: &Value,
    base: &Url,
    pages: &HashSet<String>,
    fields: &[&str],
) -> PageIdentity {
    for &field in fields {
        let Some(value) = value.get(field) else {
            continue;
        };
        if field == "@id" && value.as_str().is_some_and(|id| id.starts_with('#')) {
            continue;
        }
        let urls = identity_urls(value, base);
        if !urls.is_empty() {
            return if urls.into_iter().any(|url| pages.contains(&page_url(url))) {
                PageIdentity::Current
            } else {
                PageIdentity::Other
            };
        }
    }
    PageIdentity::Unspecified
}

fn collect_articles(
    value: &Value,
    path: String,
    base: &Url,
    pages: &HashSet<String>,
    primary_ids: &mut HashSet<String>,
    articles: &mut Vec<Article>,
    cancellation: &CancellationToken,
) -> Result<()> {
    let mut pending = vec![(value, path, false)];
    while let Some((value, path, primary)) = pending.pop() {
        check_cancelled(cancellation)?;
        if let Value::Array(values) = value {
            pending.extend(
                values
                    .iter()
                    .enumerate()
                    .rev()
                    .map(|(index, value)| (value, format!("{path}[{index}]"), primary)),
            );
            continue;
        }
        if !value.is_object() {
            continue;
        }
        if let Some(graph) = value.get("@graph") {
            pending.push((graph, format!("{path}[\"@graph\"]"), false));
        }
        let identity = page_identity(value, base, pages, &["mainEntityOfPage", "url", "@id"]);
        if schema_type(value, &["WebPage", "ItemPage"])
            && identity != PageIdentity::Other
            && let Some(entity) = value.get("mainEntity")
        {
            primary_ids.extend(identity_urls(entity, base).into_iter().map(String::from));
            pending.push((entity, format!("{path}.mainEntity"), true));
        }
        if !schema_type(
            value,
            &[
                "Article",
                "NewsArticle",
                "BlogPosting",
                "LiveBlogPosting",
                "ScholarlyArticle",
                "TechArticle",
                "Report",
                "SocialMediaPosting",
                "DiscussionForumPosting",
                "MedicalScholarlyArticle",
                "SatiricalArticle",
                "AdvertiserContentArticle",
                "AnalysisNewsArticle",
                "AskPublicNewsArticle",
                "BackgroundNewsArticle",
                "OpinionNewsArticle",
                "ReportageNewsArticle",
                "ReviewNewsArticle",
            ],
        ) {
            continue;
        }
        let mut publications = Vec::new();
        if let Some(date) = value.get("datePublished") {
            let mut dates = vec![(date, format!("{path}.datePublished"))];
            while let Some((date, evidence)) = dates.pop() {
                check_cancelled(cancellation)?;
                match date {
                    Value::String(value) if !value.trim().is_empty() => {
                        publications.push(WebPublication {
                            value: value.clone(),
                            evidence,
                        })
                    }
                    Value::Array(values) => dates.extend(
                        values
                            .iter()
                            .enumerate()
                            .rev()
                            .map(|(index, value)| (value, format!("{evidence}[{index}]"))),
                    ),
                    Value::Object(object) => {
                        if let Some(value) = object.get("@value") {
                            dates.push((value, format!("{evidence}[\"@value\"]")));
                        }
                    }
                    _ => {}
                }
            }
        }
        articles.push(Article {
            identity,
            explicit_page_identity: page_identity(value, base, pages, &["mainEntityOfPage", "url"]),
            id: value
                .get("@id")
                .and_then(Value::as_str)
                .and_then(|id| http_url(base, id))
                .map(String::from),
            primary,
            publications,
        });
    }
    Ok(())
}
