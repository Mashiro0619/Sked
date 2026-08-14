import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../screens/period_times_page.dart';
import '../utils/constants.dart';
import 'sked_preview_support.dart';

@Preview(
  group: 'Period time-set editor',
  name: 'Phone',
  size: skedPhonePreviewSize,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Period time-set editor',
  name: 'Phone - 2x text',
  size: skedPhoneLargeTextPreviewSize,
  textScaleFactor: 2,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Period time-set editor',
  name: 'Wide',
  size: skedWidePreviewSize,
  wrapper: skedPreviewWrapper,
)
Widget periodTimesEditorPreview() => const _PeriodTimesEditorPreviewHost();

class _PeriodTimesEditorPreviewHost extends StatefulWidget {
  const _PeriodTimesEditorPreviewHost();

  @override
  State<_PeriodTimesEditorPreviewHost> createState() =>
      _PeriodTimesEditorPreviewHostState();
}

class _PeriodTimesEditorPreviewHostState
    extends State<_PeriodTimesEditorPreviewHost> {
  late final TimetableProvider _provider = TimetableProvider(
    systemLocaleCodeResolver: () => 'en',
  );

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TimetableProvider>.value(
      value: _provider,
      child: const PeriodTimesPage(periodTimeSetId: defaultPeriodTimeSetId),
    );
  }
}
