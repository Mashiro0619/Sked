use rig::{completion::PromptError, error::ErrorKind};
use serde_json::Value;

use super::credentials::CredentialGuard;
use crate::storage::models::ProviderFailure;

pub(super) fn from_prompt(error: &PromptError, api_key: &str) -> Option<ProviderFailure> {
    let kind = match error {
        PromptError::Provider(error) => error.kind(),
        PromptError::Report(report) => report.kind,
        _ => return None,
    };
    let status_code = error
        .provider_response_status()
        .map(|status| status.as_u16());
    let code = match status_code {
        Some(300..=399) => "provider.redirectRejected",
        Some(401 | 403) => "provider.authentication",
        Some(429) => "provider.rateLimited",
        Some(_) => "provider.httpFailure",
        None => match kind {
            ErrorKind::Http => "provider.transportFailure",
            ErrorKind::Timeout => "provider.timeout",
            ErrorKind::Url | ErrorKind::Request => "provider.invalidRequest",
            ErrorKind::Json | ErrorKind::Response => "provider.invalidResponse",
            ErrorKind::Provider | ErrorKind::ProviderResponse => "provider.httpFailure",
            _ => return None,
        },
    };
    let guard = CredentialGuard::new(api_key);
    let body = error.provider_response_body();
    let parsed = body.and_then(|body| serde_json::from_str::<Value>(body).ok());
    let response = parsed
        .as_ref()
        .map(|value| value.get("error").unwrap_or(value));
    let message = response.and_then(|value| {
        value
            .get("message")
            .and_then(Value::as_str)
            .or_else(|| value.as_str())
    });
    let response_code = response.and_then(|value| {
        value
            .get("code")
            .filter(|value| !value.is_null())
            .or_else(|| value.get("type"))
    });
    Some(ProviderFailure {
        code: code.into(),
        status_code,
        response_message: message.and_then(|message| guard.diagnostic(message, 8192)),
        response_code: response_code
            .and_then(|value| match value {
                Value::String(value) => Some(value.clone()),
                Value::Number(value) => Some(value.to_string()),
                _ => None,
            })
            .and_then(|code| guard.diagnostic(&code, 256)),
        response_body: body.and_then(|body| guard.diagnostic(body, 32768)),
        request_id: error
            .provider_request_id()
            .and_then(|id| guard.diagnostic(id, 256)),
    })
}
