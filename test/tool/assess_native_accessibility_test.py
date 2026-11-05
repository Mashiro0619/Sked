"""Exercise the report assessor with synthetic data, never native UI evidence."""

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest


ASSESSOR = Path(__file__).resolve().parents[2] / "tool" / "assess_native_accessibility.py"
REVISION = "0123456789abcdef0123456789abcdef01234567"
PROCESS_ID = 1234
WORKSPACE_PHASES = [
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
]
AGENT_PHASES = [
    "mount", "entry", "composer-value", "settings-open", "settings-connection",
    "settings-preferences", "settings-skills", "settings-memory", "settings-return",
    "ask-prepare", "ask-approve-control", "ask-reject-control", "preview-pagination",
    "preview-first-detail", "preview-last-detail",
]
SETTINGS_PAGES = [
    ("agent-settings-connection", "Connection and models", "AgentConnectionSettingsPage"),
    ("agent-settings-preferences", "Run preferences", "AgentPreferencesSettingsPage"),
    ("agent-settings-skills", "Skills", "AgentKnowledgeView"),
    ("agent-settings-memories", "Memory", "AgentKnowledgeView"),
]


def input_diagnostic(value):
    return {
        "expectedValue": value,
        "textInputRegistered": True,
        "textInputHasClient": True,
        "textInputClientId": 1,
        "controllerValue": value,
        "renderedValue": value,
        "publishedEditableNode": {
            "isTextField": True, "value": value, "mergedIntoParent": False,
        },
    }


def native_probe(phase, text, purpose, role, configuration=None):
    return {
        "phase": phase,
        "configuration": configuration,
        "purpose": purpose,
        "nativeApi": "MSAA",
        "processId": PROCESS_ID,
        "expectedText": text,
        "matchedExpectedText": 1,
        "matchedEditableValues": 1 if purpose == "editable-value" else 0,
        "nativeButtons": 1,
        "descendants": 1,
        "roots": [{"matches": [{
            "role": role, "nameMatched": True, "valueMatched": True,
            "value": text,
        }]}],
    }


def object_digest(value):
    return hashlib.sha256(
        json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode()
    ).hexdigest()


def agent_scenario(name):
    accessible = name == "accessible"
    draft = f"Prepare 21 synthetic accessibility events for {name}."
    settings = []
    for index, (destination, title, content_type) in enumerate(SETTINGS_PAGES):
        page = {
            "index": index, "destination": destination, "title": title,
            "currentChildRoute": True, "contentType": content_type,
            "id": 100 + index, "label": title, "role": "none",
            "isButton": True, "hasTap": True, "selected": False,
            "mergedIntoParent": False,
        }
        if index >= 2:
            page["knowledgeKind"] = "skill" if index == 2 else "memory"
        settings.append(page)
    events = [{
        "id": f"fixture-{name}-{index:02}", "calendarId": "native-calendar",
        "title": f"MSAA {name} event {index:02}",
        "start": "2026-09-07T15:00:00.000", "end": "2026-09-07T16:00:00.000",
        "notes": f"Native MSAA {name} detail {index:02}",
        "reminderBehavior": "disabled", "reminders": [],
    } for index in range(1, 22)]
    changes = [{
        "before": None, "after": event,
        "ref": {"kind": "event", "parentId": "native-calendar", "id": event["id"]},
    } for event in events]
    before_hash = "a" * 64
    after_hash = "b" * 64 if accessible else before_hash
    result = {"status": "committed", "operationId": "fixture-operation"} if accessible else None
    tool_result = result if accessible else {"status": "not_executed", "error": {"code": "cancelled"}}
    configuration = {
        "name": name, "brightness": "dark" if accessible else "light",
        "textScale": 2 if accessible else 1,
        "reduceMotion": accessible, "disableAnimations": False,
    }
    decision = {
        "action": "approve" if accessible else "reject",
        "toolCallId": f"native-msaa-{name}-3", "toolResult": tool_result,
        "beforeCommittedSha256": before_hash, "beforeStoredSha256": before_hash,
        "afterCommittedSha256": after_hash, "afterStoredSha256": after_hash,
        "eventCountBefore": 1, "eventCountAfter": 22 if accessible else 1,
        "originalLongHistoryPreserved": True,
        "receiptCount": 1 if accessible else 0,
        "terminal": {
            "runtimeActive": False, "phase": "idle" if accessible else "failed",
            "errorCode": None if accessible else "operation.cancelled",
            "pendingApproval": False, "recoveryRequired": False,
            "conversationStatus": "idle" if accessible else "interrupted",
            "conversationSha256": "c" * 64, "storedConversationSha256": "c" * 64,
            "runStatus": "completed" if accessible else "interrupted", "settled": True,
            "requestCount": 4 if accessible else 3,
            "requestOutcomes": ["completed"] * (4 if accessible else 3),
            "toolOutcomes": ["completed", "completed", "completed" if accessible else "failed"],
            "lastMessageRole": "assistant" if accessible else "tool",
            "lastMessageToolCallId": None if accessible else f"native-msaa-{name}-3",
            "finalProviderReply": accessible,
        },
    }
    if accessible:
        decision.update({
            "receiptStatus": "committed", "receiptChangeCount": 21,
            "receiptIds": [event["id"] for event in events],
            "verifiedCreatedIds": [event["id"] for event in events],
            "unrelatedSnapshotPreserved": True, "committedReceiptCard": True,
            "operationId": result["operationId"],
        })
    else:
        decision["errorCode"] = "cancelled"
    scenario = {
        "protocol": "agent-msaa-v2", "status": "passed", "revision": REVISION,
        "processId": PROCESS_ID, "configuration": configuration,
        "observedConfiguration": deepcopy(configuration),
        "textInputTransport": "registered-flutter-test-client",
        "textSemanticsDiagnostics": [input_diagnostic(draft)],
        "settingsHierarchy": "overview / category / item", "settingsPages": settings,
        "settingsReturn": {"draftPreserved": True, "mainSnapshotUnchanged": True, "providerRequests": 0},
        "approval": {
            "mode": "ask", "planId": "fixture-plan", "changeCount": 21, "changes": changes,
            "beforeCommittedSha256": before_hash, "beforeStoredSha256": before_hash,
            "pendingCommittedSha256": before_hash, "pendingStoredSha256": before_hash,
        },
        "approvalActions": [{"key": key, "id": 200 + index, "hasTap": True, "mergedIntoParent": False}
                            for index, key in enumerate(["agent-approve", "agent-reject"])],
        "preview": {
            "initialRowCount": 20, "fullRowCount": 21,
            "orderedIds": [event["id"] for event in events],
            "details": [{
                "position": position, "id": event["id"], "notes": event["notes"],
                "beforeIsNull": True, "completeAfterMatches": True, "afterSha256": object_digest(event),
            } for position, event in [("first", events[0]), ("last", events[-1])]],
        },
        "provider": {
            "requests": 4 if accessible else 3,
            "requestedTools": ["capabilities.describe", "mutation.prepare", "mutation.commit"],
            "transportAttempts": 0, "closed": True, "preparedPlanId": "fixture-plan", "result": result,
        },
        "httpOperationAttempts": 0, "decision": decision,
        "storageAfterCleanup": {"mainSha256": after_hash},
        "cleanup": {
            "unmount": "complete", "httpGuardRestored": True,
            "owners": {"status": "complete", "steps": [
                {"name": step, "status": "complete"} for step in [
                    "cancel-active-run", "quiesce", "dispose-runtime", "close-agent",
                    "close-backup-staging", "close-session", "drain-main-writes", "flush-layout",
                    "release-owned-preferences",
                ]
            ]},
        },
    }
    probes = [native_probe(f"agent-{name}-composer-value", draft, "editable-value", 42, name)]
    for index, suffix in enumerate(["connection", "preferences", "skills", "memory"]):
        probes.append(native_probe(f"agent-{name}-settings-{suffix}", settings[index]["title"], "button", 43, name))
    for suffix, label, purpose, role in [
        ("ask-approve-control", "Approve these changes", "button", 43),
        ("ask-reject-control", "Reject", "button", 43),
        ("preview-pagination", "Show more changes", "button", 43),
        ("preview-first-detail", events[0]["notes"], "detail", 41),
        ("preview-last-detail", events[-1]["notes"], "detail", 41),
    ]:
        probes.append(native_probe(f"agent-{name}-{suffix}", label, purpose, role, name))
    return scenario, probes


def valid_report():
    phase_names = list(WORKSPACE_PHASES)
    scenarios = []
    probes = [
        native_probe("native-provider-exposes-controls", None, "button", 43),
        native_probe("native-provider-exposes-editor-value", "Native semantics saved event", "editable-value", 42),
        native_probe("native-provider-exposes-discard-dialog", "Discard changes?", "detail", 41),
    ]
    for name in ["baseline", "accessible"]:
        scenario, agent_probes = agent_scenario(name)
        scenarios.append(scenario)
        probes.extend(agent_probes)
        suffixes = AGENT_PHASES + ["decision-approve" if name == "accessible" else "decision-reject", "unmount"]
        phase_names.extend(f"agent-{name}-{suffix}" for suffix in suffixes)
    return {"nativeAccessibility": {
        "completedInteractions": True, "platform": "windows", "profile": True,
        "workspacePanelDisplayMode": "sideBySide", "processId": PROCESS_ID,
        "nativeApi": "MSAA", "revision": REVISION,
        "nativeProbePath": r"C:\fixture\tool\probe_native_accessibility.ps1",
        "nativeWorkingDirectory": r"C:\fixture", "semanticsUpdates": len(phase_names),
        "engineSemanticsEnabled": True, "nativeBootstrap": {"engineSemanticsEnabledAfter": True},
        "phases": [{
            "phase": phase, "engineSemanticsEnabledBefore": True,
            "engineSemanticsEnabledAfter": True, "frameworkSemanticsEnabled": True,
            "updatesBefore": index, "updatesAfter": index + 1, "reachableNodes": 1,
        } for index, phase in enumerate(phase_names)],
        "nativeProbes": probes, "graphErrors": [],
        "textInputTransport": "registered-flutter-test-client",
        "textSemanticsDiagnostics": [input_diagnostic(value) for value in [
            "Native semantics saved event", "Native semantics discarded event",
        ]],
        "agentScenarios": scenarios,
    }}


class NativeAccessibilityAssessorTest(unittest.TestCase):
    def assess(self, fixture, log_text="Synthetic assessor fixture only.\n"):
        with TemporaryDirectory(prefix="sked-native-assessor-test-") as temporary:
            root = Path(temporary)
            report = root / "native-accessibility.json"
            report.write_text(json.dumps(fixture), encoding="utf-8")
            log = root / "run.log"
            log.write_text(log_text, encoding="utf-8")
            result = subprocess.run([
                sys.executable, "-B", str(ASSESSOR), "--log", str(log),
                "--report", str(report), "--exit-code", "0", "--revision", REVISION,
            ], capture_output=True, text=True, timeout=15, check=False)
            self.assertIn(result.returncode, [0, 1], result.stderr)
            assessment = json.loads((root / "native-accessibility-assessment.json").read_text(encoding="utf-8"))
            self.assertEqual(json.loads(result.stdout), assessment)
            self.assertEqual(result.returncode, 0 if assessment["passed"] else 1)
            return assessment

    def assert_rejected(self, fixture, reason):
        assessment = self.assess(fixture)
        self.assertFalse(assessment["passed"])
        self.assertTrue(any(reason in item for item in assessment["reasons"]), assessment["reasons"])

    def test_hierarchical_pages_pass_with_exact_native_push_buttons(self):
        assessment = self.assess(valid_report())
        self.assertTrue(assessment["passed"], assessment["reasons"])
        self.assertEqual(assessment["agentSettingsPageChecks"], 8)
        self.assertEqual(assessment["requiredPhases"], 61)
        self.assertEqual(assessment["requiredAgentPhases"], 34)

    def test_explicit_semantics_button_role_also_passes(self):
        fixture = valid_report()
        for scenario in fixture["nativeAccessibility"]["agentScenarios"]:
            for page in scenario["settingsPages"]:
                page["role"] = "button"
        assessment = self.assess(fixture)
        self.assertTrue(assessment["passed"], assessment["reasons"])

    def test_missing_malformed_and_incomplete_page_lists_fail(self):
        for pages in [None, {}, [None], [], valid_report()["nativeAccessibility"]["agentScenarios"][0]["settingsPages"][:3]]:
            with self.subTest(pages=type(pages).__name__, count=len(pages) if isinstance(pages, list) else None):
                fixture = valid_report()
                scenario = fixture["nativeAccessibility"]["agentScenarios"][0]
                if pages is None:
                    scenario.pop("settingsPages")
                else:
                    scenario["settingsPages"] = deepcopy(pages)
                self.assert_rejected(fixture, "four distinct hierarchical settings-page entrances")

    def test_hierarchy_marker_is_required(self):
        for hierarchy in [None, "tabs", "overview / category"]:
            with self.subTest(hierarchy=hierarchy):
                fixture = valid_report()
                scenario = fixture["nativeAccessibility"]["agentScenarios"][0]
                if hierarchy is None:
                    scenario.pop("settingsHierarchy")
                else:
                    scenario["settingsHierarchy"] = hierarchy
                self.assert_rejected(fixture, "overview/category/item hierarchy")

    def test_wrong_page_destination_title_type_and_knowledge_kind_fail(self):
        for index, field, value in [
            (0, "destination", "agent-settings-model"),
            (0, "title", "Agent model settings"),
            (0, "contentType", "AgentModelSettingsForm"),
            (1, "contentType", "AgentPreferencesForm"),
            (2, "knowledgeKind", "memory"),
            (3, "knowledgeKind", "skill"),
        ]:
            with self.subTest(index=index, field=field, value=value):
                fixture = valid_report()
                fixture["nativeAccessibility"]["agentScenarios"][0]["settingsPages"][index][field] = value
                self.assert_rejected(fixture, "corresponding current child page")

    def test_current_child_route_and_independent_button_evidence_are_required(self):
        for field, value in [
            ("currentChildRoute", False), ("currentChildRoute", None),
            ("isButton", False), ("hasTap", False), ("mergedIntoParent", True),
            ("role", "tab"), ("role", None), ("selected", True),
            ("label", "Unrelated action"), ("label", None),
            ("index", True), ("index", 1),
        ]:
            with self.subTest(field=field, value=value):
                fixture = valid_report()
                fixture["nativeAccessibility"]["agentScenarios"][0]["settingsPages"][0][field] = value
                self.assert_rejected(fixture, "independent button")

    def test_duplicate_invalid_or_extra_page_identities_fail_without_crashing(self):
        for value in [101, -1, True, None, [], {}]:
            with self.subTest(value=value):
                fixture = valid_report()
                fixture["nativeAccessibility"]["agentScenarios"][0]["settingsPages"][0]["id"] = value
                self.assert_rejected(fixture, "four distinct hierarchical settings-page entrances")
        fixture = valid_report()
        pages = fixture["nativeAccessibility"]["agentScenarios"][0]["settingsPages"]
        extra = deepcopy(pages[0])
        extra.update(index=4, id=104)
        pages.append(extra)
        self.assert_rejected(fixture, "four distinct hierarchical settings-page entrances")

    def test_legacy_tabs_cannot_supplement_a_valid_new_page_report(self):
        fixture = valid_report()
        fixture["nativeAccessibility"]["agentScenarios"][0]["settingsTabs"] = []
        self.assert_rejected(fixture, "legacy settings-tab report")

    def test_old_tabs_and_old_model_stage_are_rejected(self):
        fixture = valid_report()
        report = fixture["nativeAccessibility"]
        for scenario in report["agentScenarios"]:
            tabs = scenario.pop("settingsPages")
            scenario.pop("settingsHierarchy")
            for index, tab in enumerate(tabs):
                tab["role"] = "tab"
                tab["selected"] = True
                if index == 0:
                    tab.update(title="Agent model settings", contentType="AgentModelSettingsForm")
                elif index == 1:
                    tab["contentType"] = "AgentPreferencesForm"
            scenario["settingsTabs"] = tabs
        for phase in report["phases"]:
            phase["phase"] = phase["phase"].replace("settings-connection", "settings-model")
        for probe in report["nativeProbes"]:
            if "-settings-" in probe["phase"]:
                probe["phase"] = probe["phase"].replace("settings-connection", "settings-model")
                probe["purpose"] = "tab"
                probe["roots"][0]["matches"][0]["role"] = 37
        self.assert_rejected(fixture, "legacy settings-tab report")

    def test_settings_native_probes_require_role_43_not_tabs_text_or_containers(self):
        for role in [9, 37, 41, 42, 56, 57, 58, 62]:
            with self.subTest(role=role):
                fixture = valid_report()
                probe = next(item for item in fixture["nativeAccessibility"]["nativeProbes"]
                             if item["phase"] == "agent-baseline-settings-connection")
                probe["roots"][0]["matches"][0]["role"] = role
                self.assert_rejected(fixture, "MSAA button evidence is missing for settings-connection")

    def test_missing_duplicate_or_wrong_purpose_native_page_probes_fail(self):
        for kind in ["missing", "duplicate", "wrong-purpose", "unmatched"]:
            with self.subTest(kind=kind):
                fixture = valid_report()
                probes = fixture["nativeAccessibility"]["nativeProbes"]
                probe = next(item for item in probes if item["phase"] == "agent-baseline-settings-skills")
                if kind == "missing":
                    probes.remove(probe)
                elif kind == "duplicate":
                    probes.append(deepcopy(probe))
                elif kind == "wrong-purpose":
                    probe["purpose"] = "tab"
                else:
                    probe["roots"][0]["matches"][0].update(nameMatched=False, valueMatched=False)
                self.assert_rejected(fixture, "MSAA button evidence is missing for settings-skills")

    def test_settings_phases_remain_complete_and_ordered(self):
        for kind in ["missing", "duplicate", "swapped"]:
            with self.subTest(kind=kind):
                fixture = valid_report()
                phases = fixture["nativeAccessibility"]["phases"]
                index = next(index for index, phase in enumerate(phases)
                             if phase["phase"] == "agent-baseline-settings-connection")
                if kind == "missing":
                    phases.pop(index)
                elif kind == "duplicate":
                    phases.insert(index, deepcopy(phases[index]))
                else:
                    phases[index], phases[index + 1] = phases[index + 1], phases[index]
                self.assert_rejected(fixture, "full ordered phase sequence exactly once")

    def test_settings_back_still_requires_preserved_draft_and_untouched_data(self):
        for field, value in [("draftPreserved", False), ("mainSnapshotUnchanged", False), ("providerRequests", 1)]:
            with self.subTest(field=field):
                fixture = valid_report()
                fixture["nativeAccessibility"]["agentScenarios"][0]["settingsReturn"][field] = value
                self.assert_rejected(fixture, "settings navigation did not preserve")

    def test_existing_source_and_native_error_gates_remain_required(self):
        fixture = valid_report()
        fixture["nativeAccessibility"]["revision"] = "0" * 40
        self.assert_rejected(fixture, "revision does not match")
        assessment = self.assess(valid_report(), "Failed to update ui::AXTree\n")
        self.assertFalse(assessment["passed"])
        self.assertEqual(assessment["nativeErrorCount"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
