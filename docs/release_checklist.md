# Release Checklist

Use this checklist before cutting a release or publishing a build.

## Code Quality

- Run `dart format --output=none --set-exit-if-changed .`
- Run `flutter analyze`
- Run `flutter test`
- Confirm newly changed import/export paths have focused tests.
- Confirm destructive restore/import flows still require explicit confirmation.

## Build Smoke Tests

- Run `flutter build web --debug`
- Run `flutter build apk --debug`
- Open the app in student mode and general schedule mode.
- Verify settings, theme switching, import/export sheets, and editor sheets on a narrow viewport.

## Data And Privacy

- Verify full app backup exports timetables, general schedules, settings, and school sites.
- Verify full app backup does not include custom parser API keys.
- Verify full restore prompts before replacing app data.
- Re-read README, README_EN, in-app privacy policy, and parser settings copy.
- Confirm custom parser requests use only the user-configured endpoint.

## Release Notes

- Update `pubspec.yaml` version and build number.
- Review screenshots if UI changed materially.
- Summarize user-visible changes, migration notes, and known limitations.
- Create a GitHub release only after CI is green.
