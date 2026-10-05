import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sked/widgets/sked_panel_header.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/services/update_service.dart';
import 'package:sked/widgets/app_update_dialog.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/sked_task_session.dart';

const result = UpdateCheckResult(
  localVersion: '2.3.0-rc.1',
  remoteVersion: '2.3.0-rc.2',
  releaseUrl: 'https://github.com/Mashiro0619/Sked/releases/tag/v2.3.0-rc.2',
  updateContent: '# Desktop\n\n- **Compact panels**\n- Bug fixes\n\n![Preview](https://invalid.example/image.png)',
  hasUpdate: true,
);

Future<BuildContext> pumpDialog(
  WidgetTester tester, {
  UpdateCheckResult? initial = result,
  bool startup = false,
  double scale = 1,
  String locale = 'en',
  TargetPlatform platform = TargetPlatform.android,
  TextDirection direction = TextDirection.ltr,
  UpdateDistribution distribution = const UpdateDistribution(
    UpdateChannel.github,
  ),
  Future<UpdateCheckResult> Function()? retry,
  Future<void> Function(String)? ignore,
}) async {
  final session = SkedTaskSession();
  addTearDown(session.dispose);
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      theme: ThemeData(platform: platform),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(
    showExpressiveDialog<void>(
      context: context,
      session: session,
      builder: (_) => AppUpdateDialog(
        distribution: distribution,
        session: session,
        result: initial,
        startup: startup,
        fallbackUrl: result.releaseUrl,
        retry: retry ?? () async => result,
        recordResult: (_) async {},
        ignoreVersion: ignore ?? (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return context;
}

void main() {
  test(
    'note links reject local/script protocols and resolve relative HTTPS',
    () {
      for (final bad in [
        'javascript:alert(1)',
        'file:///a',
        'http://example.com',
        'market://details?id=x',
        'https://user:pass@example.com',
      ]) {
        expect(resolveUpdateNoteLink(bad, result.releaseUrl), isNull);
      }
      expect(
        resolveUpdateNoteLink('../v2.3.0', result.releaseUrl)?.scheme,
        'https',
      );
    },
  );

  testWidgets(
    'renders selectable Markdown and image alt text without loading images',
    (tester) async {
      await pumpDialog(tester);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(
        tester.widget<MarkdownBody>(find.byType(MarkdownBody)).selectable,
        isTrue,
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Prerelease'), findsOneWidget);
      expect(find.text('Github'), findsOneWidget);
      expect(find.text('Ignore this version'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('app-update-content'))).width,
        lessThanOrEqualTo(640),
      );
    },
  );

  testWidgets(
    'failed check retries within the same element and has no ignore action',
    (tester) async {
      final pending = Completer<UpdateCheckResult>();
      var calls = 0;
      await pumpDialog(
        tester,
        initial: null,
        startup: true,
        retry: () {
          calls++;
          return pending.future;
        },
      );
      final original = tester.element(find.byType(AppUpdateDialog));
      expect(find.text('Ignore this version'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(calls, 1);
      pending.complete(result);
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(AppUpdateDialog)), same(original));
      expect(find.text('New version available'), findsOneWidget);
    },
  );

  testWidgets('ignore failure preserves dialog and allows retry', (
    tester,
  ) async {
    var calls = 0;
    await pumpDialog(
      tester,
      startup: true,
      ignore: (_) async {
        if (++calls == 1) throw StateError('disk');
      },
    );
    await tester.tap(find.text('Ignore this version'));
    await tester.pumpAndSettle();
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(find.text('New version available'), findsOneWidget);
    await tester.tap(find.text('Ignore this version'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(AppUpdateDialog), findsNothing);
  });

  testWidgets('launch completion removes only its route, not a newer task', (
    tester,
  ) async {
    final pending = Completer<bool>();
    final context = await pumpDialog(
      tester,
      distribution: UpdateDistribution(
        UpdateChannel.github,
        urlLauncher: (_, _) => pending.future,
      ),
    );
    await tester.tap(find.text('Github'));
    await tester.pump();
    unawaited(
      showExpressiveDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Unrelated task')),
      ),
    );
    await tester.pumpAndSettle();
    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Unrelated task'), findsOneWidget);
    expect(find.byType(AppUpdateDialog, skipOffstage: false), findsNothing);
  });

  testWidgets(
    'long notes, wide tables and code remain inside the reading surface',
    (tester) async {
      final notes = UpdateCheckResult(
        localVersion: '1.0',
        remoteVersion: '2.0',
        releaseUrl: result.releaseUrl,
        hasUpdate: true,
        updateContent: [
          '# Changes\n',
          ...List.generate(80, (i) => '- Change $i with **details**'),
          '\n| ${List.filled(12, 'Column').join(' | ')} |',
          '| ${List.filled(12, '---').join(' | ')} |',
          '| ${List.filled(12, 'Long value').join(' | ')} |\n',
          '```',
          'x' * 500,
          '```',
        ].join('\n'),
      );
      await pumpDialog(tester, initial: notes);
      expect(tester.takeException(), isNull);
      expect(find.text('Github').hitTestable(), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('app-update-content'))).width,
        lessThanOrEqualTo(560),
      );
    },
  );

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  ]) {
    testWidgets('desktop $platform uses compact chrome and separated actions', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        platform: platform,
        startup: true,
        initial: const UpdateCheckResult(
          localVersion: '1.0',
          remoteVersion: '2.0',
          releaseUrl: 'https://example.com/release',
          updateContent: 'Notes',
          hasUpdate: true,
        ),
      );
      expect(find.byType(SkedFloatingSurface), findsOneWidget);
      expect(find.byType(SkedPanelHeader), findsOneWidget);
      expect(
        tester.widget<SkedPanelHeader>(find.byType(SkedPanelHeader)).onDrag,
        isNull,
      );
      expect(find.byType(Divider), findsOneWidget);
      expect(
        tester.getCenter(find.text('2.0')).dy,
        closeTo(tester.getCenter(find.text('Current version 1.0')).dy, 1),
      );
      final ignore = tester.getRect(find.text('Ignore this version'));
      final later = tester.getRect(find.text('Later'));
      expect(ignore.right, lessThan(later.left));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Github'),
      );
      final shape = button.style!.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(6));
      expect(
        tester.getSize(find.widgetWithText(FilledButton, 'Github')).height,
        greaterThanOrEqualTo(36),
      );
      await tester.tap(find.byKey(const ValueKey('app-update-close')));
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsNothing);
    });
  }

  testWidgets(
    'touch dialog retains its layout and does not gain desktop chrome',
    (tester) async {
      await pumpDialog(tester);
      expect(find.byType(SkedFloatingSurface), findsNothing);
      expect(find.byType(SkedPanelHeader), findsNothing);
      expect(find.byKey(const ValueKey('app-update-close')), findsNothing);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop close, Escape and outside clicks respect pending launch; failure can retry',
    (tester) async {
      final pending = Completer<bool>();
      var calls = 0;
      await pumpDialog(
        tester,
        platform: TargetPlatform.windows,
        distribution: UpdateDistribution(
          UpdateChannel.github,
          urlLauncher: (_, _) {
            calls++;
            return pending.future;
          },
        ),
      );
      await tester.tap(find.text('Github'));
      await tester.pump();
      final close = find.byKey(const ValueKey('app-update-close'));
      expect(tester.widget<IconButton>(close).onPressed, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      expect(find.byType(AppUpdateDialog), findsOneWidget);
      expect(calls, 1);
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('Unable to open the update link'), findsOneWidget);
      expect(tester.widget<IconButton>(close).onPressed, isNotNull);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsNothing);
    },
  );

  for (final locale in ['zh', 'en']) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final direction in TextDirection.values) {
        testWidgets('desktop small window $locale $scale $direction', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(480, 320);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await pumpDialog(
            tester,
            platform: TargetPlatform.windows,
            scale: scale,
            locale: locale,
            direction: direction,
            startup: true,
            distribution: const UpdateDistribution(
              UpdateChannel.microsoftStore,
            ),
          );
          expect(tester.takeException(), isNull);
          final close = find.byKey(const ValueKey('app-update-close'));
          expect(close.hitTestable(), findsOneWidget);
          await tester.ensureVisible(
            find.text('Microsoft Store').evaluate().isNotEmpty
                ? find.text('Microsoft Store')
                : find.text('微软商店'),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final locale in ['en', 'zh']) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final size in [
        const Size(1440, 900),
        const Size(360, 520),
        const Size(720, 320),
      ]) {
        testWidgets('bounded layout $locale $scale $size', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await pumpDialog(
            tester,
            locale: locale,
            scale: scale,
            startup: true,
            distribution: const UpdateDistribution(
              UpdateChannel.microsoftStore,
            ),
          );
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(
            find.byKey(const ValueKey('app-update-content')),
          );
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        });
      }
    }
  }
}
