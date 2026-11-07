import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';
import 'package:sked/agent/ui/agent_message_content.dart';
import 'package:sked/agent/ui/agent_operation_activity.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/agent/ui/agent_question_view.dart';
import 'package:sked/agent/ui/agent_turn_activity.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';
import 'fixtures/agent_run_state_fixtures.dart';

// Component compositions expose each state for visual inspection. Full-task
// completion folding is covered by agent_turn_process_test and the native host.
class _Preview extends StatelessWidget {
  const _Preview(this.state);
  final AgentPreviewState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final operation = previewOperation(state);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AgentMessageContent(
            text: '帮我创建秋季课表。',
            roleLabel: l.agentYou,
            isUser: true,
            showCopy: false,
          ),
          const SizedBox(height: 16),
          AgentMessageContent(
            text: state == AgentPreviewState.question
                ? '我先确认开学日期。'
                : '正在根据你的要求整理课表。',
            roleLabel: l.agentAssistant,
            showCopy: false,
          ),
          const SizedBox(height: 12),
          AgentTurnActivity(
            activity: AgentTimelineActivity(
              id: 'reads',
              anchorMessageId: 'reads',
              tools: [
                AgentToolActivity(
                  id: 'read',
                  name: 'timetables.list',
                  arguments: '{}',
                  result: '{"items":[]}',
                  status: AgentToolActivityStatus.completed,
                ),
              ],
            ),
          ),
          if (state == AgentPreviewState.question)
            AgentActivityDisclosure(
              id: 'ask-start-date',
              title: l.agentWaitingForAnswer,
              status: AgentToolActivityStatus.running,
              initiallyExpanded: true,
              child: AgentQuestionView(
                request: previewQuestion(),
                enabled: true,
                onAnswer: (_) async {},
                onDismiss: () async {},
              ),
            )
          else
            AgentOperationActivity(
              operation: operation,
              details: AgentOperationCard(
                outcome: operation.outcome!,
                embedded: true,
              ),
              interaction: state == AgentPreviewState.approval
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AgentPlanPreview(details: agentPreviewReceipt),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () {},
                              child: Text(l.agentApprove),
                            ),
                            OutlinedButton(
                              onPressed: () {},
                              child: Text(l.agentReject),
                            ),
                          ],
                        ),
                      ],
                    )
                  : null,
            ),
          if (state == AgentPreviewState.completed) ...[
            const SizedBox(height: 16),
            AgentMessageContent(
              text: '秋季课表已创建。',
              roleLabel: l.agentAssistant,
              showCopy: false,
            ),
          ],
          if (state == AgentPreviewState.error ||
              state == AgentPreviewState.recovery)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l.agentContinue),
              ),
            ),
        ],
      ),
    );
  }
}

void main() {
  final output = Platform.environment['SKED_AGENT_UI_ARTIFACT_DIR'];
  const previewFont = 'SkedAgentPreview';
  setUpAll(() async {
    if (output == null) return;
    final font = Platform.environment['SKED_AGENT_UI_FONT'];
    if (font == null || !File(font).existsSync()) {
      throw StateError(
        'UI screenshots require SKED_AGENT_UI_FONT to name a readable font '
        'with Chinese glyphs.',
      );
    }
    final bytes = ByteData.sublistView(await File(font).readAsBytes());
    for (final family in [previewFont, 'monospace']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  ButtonStyle? readableButton(ButtonStyle? style) => style?.copyWith(
    textStyle: WidgetStateProperty.resolveWith(
      (states) =>
          style.textStyle?.resolve(states)?.copyWith(fontFamily: previewFont),
    ),
  );
  for (final state in AgentPreviewState.values) {
    for (final compact in [false, true]) {
      testWidgets(
        'six-state component $state ${compact ? "Android narrow" : "Windows wide"}',
        (tester) async {
          addTearDown(tester.view.reset);
          final boundary = GlobalKey();
          await mountAgentUi(
            tester,
            Directionality(
              textDirection: compact ? TextDirection.rtl : TextDirection.ltr,
              child: Builder(
                builder: (context) {
                  final inherited = Theme.of(context);
                  final theme = output == null
                      ? inherited
                      : inherited.copyWith(
                          textTheme: inherited.textTheme.apply(
                            fontFamily: previewFont,
                          ),
                          primaryTextTheme: inherited.primaryTextTheme.apply(
                            fontFamily: previewFont,
                          ),
                          filledButtonTheme: FilledButtonThemeData(
                            style: readableButton(
                              inherited.filledButtonTheme.style,
                            ),
                          ),
                          outlinedButtonTheme: OutlinedButtonThemeData(
                            style: readableButton(
                              inherited.outlinedButtonTheme.style,
                            ),
                          ),
                          listTileTheme: inherited.listTileTheme.copyWith(
                            titleTextStyle: inherited
                                .listTileTheme
                                .titleTextStyle
                                ?.copyWith(fontFamily: previewFont),
                            subtitleTextStyle: inherited
                                .listTileTheme
                                .subtitleTextStyle
                                ?.copyWith(fontFamily: previewFont),
                          ),
                        );
                  return Theme(
                    data: theme,
                    child: SingleChildScrollView(
                      child: RepaintBoundary(
                        key: boundary,
                        child: Material(
                          color: theme.colorScheme.surface,
                          child: _Preview(state),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            size: compact ? const Size(360, 800) : const Size(1000, 760),
            scale: compact ? 2 : 1,
            locale: const Locale('zh'),
            brightness: compact ? Brightness.dark : Brightness.light,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(Card), findsNothing);
          if (state == AgentPreviewState.approval) {
            expect(
              find.text(
                AppLocalizations.of(tester.element(find.byType(_Preview)))
                    .agentApprove,
              ),
              findsOneWidget,
            );
          }
          if (state == AgentPreviewState.question) {
            expect(find.byType(AgentQuestionView), findsOneWidget);
          }
          if (state == AgentPreviewState.completed) {
            expect(find.text('秋季课表已创建。'), findsOneWidget);
            expect(find.byType(AgentOperationCard), findsNothing);
          }
          final l = AppLocalizations.of(tester.element(find.byType(_Preview)));
          if (state == AgentPreviewState.error) {
            expect(find.text(l.agentActionFailed), findsOneWidget);
          }
          if (state == AgentPreviewState.recovery) {
            expect(find.text(l.agentActionUncertain), findsOneWidget);
          }
          // The caller owns this optional OS-temp directory for visual review.
          if (output != null) {
            final root = Directory.systemTemp.absolute.path.toLowerCase();
            final directory = Directory(output).absolute;
            if (!directory.path.toLowerCase().startsWith(
              '$root${Platform.pathSeparator}',
            )) {
              throw StateError(
                'UI artifacts must use an OS temporary directory.',
              );
            }
            await tester.runAsync(() async {
              await directory.create(recursive: true);
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final variant = compact ? 'narrow' : 'wide';
                await File('${directory.path}/${state.name}-$variant.png')
                    .writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
        },
        variant: TargetPlatformVariant.only(
          compact ? TargetPlatform.android : TargetPlatform.windows,
        ),
      );
    }
  }
}
