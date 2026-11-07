import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_transcript.dart';

/// Reveals a clipped transcript control through the outer scroll gesture.
/// Embedded detail scrolling keeps the transcript's follow-latest policy.
Future<Map<String, Object?>?> revealAgentTranscriptControl(
  WidgetTester tester,
  Finder target,
) async {
  final transcripts = find.ancestor(
    of: target,
    matching: find.byType(AgentTranscript),
  );
  if (transcripts.evaluate().isEmpty) return null;
  final transcript = transcripts.first;
  final scrollable = find
      .descendant(of: transcript, matching: find.byType(Scrollable))
      .first;
  final observations = <Map<String, Object?>>[];
  void observe() {
    final position = tester.state<ScrollableState>(scrollable).position;
    observations.add({
      'targetRect': '${tester.getRect(target)}',
      'viewportRect': '${tester.getRect(transcript)}',
      'outerPixels': position.pixels,
      'outerMaxScrollExtent': position.maxScrollExtent,
      'followLatest': tester
          .widget<AgentTranscript>(transcript)
          .position
          .followLatest,
      'hitTestable': target.hitTestable().evaluate().isNotEmpty,
    });
  }

  observe();
  for (var attempt = 0; attempt < 40; attempt++) {
    if (target.hitTestable().evaluate().isNotEmpty) break;
    final viewport = tester.getRect(transcript);
    final control = tester.getRect(target);
    final center = control.center.dy;
    if (center >= viewport.top && center <= viewport.bottom) break;
    final distance = center < viewport.top
        ? math.min(180.0, viewport.top - center + 48)
        : -math.min(180.0, center - viewport.bottom + 48);
    // The transcript's horizontal padding keeps this start outside nested
    // query details while still using the real outer scrollable hit target.
    await tester.dragFrom(
      Offset(viewport.left + 8, viewport.center.dy),
      Offset(0, distance),
    );
    await tester.pumpAndSettle();
    observe();
  }
  return {'target': '$target', 'observations': observations};
}
