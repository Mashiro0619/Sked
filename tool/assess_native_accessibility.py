"""Validate the native report AND its process log without printing frame JSON."""

from pathlib import Path, PureWindowsPath
import argparse
import hashlib
import json
import re


parser = argparse.ArgumentParser()
parser.add_argument("--log", type=Path, required=True)
parser.add_argument("--report", type=Path, required=True)
parser.add_argument("--exit-code", type=int, required=True)
parser.add_argument("--revision", required=True)
args = parser.parse_args()

workspace_required_phases = {
    "populated-student-mount",
    "activate-native-accessibility-provider",
    "native-provider-exposes-controls",
    "student-navigation-tooltip",
    "week-route-open-after-tooltip",
    "week-picker-keyboard-escape",
    "workspace-student-to-general",
    "general-date-tooltip",
    "hovered-date-route-open",
    "date-picker-keyboard-escape",
    "general-navigation-tooltip",
    "event-editor-open-after-tooltip",
    "event-text-and-keyboard-focus",
    "native-provider-exposes-editor-value",
    "draft-workspace-hide",
    "draft-workspace-return",
    "settings-route-over-draft",
    "settings-route-return",
    "dirty-editor-cancel-opens-confirmation",
    "native-provider-exposes-discard-dialog",
    "cancel-discard-keeps-draft",
    "event-save-commits-and-retires-editor",
    "second-editor-open",
    "second-editor-draft",
    "second-editor-cancel",
    "discard-retires-without-saving",
    "native-tree-unmount",
}
agent_suffixes = [
    "mount", "entry", "composer-value", "settings-open", "settings-connection",
    "settings-preferences", "settings-skills", "settings-memory", "settings-return",
    "ask-prepare", "ask-approve-control", "ask-reject-control", "preview-pagination",
    "preview-first-detail", "preview-last-detail",
]
agent_phase_order = [
    f"agent-{name}-{suffix}"
    for name in ("baseline", "accessible")
    for suffix in [*agent_suffixes, "decision-reject" if name == "baseline" else "decision-approve", "unmount"]
]
required_phases = workspace_required_phases | set(agent_phase_order)
reasons = []
native_errors = []
fatal_errors = []
phase = "bootstrap"
plugin_warning = False
long_lines_skipped = 0
with args.log.open("rb") as stream:
    prefix = stream.read(4)
encoding = "utf-16" if prefix[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"
with args.log.open(encoding=encoding, errors="replace") as stream:
    for number, line in enumerate(stream, 1):
        if len(line) > 3000:
            long_lines_skipped += 1
            # Raw driver payloads can contain large frame JSON. Never print it.
            if "Failed to update ui::AXTree" in line:
                native_errors.append({"line": number, "phase": phase, "text": "AXTree rejection in a long log line; inspect locally."})
            continue
        match = re.search(r"SKED_A11Y_PHASE_BEGIN ([^ ]+)", line)
        if match:
            phase = match.group(1).strip()
        if "AXTree" in line or "[ERROR:flutter/shell/platform/common/accessibility_bridge" in line:
            native_errors.append({"line": number, "phase": phase, "text": line.strip()[:400]})
        if any(marker in line.lower() for marker in (
            "lost connection to device", "unhandled exception", "[fatal", "c0000005", "check failed:",
        )):
            fatal_errors.append({"line": number, "phase": phase, "text": line.strip()[:400]})
        if "integration_test plugin was not detected" in line:
            plugin_warning = True

report = {}
if args.report.is_file():
    try:
        candidate = json.loads(args.report.read_text(encoding="utf-8-sig")).get("nativeAccessibility", {})
        if isinstance(candidate, dict):
            report = candidate
        else:
            reasons.append("The native report payload is not an object.")
    except (ValueError, AttributeError) as error:
        reasons.append(f"Invalid native report: {error}")
else:
    reasons.append("The native report was not written.")

phases = report.get("phases", [])
completed_phases = {item.get("phase") for item in phases}
missing_phases = sorted(required_phases - completed_phases)
probes = report.get("nativeProbes", [])
text_probes = [item for item in probes if item.get("expectedText")]
editor_value_probes = [item for item in probes if item.get("phase") == "native-provider-exposes-editor-value"]
discard_dialog_probes = [item for item in probes if item.get("phase") == "native-provider-exposes-discard-dialog"]
control_probes = [item for item in probes if item.get("phase") == "native-provider-exposes-controls"]
text_diagnostics = report.get("textSemanticsDiagnostics", [])
graph_errors = report.get("graphErrors", [])
if args.exit_code != 0:
    reasons.append(f"Flutter/native process exited with {args.exit_code}.")
if report.get("completedInteractions") is not True:
    reasons.append("Interaction and storage assertions did not finish.")
if report.get("platform") != "windows" or report.get("profile") is not True:
    reasons.append("The report is not from a native Windows Profile run.")
if report.get("workspacePanelDisplayMode") != "sideBySide":
    reasons.append("The native fixture did not explicitly exercise the side-by-side panel mode.")
process_id = report.get("processId")
if (
    report.get("nativeApi") != "MSAA"
    or type(process_id) is not int or process_id <= 0
    or not probes
    or any(item.get("nativeApi") != "MSAA" or item.get("processId") != process_id for item in probes)
):
    reasons.append("The report lacks consistent same-process MSAA provider evidence.")
if report.get("revision") != args.revision:
    reasons.append("The report revision does not match the requested checkout.")
if re.fullmatch(r"[0-9a-f]{40}", args.revision) is None:
    reasons.append("The combined native Agent report requires a full source SHA.")
probe_path = report.get("nativeProbePath")
if not isinstance(probe_path, str) or not PureWindowsPath(probe_path).is_absolute():
    reasons.append("The report does not identify an explicitly compiled absolute native probe path.")
if not isinstance(report.get("nativeWorkingDirectory"), str):
    reasons.append("The report omits the native process working directory.")
if report.get("semanticsUpdates", 0) <= 0:
    reasons.append("No native-bound semantics updates were audited.")
if report.get("engineSemanticsEnabled") is not True:
    reasons.append("The native engine did not report semantics enabled.")
if any(
    item.get("engineSemanticsEnabledBefore") is not True
    or item.get("engineSemanticsEnabledAfter") is not True
    or item.get("frameworkSemanticsEnabled") is not True
    for item in phases
):
    reasons.append("Engine and framework semantics must remain enabled in every recorded phase.")
bootstrap = report.get("nativeBootstrap", {})
if bootstrap.get("engineSemanticsEnabledAfter") is not True:
    reasons.append("Native accessibility was not active before the test handle baseline was recorded.")
mount_phases = [item for item in phases if item.get("phase") == "populated-student-mount"]
if len(mount_phases) != 1 or any(
    item.get("engineSemanticsEnabledBefore") is not True
    or item.get("engineSemanticsEnabledAfter") is not True
    or item.get("updatesAfter", 0) <= item.get("updatesBefore", 0)
    for item in mount_phases
):
    reasons.append("The populated tree was not published after native semantics activation.")
if graph_errors or any(item.get("graphErrors", 0) for item in phases):
    reasons.append("The emitted semantics graph contained invalid traversal updates.")
if missing_phases:
    reasons.append("Required phases are missing: " + ", ".join(missing_phases))
if not any(item.get("descendants", 0) > 0 for item in probes):
    reasons.append("Windows MSAA did not expose native descendants.")
if len(control_probes) != 1 or any(item.get("nativeButtons", 0) <= 0 for item in control_probes):
    reasons.append("The initial native provider exposed no actionable buttons; a container is insufficient.")
if len(text_probes) < 2 or any(item.get("matchedExpectedText", 0) <= 0 for item in text_probes):
    reasons.append("Windows MSAA did not confirm the editor value and discard dialog.")
if len(editor_value_probes) != 1 or any(item.get("matchedEditableValues", 0) <= 0 for item in editor_value_probes):
    reasons.append("The native MSAA text-field role did not expose the entered editor value.")
if len(discard_dialog_probes) != 1 or any(
    not item.get("expectedText") or item.get("matchedExpectedText", 0) <= 0 for item in discard_dialog_probes
):
    reasons.append("The original native discard-dialog probe is missing; Agent text probes cannot replace it.")
expected_inputs = {"Native semantics saved event", "Native semantics discarded event"}
if (
    len(text_diagnostics) != 2
    or {item.get("expectedValue") for item in text_diagnostics} != expected_inputs
    or report.get("textInputTransport") != "registered-flutter-test-client"
):
    reasons.append("Both drafts must have explicit registered-input and published-text semantics evidence.")
for item in text_diagnostics:
    expected = item.get("expectedValue")
    node = item.get("publishedEditableNode", {})
    client_id = item.get("textInputClientId")
    if (
        item.get("textInputRegistered") is not True
        or item.get("textInputHasClient") is not True
        or type(client_id) is not int or client_id <= 0
        or item.get("controllerValue") != expected
        or item.get("renderedValue") != expected
        or node.get("isTextField") is not True
        or node.get("value") != expected
        or node.get("mergedIntoParent") is not False
    ):
        reasons.append("A draft's real input, rendered text and published editable semantics disagree.")


def as_object(value):
    return value if isinstance(value, dict) else {}


def as_objects(value):
    return value if isinstance(value, list) and all(isinstance(item, dict) for item in value) else []


def digest(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def native_matches(item, purpose, *, exact_role=None):
    matches = [
        match
        for root in as_objects(item.get("roots"))
        for match in as_objects(root.get("matches"))
    ]
    if purpose == "editable-value":
        return item.get("matchedEditableValues", 0) > 0 and any(
            match.get("role") == 42 and match.get("valueMatched") is True
            and match.get("value") == item.get("expectedText") for match in matches
        )
    roles = {exact_role} if exact_role is not None else {43, 56, 57, 58, 62} if purpose == "button" else {41, 42}
    return any(
        match.get("role") in roles
        and (match.get("nameMatched") is True or match.get("valueMatched") is True)
        for match in matches
    )


recorded_names = [item.get("phase") for item in phases]
recorded_agent = [name for name in recorded_names if isinstance(name, str) and name.startswith("agent-")]
if recorded_agent != agent_phase_order:
    reasons.append("Both Agent scenarios must finish their full ordered phase sequence exactly once.")
if any(recorded_names.count(name) != 1 for name in workspace_required_phases):
    reasons.append("The original 27 workspace phases must each remain present exactly once.")
if recorded_agent and (
    "native-tree-unmount" not in recorded_names
    or recorded_names.index(recorded_agent[0]) <= max(
        (index for index, name in enumerate(recorded_names) if name in workspace_required_phases), default=-1
    )
):
    reasons.append("Agent coverage must follow the complete original workspace flow and its unmount.")
for item in phases:
    if item.get("phase") in agent_phase_order and item.get("reachableNodes", 0) <= 0:
        reasons.append("An Agent phase did not retain an auditable current semantics tree.")

scenarios = as_objects(report.get("agentScenarios"))
if [as_object(item.get("configuration")).get("name") for item in scenarios] != ["baseline", "accessible"]:
    reasons.append("Separate baseline and accessible Agent scenario reports are required.")
agent_input_checks = 0
agent_settings_page_checks = 0
for scenario in scenarios:
    configuration = as_object(scenario.get("configuration"))
    name = configuration.get("name")
    prefix = f"Agent {name}: "
    accessible = name == "accessible"
    expected_configuration = {
        "brightness": "dark" if accessible else "light",
        "textScale": 2 if accessible else 1,
        "reduceMotion": accessible,
        "disableAnimations": False,
    }
    observed = as_object(scenario.get("observedConfiguration"))
    if any(configuration.get(key) != value or observed.get(key) != value
           for key, value in expected_configuration.items()):
        reasons.append(prefix + "the requested and observed framework configuration disagree.")
    if (
        scenario.get("protocol") != "agent-msaa-v2" or scenario.get("status") != "passed"
        or scenario.get("revision") != args.revision or scenario.get("processId") != process_id
    ):
        reasons.append(prefix + "source, native process or completion evidence is missing.")
    expected_draft = f"Prepare 21 synthetic accessibility events for {name}."
    inputs = as_objects(scenario.get("textSemanticsDiagnostics"))
    agent_input_checks += len(inputs)
    if len(inputs) != 1 or scenario.get("textInputTransport") != "registered-flutter-test-client":
        reasons.append(prefix + "one separate registered composer-input diagnostic is required.")
    for item in inputs:
        node = as_object(item.get("publishedEditableNode"))
        client_id = item.get("textInputClientId")
        if (
            item.get("expectedValue") != expected_draft
            or item.get("textInputRegistered") is not True or item.get("textInputHasClient") is not True
            or type(client_id) is not int or client_id <= 0
            or item.get("controllerValue") != expected_draft or item.get("renderedValue") != expected_draft
            or node.get("isTextField") is not True or node.get("value") != expected_draft
            or node.get("mergedIntoParent") is not False
        ):
            reasons.append(prefix + "composer input, rendering and published editable value disagree.")

    pages = as_objects(scenario.get("settingsPages"))
    agent_settings_page_checks += len(pages)
    titles = ["Connection and models", "Run preferences", "Skills", "Memory"]
    types = ["AgentConnectionSettingsPage", "AgentPreferencesSettingsPage", "AgentKnowledgeView", "AgentKnowledgeView"]
    destinations = ["agent-settings-connection", "agent-settings-preferences", "agent-settings-skills", "agent-settings-memories"]
    if "settingsTabs" in scenario:
        reasons.append(prefix + "the legacy settings-tab report is not hierarchical page evidence.")
    if scenario.get("settingsHierarchy") != "overview / category / item":
        reasons.append(prefix + "the settings overview/category/item hierarchy is not recorded.")
    page_ids = [item.get("id") for item in pages]
    if len(pages) != 4 or len({value for value in page_ids if type(value) is int and value >= 0}) != 4:
        reasons.append(prefix + "four distinct hierarchical settings-page entrances are required.")
    for index, item in enumerate(pages):
        label = item.get("label")
        if (
            index >= 4 or type(item.get("index")) is not int or item.get("index") != index
            or item.get("destination") != destinations[index] or item.get("title") != titles[index]
            or item.get("contentType") != types[index] or item.get("currentChildRoute") is not True
            # Semantics(button: true) can retain SemanticsRole.none. Its explicit
            # button flag and the same-PID MSAA push-button match remain required.
            or item.get("role") not in ("none", "button") or item.get("isButton") is not True
            or not isinstance(label, str) or titles[index] not in label
            or item.get("hasTap") is not True or item.get("selected") is not False
            or item.get("mergedIntoParent") is not False or type(item.get("id")) is not int
            or item.get("id", -1) < 0
            or (index >= 2 and item.get("knowledgeKind") != ("skill" if index == 2 else "memory"))
        ):
            reasons.append(prefix + "a settings-page entrance lost its independent button or corresponding current child page.")
    returned = as_object(scenario.get("settingsReturn"))
    if (returned.get("draftPreserved") is not True or returned.get("mainSnapshotUnchanged") is not True
            or returned.get("providerRequests") != 0):
        reasons.append(prefix + "settings navigation did not preserve the draft and untouched main snapshot.")

    approval = as_object(scenario.get("approval"))
    changes = as_objects(approval.get("changes"))
    planned = [as_object(item.get("after")) for item in changes]
    ids = [item.get("id") for item in planned]
    expected_titles = {f"MSAA {name} event {index:02}" for index in range(1, 22)}
    if (
        approval.get("mode") != "ask" or not isinstance(approval.get("planId"), str)
        or not approval.get("planId") or approval.get("changeCount") != 21 or len(changes) != 21
        or len(set(ids)) != 21 or "native-event" in ids
        or {item.get("title") for item in planned} != expected_titles
    ):
        reasons.append(prefix + "the real Ask plan must contain exactly 21 new, distinct synthetic events.")
    for change, after in zip(changes, planned):
        ref = as_object(change.get("ref"))
        title = after.get("title")
        number = title[-2:] if isinstance(title, str) else ""
        if (
            change.get("before") is not None or ref.get("kind") != "event"
            or ref.get("parentId") != "native-calendar" or ref.get("id") != after.get("id")
            or not isinstance(after.get("id"), str) or not after.get("id")
            or after.get("calendarId") != "native-calendar"
            or after.get("start") != "2026-09-07T15:00:00.000"
            or after.get("end") != "2026-09-07T16:00:00.000"
            or after.get("notes") != f"Native MSAA {name} detail {number}"
            or after.get("reminderBehavior") != "disabled" or after.get("reminders") != []
        ):
            reasons.append(prefix + "a planned object has missing or incorrect concrete content.")
    snapshots = [approval.get(key) for key in (
        "beforeCommittedSha256", "beforeStoredSha256", "pendingCommittedSha256", "pendingStoredSha256"
    )]
    if not all(digest(value) for value in snapshots) or len(set(snapshots)) != 1:
        reasons.append(prefix + "the complete main snapshot changed before the Ask decision.")
    actions = as_objects(scenario.get("approvalActions"))
    if (len(actions) != 2 or {item.get("key") for item in actions} != {"agent-approve", "agent-reject"}
            or len({item.get("id") for item in actions}) != 2
            or any(item.get("hasTap") is not True or item.get("mergedIntoParent") is not False for item in actions)):
        reasons.append(prefix + "approval and rejection must have separate published actions.")

    preview = as_object(scenario.get("preview"))
    details = as_objects(preview.get("details"))
    if (
        preview.get("initialRowCount") != 20 or preview.get("fullRowCount") != 21
        or preview.get("orderedIds") != ids or len(details) != 2
        or [item.get("position") for item in details] != ["first", "last"]
    ):
        reasons.append(prefix + "the full preview did not cross the 20-row boundary and expose both end details.")
    if planned:
        for detail, after in zip(details, [planned[0], planned[-1]]):
            after_digest = hashlib.sha256(json.dumps(after, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()
            if (detail.get("id") != after.get("id") or detail.get("notes") != after.get("notes")
                    or detail.get("beforeIsNull") is not True or detail.get("completeAfterMatches") is not True
                    or detail.get("afterSha256") != after_digest):
                reasons.append(prefix + "expanded full before/after detail does not match its actual plan object.")

    expected_probes = {
        "composer-value": (expected_draft, "editable-value"),
        "settings-connection": (titles[0], "button"),
        "settings-preferences": (titles[1], "button"),
        "settings-skills": (titles[2], "button"),
        "settings-memory": (titles[3], "button"),
        "ask-approve-control": ("Approve these changes", "button"),
        "ask-reject-control": ("Reject", "button"),
        "preview-pagination": ("Show more changes", "button"),
        "preview-first-detail": (planned[0].get("notes") if planned else None, "detail"),
        "preview-last-detail": (planned[-1].get("notes") if planned else None, "detail"),
    }
    for suffix, (expected, purpose) in expected_probes.items():
        matching = [item for item in probes if item.get("phase") == f"agent-{name}-{suffix}"]
        if len(matching) != 1 or any(
            item.get("expectedText") != expected or not expected or item.get("purpose") != purpose
            or item.get("configuration") != name or item.get("matchedExpectedText", 0) <= 0
            or not native_matches(item, purpose, exact_role=43 if suffix.startswith("settings-") else None)
            for item in matching
        ):
            reasons.append(prefix + f"same-process MSAA {purpose} evidence is missing for {suffix}.")

    provider = as_object(scenario.get("provider"))
    provider_result = as_object(provider.get("result"))
    if (
        provider.get("requests") != (4 if accessible else 3) or provider.get("requestedTools") != [
            "capabilities.describe", "mutation.prepare", "mutation.commit"
        ] or provider.get("transportAttempts") != 0 or provider.get("closed") is not True
        or provider.get("preparedPlanId") != approval.get("planId") or scenario.get("httpOperationAttempts") != 0
    ):
        reasons.append(prefix + "the controlled decision-specific tool flow or zero-HTTP/closed-provider evidence is incomplete.")
    decision = as_object(scenario.get("decision"))
    tool_result = as_object(decision.get("toolResult"))
    terminal = as_object(decision.get("terminal"))
    commit_call_id = f"native-msaa-{name}-3"
    if (
        decision.get("toolCallId") != commit_call_id
        or terminal.get("runtimeActive") is not False
        or terminal.get("phase") != ("idle" if accessible else "failed")
        or terminal.get("errorCode") != (None if accessible else "operation.cancelled")
        or terminal.get("pendingApproval") is not False or terminal.get("recoveryRequired") is not False
        or terminal.get("conversationStatus") != ("idle" if accessible else "interrupted")
        or not digest(terminal.get("conversationSha256"))
        or terminal.get("storedConversationSha256") != terminal.get("conversationSha256")
        or terminal.get("runStatus") != ("completed" if accessible else "interrupted")
        or terminal.get("settled") is not True or terminal.get("requestCount") != (4 if accessible else 3)
        or terminal.get("requestOutcomes") != ["completed"] * (4 if accessible else 3)
        or terminal.get("toolOutcomes") != ["completed", "completed", "completed" if accessible else "failed"]
        or terminal.get("lastMessageRole") != ("assistant" if accessible else "tool")
        or terminal.get("lastMessageToolCallId") != (None if accessible else commit_call_id)
        or terminal.get("finalProviderReply") is not accessible
        or (provider_result != tool_result if accessible else provider.get("result") is not None)
    ):
        reasons.append(prefix + "the persisted commit tool result and completed runtime state are inconsistent.")
    after_hash = decision.get("afterStoredSha256")
    if (
        decision.get("action") != ("approve" if accessible else "reject")
        or decision.get("beforeCommittedSha256") != approval.get("beforeCommittedSha256")
        or decision.get("beforeStoredSha256") != approval.get("beforeStoredSha256")
        or not digest(after_hash) or decision.get("afterCommittedSha256") != after_hash
        or decision.get("eventCountBefore") != 1 or decision.get("originalLongHistoryPreserved") is not True
        or as_object(scenario.get("storageAfterCleanup")).get("mainSha256") != after_hash
    ):
        reasons.append(prefix + "the decision lacks complete matching persisted/committed snapshot evidence.")
    if accessible:
        receipt_ids = decision.get("receiptIds", [])
        verified_ids = decision.get("verifiedCreatedIds", [])
        if (
            after_hash == decision.get("beforeStoredSha256") or decision.get("eventCountAfter") != 22
            or decision.get("receiptCount") != 1 or decision.get("receiptStatus") != "committed"
            or decision.get("receiptChangeCount") != 21 or len(receipt_ids) != 21 or set(receipt_ids) != set(ids)
            or len(verified_ids) != 21 or set(verified_ids) != set(ids)
            or decision.get("unrelatedSnapshotPreserved") is not True or decision.get("committedReceiptCard") is not True
            or not decision.get("operationId") or decision.get("operationId") != provider_result.get("operationId")
            or provider_result.get("status") != "committed"
        ):
            reasons.append(prefix + "approval did not prove all 21 persisted objects and their exact stored receipt.")
    elif (
        after_hash != decision.get("beforeStoredSha256") or decision.get("eventCountAfter") != 1
        or decision.get("receiptCount") != 0 or decision.get("errorCode") != "cancelled"
        or tool_result.get("status") != "not_executed"
        or as_object(tool_result.get("error")).get("code") != "cancelled"
    ):
        reasons.append(prefix + "rejection must leave the whole main snapshot unchanged and create no receipt.")
    cleanup = as_object(scenario.get("cleanup"))
    owners = as_object(cleanup.get("owners"))
    steps = as_objects(owners.get("steps"))
    expected_steps = ["cancel-active-run", "quiesce", "dispose-runtime", "close-agent", "close-backup-staging",
                      "close-session", "drain-main-writes", "flush-layout", "release-owned-preferences"]
    if (
        cleanup.get("unmount") != "complete" or cleanup.get("httpGuardRestored") is not True
        or owners.get("status") != "complete" or [item.get("name") for item in steps] != expected_steps
        or any(item.get("status") != "complete" for item in steps)
        or any(key.endswith("Failure") for key in cleanup)
    ):
        reasons.append(prefix + "UI unmount, owner draining or HTTP-guard restoration did not finish.")

if native_errors:
    reasons.append(f"The native accessibility bridge logged {len(native_errors)} rejected updates.")
if fatal_errors:
    reasons.append(f"The native process logged {len(fatal_errors)} crash/exception markers.")

assessment = {
    "passed": not reasons,
    "reasons": reasons,
    "revision": args.revision,
    "nativeApi": report.get("nativeApi"),
    "workspacePanelDisplayMode": report.get("workspacePanelDisplayMode"),
    "processExitCode": args.exit_code,
    "semanticsUpdates": report.get("semanticsUpdates"),
    "graphErrorCount": len(graph_errors),
    "completedPhases": len(completed_phases),
    "requiredPhases": len(required_phases),
    "requiredWorkspacePhases": len(workspace_required_phases),
    "requiredAgentPhases": len(agent_phase_order),
    "agentScenarioCount": len(scenarios),
    "agentTextSemanticsChecks": agent_input_checks,
    "agentSettingsPageChecks": agent_settings_page_checks,
    "agentNativeProbeCount": sum(item.get("configuration") in ("baseline", "accessible") for item in probes),
    "nativeProbeCount": len(probes),
    "nativeControlProbeCount": len(control_probes),
    "nativeButtonCounts": [item.get("nativeButtons", 0) for item in control_probes],
    "engineSemanticsEnabled": report.get("engineSemanticsEnabled"),
    "textSemanticsChecks": len(text_diagnostics),
    "nativeErrorCount": len(native_errors),
    "nativeErrorSamples": native_errors[:8],
    "fatalErrorCount": len(fatal_errors),
    "fatalErrorSamples": fatal_errors[:5],
    "integrationPluginWarning": plugin_warning,
    "longLinesSkipped": long_lines_skipped,
    "log": str(args.log.resolve()),
    "report": str(args.report.resolve()),
    "attribution": "No source-versus-engine conclusion is inferred from log presence alone.",
}
destination = args.report.parent / "native-accessibility-assessment.json"
destination.write_text(json.dumps(assessment, indent=2) + "\n", encoding="utf-8")
print(json.dumps(assessment, ensure_ascii=False))
raise SystemExit(0 if assessment["passed"] else 1)
