use std::sync::{Arc, LazyLock};

use base64::{Engine, engine::general_purpose::STANDARD};
use regex::Regex;
use serde_json::Value;

static AUTHORIZATION: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)\b(Bearer|Basic)\s+([^\s,;\"'<>]+)"#).expect("authorization expression")
});
static ASSIGNMENT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)(?:^|[\s{,;])[\"']?(?:api[ _-]?key|api[ _-]?token|access[ _-]?token|refresh[ _-]?token|client[ _-]?secret|secret|password|authorization|proxy[ _-]?authorization|密钥|金鑰|令牌)[\"']?\s*(?::|=|\bis\b)\s*(\"(?:\\.|[^\"\\])*(?:\"|$)|'(?:\\.|[^'\\])*(?:'|$)|[^\s,;}]+)"#).expect("credential assignment expression")
});
static DIAGNOSTIC_ASSIGNMENT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)([\"']?(?:api[ _-]?key|api[ _-]?token|access[ _-]?token|refresh[ _-]?token|client[ _-]?secret|secret|password|authorization|proxy[ _-]?authorization|cookie|set[ _-]?cookie|密钥|金鑰|令牌)[\"']?\s*[:=]\s*)(\"(?:\\.|[^\"\\])*(?:\"|$)|'(?:\\.|[^'\\])*(?:'|$)|[^\s,;}]+)"#).expect("diagnostic credential assignment expression")
});

/// One captured connection's credential. This value never implements Debug.
#[derive(Clone)]
pub(crate) struct CredentialGuard(Arc<str>);

impl CredentialGuard {
    pub fn new(key: &str) -> Self {
        Self(Arc::from(key))
    }

    pub fn error(&self, text: &str) -> String {
        if self.0.is_empty() {
            text.into()
        } else {
            text.replace(self.0.as_ref(), "[redacted]")
        }
    }

    /// Diagnostic excerpts also remove named credentials returned by a service.
    /// Redact before truncating so a boundary never exposes a partial secret.
    pub fn diagnostic(&self, text: &str, limit: usize) -> Option<String> {
        let mut text = text.to_owned();
        if !self.0.is_empty() {
            let encoded = serde_json::to_string(self.0.as_ref()).expect("credential encoding");
            text = text
                .replace(&encoded[1..encoded.len() - 1], "[redacted]")
                .replace(self.0.as_ref(), "[redacted]");
        }
        text = AUTHORIZATION
            .replace_all(&text, "[redacted authorization]")
            .into_owned();
        text = DIAGNOSTIC_ASSIGNMENT
            .replace_all(&text, |captures: &regex::Captures<'_>| {
                let value = &captures[2];
                let quote = if value.starts_with('"') {
                    "\""
                } else if value.starts_with('\'') {
                    "'"
                } else {
                    ""
                };
                format!("{}{quote}[redacted]{quote}", &captures[1])
            })
            .into_owned();
        text.retain(|value| !value.is_control() || matches!(value, '\n' | '\r' | '\t'));
        if text.is_empty() {
            return None;
        }
        let mut chars = text.chars();
        let mut excerpt: String = chars.by_ref().take(limit).collect();
        if chars.next().is_some() {
            excerpt.push('…');
        }
        Some(excerpt)
    }

    pub fn text(&self, text: &str) -> String {
        if self.0.is_empty() {
            return text.into();
        }
        let mut spans = Vec::new();
        if self.0.chars().count() >= 8 {
            spans.extend(
                text.match_indices(self.0.as_ref())
                    .map(|(start, value)| (start, start + value.len())),
            );
        }
        for captures in AUTHORIZATION.captures_iter(text) {
            let value = captures.get(2).expect("authorization value");
            let matches = value.as_str() == self.0.as_ref()
                || captures[1].eq_ignore_ascii_case("basic")
                    && STANDARD
                        .decode(value.as_str())
                        .ok()
                        .and_then(|bytes| String::from_utf8(bytes).ok())
                        .is_some_and(|decoded| {
                            decoded == self.0.as_ref() || decoded.ends_with(&format!(":{}", self.0))
                        });
            if matches {
                spans.push((value.start(), value.end()));
            }
        }
        for captures in ASSIGNMENT.captures_iter(text) {
            let value = captures.get(1).expect("credential value");
            if scalar(value.as_str()) == self.0.as_ref() {
                let quoted = value.as_str().starts_with(['\'', '"']);
                let closed = quoted
                    && value.as_str().len() > 1
                    && value
                        .as_str()
                        .ends_with(value.as_str().chars().next().expect("quote"));
                spans.push((
                    value.start() + usize::from(quoted),
                    value.end() - usize::from(closed),
                ));
            }
        }
        spans.sort_unstable();
        let mut result = String::new();
        let mut end = 0;
        for (start, next) in spans {
            if start < end {
                continue;
            }
            result.push_str(&text[end..start]);
            result.push_str("[redacted]");
            end = next;
        }
        result.push_str(&text[end..]);
        result
    }

    pub fn value(&self, value: &mut Value) {
        self.value_in(value, false);
    }

    fn value_in(&self, value: &mut Value, credential: bool) {
        match value {
            Value::String(text) => {
                *text = if credential && self.credential_value(text) {
                    "[redacted]".into()
                } else {
                    self.text(text)
                };
            }
            Value::Array(values) => values
                .iter_mut()
                .for_each(|value| self.value_in(value, credential)),
            Value::Object(values) => {
                let named = values
                    .get("name")
                    .or_else(|| values.get("key"))
                    .and_then(Value::as_str)
                    .is_some_and(credential_field);
                let entries = std::mem::take(values);
                for (key, mut value) in entries {
                    self.value_in(
                        &mut value,
                        credential || credential_field(&key) || key == "value" && named,
                    );
                    values.insert(self.text(&key), value);
                }
            }
            value if credential && !value.is_null() && value.to_string() == self.0.as_ref() => {
                *value = Value::String("[redacted]".into())
            }
            _ => {}
        }
    }

    pub fn contains_value(&self, value: &Value) -> bool {
        let mut safe = value.clone();
        self.value(&mut safe);
        safe != *value
    }

    fn credential_value(&self, value: &str) -> bool {
        if self.0.is_empty() {
            return false;
        }
        value.trim() == self.0.as_ref()
            || value.split(';').any(|part| {
                part.split_once('=')
                    .is_some_and(|(_, value)| scalar(value.trim()) == self.0.as_ref())
            })
    }
}

fn scalar(value: &str) -> String {
    if value.starts_with('"') {
        return serde_json::from_str::<String>(value)
            .or_else(|_| serde_json::from_str(&format!("{value}\"")))
            .unwrap_or_else(|_| value.into());
    }
    if let Some(value) = value.strip_prefix('\'') {
        return value
            .strip_suffix('\'')
            .unwrap_or(value)
            .replace("\\'", "'")
            .replace("\\\\", "\\");
    }
    value.into()
}

fn credential_field(name: &str) -> bool {
    let name: String = name
        .chars()
        .filter(|ch| !ch.is_whitespace() && !matches!(ch, '_' | '-'))
        .flat_map(char::to_lowercase)
        .collect();
    matches!(
        name.as_str(),
        "apikey"
            | "apitoken"
            | "accesskey"
            | "accesstoken"
            | "refreshtoken"
            | "clientsecret"
            | "secret"
            | "password"
            | "authorization"
            | "proxyauthorization"
            | "credential"
            | "credentials"
            | "token"
            | "bearertoken"
            | "cookie"
            | "setcookie"
            | "密钥"
            | "金鑰"
            | "令牌"
    )
}

/// Holds only a possible credential suffix before publishing the next delta.
/// The complete raw prefix is retained for short-credential field context.
pub(super) struct CredentialStream {
    guard: CredentialGuard,
    raw: String,
    published: usize,
}

impl CredentialStream {
    pub fn new(guard: CredentialGuard) -> Self {
        Self {
            guard,
            raw: String::new(),
            published: 0,
        }
    }
    pub fn push(&mut self, delta: &str) -> String {
        self.raw.push_str(delta);
        let mut end = self.raw.len();
        if !self.guard.0.is_empty() {
            // Include the complete key: short assignments need their delimiter
            // before a following character can rule out a credential value.
            for (offset, _) in self
                .raw
                .char_indices()
                .rev()
                .take(self.guard.0.chars().count())
            {
                if self.guard.0.starts_with(&self.raw[offset..]) {
                    end = end.min(offset);
                }
            }
            for captures in AUTHORIZATION.captures_iter(&self.raw) {
                let value = captures.get(2).expect("authorization value");
                if captures[1].eq_ignore_ascii_case("basic") && value.end() == self.raw.len() {
                    end = end.min(value.start());
                }
            }
        }
        self.publish(end)
    }
    pub fn finish(&mut self) -> String {
        self.publish(self.raw.len())
    }
    pub fn clear(&mut self) {
        self.raw.clear();
        self.published = 0;
    }
    fn publish(&mut self, end: usize) -> String {
        let safe = self.guard.text(&self.raw[..end]);
        // Published content cannot become a credential later: its only
        // potentially matching suffix is held until a following delta.
        let delta = safe.get(self.published..).unwrap_or_default().to_owned();
        self.published = safe.len();
        delta
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn redacts_split_secrets_and_preserves_short_key_prose() {
        let guard = CredentialGuard::new("sk-private-key");
        let mut stream = CredentialStream::new(guard.clone());
        let output = [
            stream.push("error sk-pr"),
            stream.push("ivate-"),
            stream.push("key here"),
            stream.finish(),
        ]
        .concat();
        assert_eq!(output, "error [redacted] here");
        assert_eq!(
            guard.error("HTTP 401: sk-private-key invalid"),
            "HTTP 401: [redacted] invalid"
        );
        let guard = CredentialGuard::new("x");
        assert_eq!(guard.text("exact x coordinate"), "exact x coordinate");
        let mut stream = CredentialStream::new(guard.clone());
        assert_eq!(
            [
                stream.push("api_key: "),
                stream.push("x"),
                stream.push("\nexact"),
                stream.finish()
            ]
            .concat(),
            "api_key: [redacted]\nexact"
        );
        assert_eq!(
            guard.text("Authorization: Basic dXNlcjp4"),
            "Authorization: Basic [redacted]"
        );
        let mut value = json!({"headers": [{"name":"authorization","value":"Bearer x"}], "token": {"value":"x"}, "text":"exact"});
        guard.value(&mut value);
        assert_eq!(value["headers"][0]["value"], "Bearer [redacted]");
        assert_eq!(value["token"]["value"], "[redacted]");
        assert_eq!(value["text"], "exact");
    }
}
