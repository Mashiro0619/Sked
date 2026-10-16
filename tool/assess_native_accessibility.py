"""Validate the native report AND its process log without printing frame JSON."""

from pathlib import Path, PureWindowsPath
import argparse
import json
import re


parser = argparse.ArgumentParser()
parser.add_argument("--log", type=Path, required=True)
parser.add_argument("--report", type=Path, required=True)
parser.add_argument("--exit-code", type=int, required=True)
parser.add_argument("--revision", required=True)
args = parser.parse_args()

required_phases = {
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
