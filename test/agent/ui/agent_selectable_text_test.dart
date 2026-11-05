import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_message_content.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

const _notes =
    'A complete note remains available after the first 160 characters. '
    'The preview includes both the original and proposed values, with no '
    'shortening of nested fields, punctuation, line breaks, or Unicode.\n'
    '完整明细 · Native Windows detail sentinel';
const _before = {'title': 'Original event', 'notes': 'Original notes'};
const _after = {
  'title': 'Proposed event',
  'notes': _notes,
  'metadata': {
    'labels': ['study', '课程'],
    'optional': null,
  },
};
const _details = <String, Object?>{
  'planId': 'synthetic-readonly-preview',
  'changeCount': 1,
  'changes': [
    {'before': _before, 'after': _after},
  ],
};

void main() {
  testWidgets(
    'preview preserves published text, selection and copy across platform variants',
    (tester) async {
      addTearDown(tester.view.reset);
      final original = jsonEncode(_details);
      String? copied;
      _captureClipboard(tester, (value) => copied = value);
      await mountAgentUi(
        tester,
        const SingleChildScrollView(child: AgentPlanPreview(details: _details)),
        size: const Size(720, 1000),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentPlanPreview)),
      );
      final expected = const JsonEncoder.withIndent('  ')
          .convert({l.agentValueBefore: _before, l.agentValueAfter: _after});
      expect(expected.length, greaterThan(160));
      await tester.tap(find.text('Proposed event'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l.agentPlanDetails));
      await tester.tap(find.text(l.agentPlanDetails));
      await tester.pumpAndSettle();
      var node = _expectReadonlyText(tester, expected);
      final owner = _semanticsOwner(tester);
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.longPress),
        isTrue,
      );

      // Focus and select through the published accessibility actions, not the
      // controller. Excluding the EditableText semantics would break this path.
      owner.performAction(node.id, ui.SemanticsAction.longPress);
      await tester.pumpAndSettle();
      node = _expectReadonlyText(tester, expected);
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.setSelection),
        isTrue,
      );
      const selected = '完整明细 · Native Windows detail sentinel';
      final start = expected.indexOf(selected);
      expect(start, greaterThan(160));
      owner.performAction(node.id, ui.SemanticsAction.setSelection, {
        'base': start,
        'extent': start + selected.length,
      });
      await tester.pumpAndSettle();
      node = _expectReadonlyText(tester, expected);
      expect(
        node.getSemanticsData().textSelection,
        TextSelection(baseOffset: start, extentOffset: start + selected.length),
      );
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.copy),
        isTrue,
      );
      owner.performAction(node.id, ui.SemanticsAction.copy);
      await tester.pumpAndSettle();
      expect(copied, selected);

      node = _expectReadonlyText(tester, expected);
      owner.performAction(node.id, ui.SemanticsAction.setSelection, {
        'base': 0,
        'extent': expected.length,
      });
      await tester.pumpAndSettle();
      node = _expectReadonlyText(tester, expected);
      owner.performAction(node.id, ui.SemanticsAction.copy);
      await tester.pumpAndSettle();
      expect(copied, expected);
      expect(jsonEncode(_details), original);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant(TargetPlatform.values.toSet()),
  );

  const receipt = <String, Object?>{
    'operationId': 'synthetic-readonly-receipt',
    'status': 'committed',
    'details': _notes,
  };
  const endpoint = 'http://synthetic.invalid/v1?scope=preview';
  const code = 'const message = "完整明细";\n';
  const imageText = 'Reference image description · 完整内容';
  final cases = [
    (
      name: 'HTTP endpoint',
      child: const AgentPlanPreview(
        details: {'kind': 'httpTransport', 'endpoint': endpoint},
      ),
      text: endpoint,
      expand: false,
    ),
    (
      name: 'receipt details',
      child: const AgentOperationCard(receipt: receipt),
      text: const JsonEncoder.withIndent('  ').convert(receipt),
      expand: true,
    ),
    (
      name: 'user message',
      child: const AgentMessageContent(
        text: _notes,
        roleLabel: 'You',
        isUser: true,
      ),
      text: _notes,
      expand: false,
    ),
    (
      name: 'notice',
      child: const AgentMessageContent(
        text: _notes,
        roleLabel: 'Notice',
        isNotice: true,
      ),
      text: _notes,
      expand: false,
    ),
    (
      name: 'code block',
      child: const AgentMessageContent(
        text: '```dart\n$code```',
        roleLabel: 'Agent',
      ),
      text: code,
      expand: false,
    ),
    (
      name: 'remote image description',
      child: const AgentMessageContent(
        text: '![$imageText](https://synthetic.invalid/image.png)',
        roleLabel: 'Agent',
      ),
      text: imageText,
      expand: false,
    ),
  ];
  for (final testCase in cases) {
    testWidgets('Windows publishes the ${testCase.name} text once', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        SingleChildScrollView(child: testCase.child),
        size: const Size(720, 1000),
      );
      if (testCase.expand) {
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
      }
      _expectReadonlyText(tester, testCase.text);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}

SemanticsOwner _semanticsOwner(WidgetTester tester) =>
    tester.renderObject(find.byType(Scaffold).first).owner!.semanticsOwner!;

SemanticsNode _expectReadonlyText(WidgetTester tester, String text) {
  final matches = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (!node.isMergedIntoParent) {
      final data = node.getSemanticsData();
      if (data.value == text || data.label.contains(text)) matches.add(node);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(_semanticsOwner(tester).rootSemanticsNode!);
  expect(
    matches,
    hasLength(1),
    reason: 'One published node owns the full text.',
  );
  final node = matches.single;
  final data = node.getSemanticsData();
  expect(data.value, text);
  expect(
    data.label,
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
        ? contains(text)
        : isNot(contains(text)),
    reason: 'Windows static text needs a name on the same selectable node.',
  );
  expect(data.flagsCollection.isTextField, isTrue);
  expect(data.flagsCollection.isReadOnly, isTrue);
  expect(data.flagsCollection.isButton, isFalse);
  expect(data.flagsCollection.isHidden, isFalse);
  for (final action in [
    ui.SemanticsAction.setText,
    ui.SemanticsAction.cut,
    ui.SemanticsAction.paste,
  ]) {
    expect(data.hasAction(action), isFalse);
  }
  return node;
}

void _captureClipboard(WidgetTester tester, ValueChanged<String> capture) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        capture((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}
