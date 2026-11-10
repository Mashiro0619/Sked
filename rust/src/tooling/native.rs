use crate::runtime::ToolDescriptor;
use serde_json::{Value, json};

fn descriptor(
    name: &str,
    description: &str,
    properties: Value,
    required: &[&str],
) -> ToolDescriptor {
    ToolDescriptor {
        name: name.into(),
        description: description.into(),
        parameters: json!({"type":"object","properties":properties,"required":required,"additionalProperties":false}),
    }
}

pub(super) fn descriptors() -> Vec<ToolDescriptor> {
    let mut tools = vec![
        descriptor(
            "ask_user",
            "Ask for facts or choices needed for the current task. Answers provide information; business approval is separate.",
            json!({"questions":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"title":{"type":"string"},"question":{"type":"string"},"options":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"label":{"type":"string"},"description":{"type":"string"}},"required":["id","label"]}},"multiple":{"type":"boolean"},"allowFreeText":{"type":"boolean"},"required":{"type":"boolean"}},"required":["id","question"]}}}),
            &["questions"],
        ),
        descriptor(
            "update_plan",
            "Update this run's task plan. An empty steps list clears the plan. Completion must follow actual operation receipts.",
            json!({"steps":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"title":{"type":"string"},"status":{"enum":["pending","inProgress","completed","blocked"]},"detail":{"type":"string"},"operationIds":{"type":"array","items":{"type":"string"}}},"required":["id","title","status"]}}}),
            &["steps"],
        ),
        descriptor(
            "skills.search",
            "Find enabled Skills by title, summary, or trigger. Load a Skill before following its full instructions.",
            json!({"query":{"type":"string"},"offset":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1}}),
            &[],
        ),
        descriptor(
            "skills.load",
            "Load the current revision of an enabled Skill into this conversation and discover its available tools.",
            json!({"id":{"type":"string"}}),
            &["id"],
        ),
        descriptor(
            "memories.search",
            "Search shared memories. Recheck live resources before modifying them; memories never grant permission.",
            json!({"query":{"type":"string"},"offset":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1}}),
            &[],
        ),
        descriptor(
            "knowledge.undo",
            "Undo one recorded knowledge operation after checking its current revisions. The host previews in plan mode, asks in confirmation mode, and saves in full mode.",
            json!({"targetOperationId":{"type":"string"}}),
            &["targetOperationId"],
        ),
        descriptor(
            "knowledge.changes.get",
            "Read full details of a knowledge proposal held by this conversation.",
            json!({"proposalId":{"type":"string"}}),
            &["proposalId"],
        ),
        descriptor(
            "conversation.get",
            "Read the current conversation's metadata, plan, pending question, and queue.",
            json!({}),
            &[],
        ),
        descriptor(
            "conversation.history",
            "Read a page of current conversation messages, including complete tool groups.",
            json!({"before":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1},"query":{"type":"string"}}),
            &[],
        ),
        descriptor(
            "conversation.read",
            "Read a current conversation message by its stable ID.",
            json!({"messageId":{"type":"string"}}),
            &["messageId"],
        ),
    ];
    for family in ["skills", "memories"] {
        tools.push(descriptor(
            &format!("{family}.get"),
            "Read one knowledge record and its current revision.",
            json!({"id":{"type":"string"}}),
            &["id"],
        ));
        tools.push(descriptor(&format!("{family}.apply"), "Create, update, delete, enable or restore shared knowledge. Existing records require the revision from get. Built-in Skills cannot be deleted. The host previews in plan mode, asks in confirmation mode, and saves in full mode.", json!({"action":{"enum":["create","update","delete","setEnabled","restoreOriginal"]},"id":{"type":"string"},"revision":{"type":"integer","minimum":0},"title":{"type":"string"},"summary":{"type":"string"},"body":{"type":"string"},"sourceNote":{"type":"string"},"enabled":{"type":"boolean"},"triggers":{"type":"array","items":{"type":"string"}},"requiredTools":{"type":"array","items":{"type":"string"}},"optionalTools":{"type":"array","items":{"type":"string"}}}), &["action"]));
    }
    tools
}
