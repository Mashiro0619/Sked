part of 'package:sked/screens/home_screen.dart';

@Preview(
  group: 'Timetable information form',
  name: 'Phone',
  size: skedPhonePreviewSize,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Timetable information form',
  name: 'Phone - 2x text',
  size: skedPhoneLargeTextPreviewSize,
  textScaleFactor: 2,
  wrapper: skedPreviewWrapper,
)
@Preview(
  group: 'Timetable information form',
  name: 'Wide',
  size: skedWidePreviewSize,
  wrapper: skedPreviewWrapper,
)
Widget timetableInformationFormPreview() {
  return const _TimetableInformationFormPreview();
}

class _TimetableInformationFormPreview extends StatefulWidget {
  const _TimetableInformationFormPreview();

  @override
  State<_TimetableInformationFormPreview> createState() =>
      _TimetableInformationFormPreviewState();
}

class _TimetableInformationFormPreviewState
    extends State<_TimetableInformationFormPreview> {
  late final TextEditingController _nameController = TextEditingController(
    text: 'Autumn timetable',
  );
  late final TextEditingController _weeksController = TextEditingController(
    text: '18',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _weeksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: TimetableInformationDialogSurface(
          title: Text(l10n.editTimetable),
          form: TimetableInformationForm(
            nameController: _nameController,
            weeksController: _weeksController,
            startDateLabel: '2026-09-07',
            periodTimeSetSummary: l10n.periodTimeSetSummary('Standard day', 10),
            enabled: true,
            onPickStartDate: () {},
            onPickPeriodTimeSet: () {},
          ),
          leading: TextButton(onPressed: () {}, child: Text(l10n.delete)),
          actions: <Widget>[
            TextButton(onPressed: () {}, child: Text(l10n.cancel)),
            FilledButton(onPressed: () {}, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
