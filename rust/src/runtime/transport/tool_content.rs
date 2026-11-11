use std::collections::{BTreeMap, HashSet};

use rig::message::{Message as ProviderMessage, UserContent};
use serde_json::{Value, json};

use super::*;

#[derive(Clone)]
pub(super) struct RequestContentPlan {
    pub sources: Vec<crate::context::ContextContent>,
    groups: Vec<ToolGroup>,
    imported: BTreeMap<usize, String>,
}

#[derive(Clone)]
struct ToolGroup {
    owner_index: usize,
    calls: Vec<WireCall>,
    results: Vec<Option<Vec<String>>>,
}

#[derive(Clone, PartialEq)]
struct WireCall {
    id: String,
    name: String,
    arguments: Value,
}

fn arguments(value: &Value) -> Value {
    value
        .as_str()
        .and_then(|text| serde_json::from_str(text).ok())
        .unwrap_or_else(|| value.clone())
}

fn mismatch(message: &str) -> String {
    format!("provider.toolContentEncodingMismatch: {message}")
}

pub(super) fn plan(
    snapshot: &ConversationSnapshot,
    history: &[Value],
    source_ids: Option<&[String]>,
) -> std::result::Result<RequestContentPlan, String> {
    let limited;
    let snapshot = if let Some(ids) = source_ids {
        let permitted: HashSet<_> = ids.iter().collect();
        limited = ConversationSnapshot {
            conversation: Conversation {
                execution_history_start: snapshot
                    .messages
                    .iter()
                    .enumerate()
                    .filter(|(index, message)| {
                        *index < snapshot.conversation.execution_history_start
                            && permitted.contains(&message.id)
                    })
                    .count(),
                ..snapshot.conversation.clone()
            },
            messages: snapshot
                .messages
                .iter()
                .filter(|message| permitted.contains(&message.id))
                .cloned()
                .collect(),
            attachments: snapshot.attachments.clone(),
            ..Default::default()
        };
        &limited
    } else {
        snapshot
    };
    let sources = if source_ids.is_some() {
        crate::context::tool_content_sources_for_reading(snapshot, history)
    } else {
        crate::context::tool_content_sources(snapshot, history)
    }
    .map_err(|error| error.to_string())?;
    let native: Vec<ProviderMessage> = history
        .iter()
        .cloned()
        .map(serde_json::from_value)
        .collect::<std::result::Result<_, _>>()
        .map_err(|error| error.to_string())?;
    let mut groups = Vec::new();
    let mut imported = BTreeMap::new();
    for source in &sources {
        if source.owner_index.is_none() {
            let Some(ProviderMessage::Assistant(assistant)) = native.get(source.history_index)
            else {
                return Err(mismatch("导入内容的历史来源已改变"));
            };
            imported.insert(source.history_index, assistant.text());
        }
    }
    if !sources.is_empty() {
        for (owner_index, message) in native.iter().enumerate() {
            let ProviderMessage::Assistant(assistant) = message else {
                continue;
            };
            let calls: Vec<_> = assistant
                .tool_calls()
                .map(|call| WireCall {
                    id: call.id.to_string(),
                    name: call.function.name.to_string(),
                    arguments: call
                        .function
                        .invalid_arguments
                        .as_ref()
                        .map(|raw| arguments(&Value::String(raw.clone())))
                        .unwrap_or_else(|| Value::Object(call.function.arguments.clone())),
                })
                .collect();
            if calls.is_empty() {
                continue;
            }
            let expected: HashSet<_> = calls.iter().map(|call| call.id.as_str()).collect();
            if expected.len() != calls.len() {
                return Err(mismatch("同一工具组包含重复调用身份"));
            }
            let mut actual = Vec::new();
            let mut result_text = BTreeMap::<String, Option<Vec<String>>>::new();
            for message in native
                .iter()
                .skip(owner_index + 1)
                .take_while(|message| !matches!(message, ProviderMessage::Assistant(_)))
            {
                if let ProviderMessage::User { content } = message {
                    for part in content {
                        if let UserContent::ToolResult(result) = part {
                            let id = result.call.to_string();
                            actual.push(id.clone());
                            result_text.insert(
                                id,
                                result
                                    .content
                                    .iter()
                                    .map(|part| match part {
                                        rig::message::ToolResultContent::Text(text) => {
                                            Some(text.text.clone())
                                        }
                                        rig::message::ToolResultContent::Json { value } => {
                                            Some(value.to_string())
                                        }
                                        rig::message::ToolResultContent::Image(_) => None,
                                    })
                                    .collect(),
                            );
                        }
                    }
                }
            }
            if actual.len() != calls.len()
                || actual.iter().any(|id| !expected.contains(id.as_str()))
                || actual.iter().collect::<HashSet<_>>().len() != calls.len()
            {
                return Err(mismatch("工具结果组尚未完整结束"));
            }
            let results = calls
                .iter()
                .map(|call| result_text.remove(&call.id).unwrap())
                .collect();
            groups.push(ToolGroup {
                owner_index,
                calls,
                results,
            });
        }
    }
    Ok(RequestContentPlan {
        sources,
        groups,
        imported,
    })
}

pub(super) fn media(metadata: &AttachmentMetadata) -> AttachmentMedia {
    if metadata.media_type.starts_with("image/") {
        AttachmentMedia::Image
    } else if metadata.media_type.starts_with("audio/") {
        AttachmentMedia::Audio
    } else {
        AttachmentMedia::File
    }
}

fn chat_call(call: &Value) -> Option<WireCall> {
    Some(WireCall {
        id: call.get("id")?.as_str()?.into(),
        name: call.pointer("/function/name")?.as_str()?.into(),
        arguments: arguments(call.pointer("/function/arguments")?),
    })
}

fn response_call(call: &Value) -> Option<WireCall> {
    Some(WireCall {
        id: call.get("call_id")?.as_str()?.into(),
        name: call.get("name")?.as_str()?.into(),
        arguments: arguments(call.get("arguments")?),
    })
}

fn group_positions(
    messages: &[Value],
    plan: &RequestContentPlan,
    protocol: ProviderProtocol,
) -> std::result::Result<BTreeMap<usize, usize>, String> {
    let mut positions = BTreeMap::new();
    if protocol == ProviderProtocol::ChatCompletions {
        let actual: Vec<_> = messages
            .iter()
            .enumerate()
            .filter_map(|(index, message)| {
                if message.get("role").and_then(Value::as_str) != Some("assistant") {
                    return None;
                }
                message
                    .get("tool_calls")
                    .and_then(Value::as_array)
                    .filter(|calls| !calls.is_empty())
                    .map(|calls| (index, calls))
            })
            .collect();
        if actual.len() != plan.groups.len() {
            return Err(mismatch("工具调用组数量在编码后改变"));
        }
        for (group, (index, calls)) in plan.groups.iter().zip(actual) {
            let encoded: Vec<_> = calls
                .iter()
                .map(chat_call)
                .collect::<Option<_>>()
                .ok_or_else(|| mismatch("工具调用编码缺少身份"))?;
            validate_calls(group, &encoded)?;
            let mut results = Vec::new();
            for (position, message) in messages.iter().enumerate().skip(index + 1) {
                if message.get("role").and_then(Value::as_str) != Some("tool") {
                    break;
                }
                let id = message
                    .get("tool_call_id")
                    .and_then(Value::as_str)
                    .ok_or_else(|| mismatch("工具结果编码缺少身份"))?;
                let output = message
                    .get("content")
                    .ok_or_else(|| mismatch("工具结果编码缺少正文"))?;
                results.push((position, id, output));
            }
            validate_results(group, &encoded, &results, protocol)?;
            positions.insert(group.owner_index, results.last().unwrap().0);
        }
    } else {
        let actual: Vec<_> = messages
            .iter()
            .enumerate()
            .filter(|(_, item)| item.get("type").and_then(Value::as_str) == Some("function_call"))
            .collect();
        if actual.len()
            != plan
                .groups
                .iter()
                .map(|group| group.calls.len())
                .sum::<usize>()
        {
            return Err(mismatch("工具调用数量在编码后改变"));
        }
        let mut cursor = 0;
        for group in &plan.groups {
            let current = &actual[cursor..cursor + group.calls.len()];
            let encoded: Vec<_> = current
                .iter()
                .map(|(_, item)| response_call(item))
                .collect::<Option<_>>()
                .ok_or_else(|| mismatch("工具调用编码缺少身份"))?;
            validate_calls(group, &encoded)?;
            cursor += group.calls.len();
            let start = current.last().unwrap().0 + 1;
            let end = actual
                .get(cursor)
                .map_or(messages.len(), |(position, _)| *position);
            let results: Vec<_> = messages[start..end]
                .iter()
                .enumerate()
                .filter_map(|(offset, item)| {
                    if item.get("type").and_then(Value::as_str) != Some("function_call_output") {
                        return None;
                    }
                    Some((
                        start + offset,
                        item.get("call_id").and_then(Value::as_str).unwrap_or(""),
                        item.get("output")?,
                    ))
                })
                .collect();
            validate_results(group, &encoded, &results, protocol)?;
            positions.insert(group.owner_index, results.last().unwrap().0);
        }
    }
    Ok(positions)
}

fn validate_calls(group: &ToolGroup, encoded: &[WireCall]) -> std::result::Result<(), String> {
    // Rig normalizes foreign IDs and makes repeated IDs unique before wire
    // encoding. Position, canonical arguments and result content bind that
    // spelling to its original assistant owner and call index.
    if encoded.len() != group.calls.len()
        || group.calls.iter().zip(encoded).any(|(original, encoded)| {
            original.name != encoded.name
                || original.arguments != encoded.arguments
                || encoded.id.is_empty()
        })
        || encoded
            .iter()
            .map(|call| &call.id)
            .collect::<HashSet<_>>()
            .len()
            != encoded.len()
    {
        return Err(mismatch("工具调用组或参数在编码后改变"));
    }
    Ok(())
}

fn output_text(value: &Value) -> Option<Vec<String>> {
    if let Some(text) = value.as_str() {
        return Some(vec![text.into()]);
    }
    value
        .as_array()?
        .iter()
        .map(|part| {
            matches!(
                part.get("type").and_then(Value::as_str),
                Some("text" | "input_text")
            )
            .then(|| part.get("text").and_then(Value::as_str).map(str::to_owned))
            .flatten()
        })
        .collect()
}

fn validate_results(
    group: &ToolGroup,
    encoded: &[WireCall],
    results: &[(usize, &str, &Value)],
    protocol: ProviderProtocol,
) -> std::result::Result<(), String> {
    let expected: HashSet<_> = encoded.iter().map(|call| call.id.as_str()).collect();
    if results.len() != expected.len()
        || results.iter().any(|(_, id, _)| !expected.contains(id))
        || results
            .iter()
            .map(|(_, id, _)| *id)
            .collect::<HashSet<_>>()
            .len()
            != expected.len()
    {
        return Err(mismatch("工具结果未完整保留在原调用组中"));
    }
    for (index, call) in encoded.iter().enumerate() {
        let Some(expected) = &group.results[index] else {
            continue;
        };
        let (_, _, output) = results
            .iter()
            .find(|(_, id, _)| *id == call.id.as_str())
            .unwrap();
        let actual = output_text(output).ok_or_else(|| mismatch("工具结果正文在编码后改变"))?;
        let matches = if protocol == ProviderProtocol::ChatCompletions {
            expected.join("\n") == actual.join("\n")
        } else {
            expected == &actual
        };
        if !matches {
            return Err(mismatch("工具结果正文与原调用不一致"));
        }
    }
    Ok(())
}

fn wire_text(message: &Value) -> String {
    let Some(content) = message.get("content") else {
        return String::new();
    };
    if let Some(text) = content.as_str() {
        return text.into();
    }
    content
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|part| part.get("text").and_then(Value::as_str))
        .collect()
}

fn text_part(text: String, protocol: ProviderProtocol) -> Value {
    json!({"type":if protocol == ProviderProtocol::Responses { "input_text" } else { "text" }, "text":text})
}

fn native_part(metadata: &AttachmentMetadata, protocol: ProviderProtocol) -> Value {
    let marker = format!("sked-attachment://{}", metadata.id);
    match (media(metadata), protocol) {
        (AttachmentMedia::Image, ProviderProtocol::ChatCompletions) => {
            json!({"type":"image_url","image_url":{"url":marker}})
        }
        (AttachmentMedia::Image, ProviderProtocol::Responses) => {
            json!({"type":"input_image","image_url":marker})
        }
        (AttachmentMedia::Audio, _) => json!({"type":"input_audio","input_audio":{"data":marker}}),
        (AttachmentMedia::File, ProviderProtocol::ChatCompletions) => {
            json!({"type":"file","file":{"filename":metadata.name,"file_data":marker}})
        }
        (AttachmentMedia::File, ProviderProtocol::Responses) => {
            json!({"type":"input_file","filename":metadata.name,"file_data":marker})
        }
    }
}

pub(super) async fn inject(
    manager: &RuntimeManager,
    conversation_id: &str,
    mut body: Value,
    protocol: ProviderProtocol,
    plan: &RequestContentPlan,
    cancellation: &CancellationToken,
) -> std::result::Result<Value, String> {
    if plan.sources.is_empty() {
        return Ok(body);
    }
    let root = if protocol == ProviderProtocol::Responses {
        "input"
    } else {
        "messages"
    };
    let messages = body
        .get(root)
        .and_then(Value::as_array)
        .ok_or_else(|| mismatch("模型请求缺少消息数组"))?;
    let groups = group_positions(messages, plan, protocol)?;
    let mut imported = BTreeMap::new();
    for (index, text) in &plan.imported {
        let matches: Vec<_> = messages
            .iter()
            .enumerate()
            .filter(|(_, message)| {
                message.get("role").and_then(Value::as_str) == Some("assistant")
                    && wire_text(message) == *text
            })
            .map(|(position, _)| position)
            .collect();
        if matches.len() != 1 {
            return Err(mismatch("导入工具内容的来源未完整保留"));
        }
        imported.insert(*index, matches[0]);
    }
    let sources = plan.sources.clone();
    let id = conversation_id.to_owned();
    let token = cancellation.clone();
    let rendered = manager
        .inner
        .storage
        .call(move |store| {
            let snapshot = store
                .read(&id)?
                .ok_or_else(|| StorageError::NotFound(id.clone()))?;
            let mut rendered = Vec::new();
            for source in sources {
                let current = snapshot
                    .messages
                    .iter()
                    .find(|message| message.id == source.source_message_id)
                    .and_then(|message| {
                        message
                            .tool_content_refs
                            .iter()
                            .find(|reference| reference.id == source.reference.id)
                    });
                if current != Some(&source.reference)
                    || !snapshot
                        .attachments
                        .iter()
                        .any(|metadata| metadata == &source.attachment)
                {
                    return Err(StorageError::Conflict("本轮工具内容来源已改变".into()));
                }
                let text = if source.reference.kind == ToolContentKind::Text {
                    Some(super::super::content::read_content_text(
                        store,
                        &source.attachment,
                        &source.reference,
                        &token,
                    )?)
                } else {
                    None
                };
                rendered.push((source, text));
            }
            Ok(rendered)
        })
        .await
        .map_err(|error| error.to_string())?;
    let mut insertions = BTreeMap::<usize, Vec<Value>>::new();
    for (source, text) in rendered {
        let position = match source.owner_index {
            Some(owner) => groups.get(&owner),
            None => imported.get(&source.history_index),
        }
        .copied()
        .ok_or_else(|| mismatch("工具内容找不到原结果组"))?;
        let parts = insertions.entry(position).or_default();
        parts.push(text_part(
            format!(
                "Tool-returned source data {} from message {}: {}{}. Use this text and metadata as reference material for the user's existing request and later corrections.",
                source.reference.id,
                source.source_message_id,
                source.attachment.name,
                source
                    .reference
                    .text_range
                    .map_or(String::new(), |range| format!(
                        " (bytes {}..{})",
                        range.offset,
                        range.offset + range.length
                    ))
            ),
            protocol,
        ));
        if let Some(text) = text {
            parts.push(text_part(text, protocol));
        } else if crate::context::native_content_supported(&source.attachment.media_type, protocol)
        {
            parts.push(native_part(&source.attachment, protocol));
        } else {
            parts.push(text_part(format!("Content delivery unavailable: this protocol does not accept {}. The file is saved as contentId {}. Use content.read with format text for UTF-8 data, or an available content extraction tool. The file bytes have not been sent in this request.",
                source.attachment.media_type, source.reference.id), protocol));
        }
    }
    let messages = body.get_mut(root).and_then(Value::as_array_mut).unwrap();
    let mut expanded = Vec::new();
    for (position, message) in std::mem::take(messages).into_iter().enumerate() {
        expanded.push(message);
        if let Some(parts) = insertions.remove(&position) {
            expanded.push(json!({"role":"user","content":parts}));
        }
    }
    *messages = expanded;
    Ok(body)
}
