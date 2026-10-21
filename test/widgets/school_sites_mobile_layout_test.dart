import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/screens/school_sites_page.dart';
import 'package:sked/screens/school_web_import_page.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/settings_page_header.dart';

import '../support/workspace_harness.dart';

const _shortSite = SchoolSite(name: 'a', loginUrl: 'https://vpn.czu.cn');
const _longUrl =
    'https://vpn.czu.cn/portal/authentication/student/timetable/login'
    '?redirect=https%3A%2F%2Fstudent.example.edu%2Fsemester%2F2026';

class _SiteStore extends SchoolSiteStore {
  _SiteStore(List<SchoolSite> sites)
    : source = encodeSchoolSites(sites),
      super.base();

  String source;
  int writes = 0;
  bool failNext = false;
  Completer<void>? pending;

  @override
  Future<String?> load() async => source;

  @override
  Future<void> save(String value) async {
    writes++;
    await pending?.future;
    if (failNext) {
      failNext = false;
      throw StateError('retryable school-site write');
    }
    source = value;
  }

  @override
  Future<String?> filePath() async => 'memory://school-sites-mobile-layout';
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<(_SiteStore, AppLocalizations)> _openPage(
  WidgetTester t, {
  double width = 360,
  double scale = 1,
  String language = 'en',
  TextDirection direction = TextDirection.ltr,
  List<SchoolSite> sites = const [_shortSite],
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 900);
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.reset);
  final p = await workspaceProvider(locale: language);
  addTearDown(p.dispose);
  final store = _SiteStore(sites);
  final service = SchoolSiteService(store: store);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      locale: Locale(language),
      textDirection: direction,
      textScale: scale,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('open-school-sites-mobile'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => SchoolSitesPage(siteService: service),
                ),
              ),
              child: const Text('Open school sites'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(_key('open-school-sites-mobile'));
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
  return (store, AppLocalizations.of(t.element(find.byType(SchoolSitesPage))));
}

void _expectRow(
  WidgetTester t,
  SchoolSite site,
  AppLocalizations l,
  TextDirection direction,
) {
  final title = find.text(site.name);
  final url = find.text(site.loginUrl);
  final icon = find.byIcon(Icons.school_outlined);
  final edit = find.byTooltip(l.schoolSitesEdit).hitTestable();
  expect(title, findsOneWidget);
  expect(url, findsOneWidget);
  expect(icon, findsOneWidget);
  expect(edit, findsOneWidget);
  final textRect = t.getRect(title).expandToInclude(t.getRect(url));
  final editRect = t.getRect(edit);
  final iconRect = t.getRect(icon);
  expect(editRect.width, greaterThanOrEqualTo(48));
  expect(editRect.height, greaterThanOrEqualTo(48));
  expect(
    editRect.center.dy,
    inInclusiveRange(textRect.top, textRect.bottom),
    reason: 'Editing stays beside the name and URL instead of a second row',
  );
  expect(iconRect.center.dy, inInclusiveRange(textRect.top, textRect.bottom));
  if (direction == TextDirection.ltr) {
    expect(iconRect.right, lessThanOrEqualTo(textRect.left));
    expect(textRect.right, lessThanOrEqualTo(editRect.left));
  } else {
    expect(editRect.right, lessThanOrEqualTo(textRect.left));
    expect(textRect.right, lessThanOrEqualTo(iconRect.left));
  }
  for (final text in [title, url]) {
    final paragraph = t.renderObject<RenderParagraph>(text);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.maxLines, isNull);
    final rect = t.getRect(text);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(t.view.physicalSize.width));
  }
}

Finder _fields() => find.descendant(
  of: find.byType(AppSheetScaffold),
  matching: find.byType(TextField),
);

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

ScrollPosition _position(WidgetTester t) => t
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const PageStorageKey('school-sites-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

int _headingCount(WidgetTester t, String title) {
  final root =
      t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
  var count = 0;
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isHeader && data.label == title) count++;
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return count;
}

List<SchoolSite> _manySites() => [
  for (var index = 0; index < 20; index++)
    SchoolSite(
      name: 'School $index',
      loginUrl: 'https://school$index.example.edu/login',
    ),
];

void _expectHeaderActions(WidgetTester t, AppLocalizations l, double width) {
  for (final tooltip in [
    l.schoolSitesAdd,
    l.schoolHtmlImportEntry,
    l.importExport,
  ]) {
    final action = find.byTooltip(tooltip).hitTestable();
    expect(action, findsOneWidget, reason: tooltip);
    final rect = t.getRect(action);
    expect(rect.width, greaterThanOrEqualTo(48), reason: tooltip);
    expect(rect.height, greaterThanOrEqualTo(48), reason: tooltip);
    expect(rect.left, greaterThanOrEqualTo(0), reason: tooltip);
    expect(rect.right, lessThanOrEqualTo(width), reason: tooltip);
    expect(rect.top, greaterThanOrEqualTo(24), reason: tooltip);
  }
}

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  for (final width in [320.0, 360.0, 400.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final (language, direction) in [
        ('en', TextDirection.ltr),
        ('zh', TextDirection.ltr),
        ('en', TextDirection.rtl),
      ]) {
        testWidgets(
          'short school site $width scale $scale $language ${direction.name} keeps edit beside its text',
          (t) async {
            final (store, l) = await _openPage(
              t,
              width: width,
              scale: scale,
              language: language,
              direction: direction,
            );
            _expectRow(t, _shortSite, l, direction);
            await _tap(t, find.byTooltip(l.schoolSitesEdit).hitTestable());
            expect(find.byType(AppSheetScaffold), findsOneWidget);
            expect(
              find.byType(SchoolWebImportPage, skipOffstage: false),
              findsNothing,
            );
            expect(t.widget<TextField>(_fields().first).controller!.text, 'a');
            expect(
              t.widget<TextField>(_fields().last).controller!.text,
              _shortSite.loginUrl,
            );
            expect(store.writes, 0);
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await t.pumpAndSettle();
            expect(find.byType(AppSheetScaffold), findsNothing);
            expect(find.byType(SchoolSitesPage), findsOneWidget);
            expect(store.writes, 0);
            expect(t.takeException(), isNull);
          },
          variant: android,
        );

        testWidgets(
          'long school site $width scale $scale $language ${direction.name} wraps beside independent edit',
          (t) async {
            final site = SchoolSite(
              name: language == 'zh' ? '学校教务管理系统本科研究生课程表与校园统一身份认证登录入口' : 'School administration and student timetable portal with campus authentication',
              loginUrl: _longUrl,
            );
            final (store, l) = await _openPage(
              t,
              width: width,
              scale: scale,
              language: language,
              direction: direction,
              sites: [site],
            );
            _expectRow(t, site, l, direction);
            final paragraph = t.renderObject<RenderParagraph>(
              find.text(site.loginUrl),
            );
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: site.loginUrl.length),
            );
            expect(boxes.map((box) => box.top).toSet().length, greaterThan(2));
            await _tap(t, find.byTooltip(l.schoolSitesEdit).hitTestable());
            expect(find.byType(AppSheetScaffold), findsOneWidget);
            expect(
              find.byType(SchoolWebImportPage, skipOffstage: false),
              findsNothing,
            );
            expect(
              t.widget<TextField>(_fields().first).controller!.text,
              site.name,
            );
            expect(
              t.widget<TextField>(_fields().last).controller!.text,
              site.loginUrl,
            );
            expect(store.writes, 0);
            expect(t.takeException(), isNull);
          },
          variant: android,
        );
      }
    }
  }

  for (final (width, scale, language, direction) in [
    (320.0, 2.0, 'en', TextDirection.ltr),
    (360.0, 1.3, 'zh', TextDirection.ltr),
    (400.0, 1.0, 'en', TextDirection.rtl),
  ]) {
    testWidgets(
      'school header $width scale $scale $language ${direction.name} shares list collapse and keeps all actions reachable',
      (t) async {
        final semantics = t.ensureSemantics();
        try {
          final (store, l) = await _openPage(
            t,
            width: width,
            scale: scale,
            language: language,
            direction: direction,
            sites: _manySites(),
          );
          final header = find.byType(SettingsPageHeader);
          expect(header, findsOneWidget);
          expect(
            t.widget<SettingsPageHeader>(header).title,
            l.schoolSitesPageTitle,
          );
          expect(_key('settings-expanded-title'), findsOneWidget);
          final title = t.widget<Text>(_key('settings-expanded-title'));
          expect(title.data, l.schoolSitesPageTitle);
          expect(title.style!.fontSize, 32);
          expect(
            t
                .renderObject<RenderParagraph>(_key('settings-expanded-title'))
                .didExceedMaxLines,
            isFalse,
          );
          final back = find.byType(BackButton).hitTestable();
          expect(back, findsOneWidget);
          expect(
            t.widget<BackButton>(back).style!.shape!.resolve({}),
            isA<CircleBorder>(),
          );
          final actualBar = find.descendant(
            of: header,
            matching: find.byWidgetPredicate((widget) => widget is AppBar),
          );
          expect(t.getRect(actualBar).top, 24);
          _expectHeaderActions(t, l, width);
          expect(_headingCount(t, l.schoolSitesPageTitle), 1);
          final flexible = find.descendant(
            of: header,
            matching: find.byType(FlexibleSpaceBarSettings),
          );
          final expanded = t.widget<FlexibleSpaceBarSettings>(flexible);
          expect(expanded.currentExtent, expanded.maxExtent);
          final position = _position(t);
          position.jumpTo(500);
          await t.pumpAndSettle();
          final collapsed = t.widget<FlexibleSpaceBarSettings>(flexible);
          expect(collapsed.currentExtent, collapsed.minExtent);
          expect(position.pixels, 500);
          expect(t.getRect(actualBar).top, 24);
          _expectHeaderActions(t, l, width);
          expect(_headingCount(t, l.schoolSitesPageTitle), 1);
          final compact = find.descendant(
            of: _key('settings-compact-title-scroll'),
            matching: find.text(l.schoolSitesPageTitle),
          );
          expect(compact, findsOneWidget);
          expect(
            t.renderObject<RenderParagraph>(compact).didExceedMaxLines,
            isFalse,
          );
          await _tap(t, back);
          expect(_key('open-school-sites-mobile'), findsOneWidget);
          expect(find.byType(SchoolSitesPage), findsNothing);
          expect(store.writes, 0);
          expect(t.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: android,
    );

    testWidgets(
      'school edit $width scale $scale $language ${direction.name} retains draft on back and failed save and blocks exits while saving',
      (t) async {
        final (store, l) = await _openPage(
          t,
          width: width,
          scale: scale,
          language: language,
          direction: direction,
        );
        final originalSource = store.source;
        await _tap(t, _key('school-site-edit-0'));
        final nameElement = t.element(_fields().first);
        final urlElement = t.element(_fields().last);
        await t.enterText(_fields().first, 'Retained school draft');
        await t.enterText(_fields().last, 'https://vpn.czu.cn/student/draft');
        await t.pumpAndSettle();
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(find.text(l.unsavedChangesMessage), findsOneWidget);
        await _tap(
          t,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l.cancel),
          ),
        );
        expect(t.element(_fields().first), same(nameElement));
        expect(t.element(_fields().last), same(urlElement));
        expect(
          t.widget<TextField>(_fields().first).controller!.text,
          'Retained school draft',
        );
        expect(
          t.widget<TextField>(_fields().last).controller!.text,
          'https://vpn.czu.cn/student/draft',
        );
        expect(store.source, originalSource);
        expect(store.writes, 0);
        final save = find.widgetWithText(FilledButton, l.save);
        store.failNext = true;
        await _tap(t, save);
        expect(find.text(l.saveFailedRetry), findsOneWidget);
        expect(find.byType(AppSheetScaffold), findsOneWidget);
        expect(t.element(_fields().first), same(nameElement));
        expect(t.element(_fields().last), same(urlElement));
        expect(
          t.widget<TextField>(_fields().first).controller!.text,
          'Retained school draft',
        );
        expect(
          t.widget<TextField>(_fields().last).controller!.text,
          'https://vpn.czu.cn/student/draft',
        );
        expect(store.source, originalSource);
        expect(store.writes, 1);
        store.pending = Completer<void>();
        await t.tap(save);
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(store.writes, 2);
        expect(t.widget<FilledButton>(save).onPressed, isNull);
        for (final field in t.widgetList<TextField>(_fields())) {
          expect(field.enabled, isFalse);
        }
        await t.binding.handlePopRoute();
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(find.byType(AppSheetScaffold), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.byType(SchoolWebImportPage, skipOffstage: false),
          findsNothing,
        );
        expect(store.source, originalSource);
        store.pending!.complete();
        await t.pumpAndSettle();
        expect(find.byType(AppSheetScaffold), findsNothing);
        final saved = decodeSchoolSitesStrict(store.source).single;
        expect(saved.name, 'Retained school draft');
        expect(saved.loginUrl, 'https://vpn.czu.cn/student/draft');
        expect(store.writes, 2);
        expect(find.byType(SchoolSitesPage), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: android,
    );
  }

  testWidgets(
    'school mobile list and editor keep scroll and draft when resized through a wide touch layout',
    (t) async {
      final (store, l) = await _openPage(
        t,
        width: 360,
        scale: 1.3,
        sites: _manySites(),
      );
      final position = _position(t);
      position.jumpTo(350);
      await t.pumpAndSettle();
      await t.ensureVisible(_key('school-site-edit-3'));
      await t.pumpAndSettle();
      final offset = position.pixels;
      await _tap(t, _key('school-site-edit-3'));
      final nameElement = t.element(_fields().first);
      final urlElement = t.element(_fields().last);
      await t.enterText(_fields().first, 'Draft across touch widths');
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(1920, 900);
      await t.pumpAndSettle();
      expect(_key('settings-expanded-title'), findsNothing);
      expect(t.element(_fields().first), same(nameElement));
      expect(t.element(_fields().last), same(urlElement));
      expect(t.getRect(_fields().first).left, greaterThan(280));
      expect(_position(t), same(position));
      expect(position.pixels, closeTo(offset, .01));
      t.view.physicalSize = const Size(360, 900);
      await t.pumpAndSettle();
      expect(t.element(_fields().first), same(nameElement));
      expect(t.element(_fields().last), same(urlElement));
      expect(
        t.widget<TextField>(_fields().first).controller!.text,
        'Draft across touch widths',
      );
      expect(_position(t), same(position));
      expect(position.pixels, closeTo(offset, .01));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text(l.unsavedChangesMessage), findsOneWidget);
      await _tap(t, find.text(l.discardChangesAndExit));
      expect(find.byType(AppSheetScaffold), findsNothing);
      expect(position.pixels, closeTo(offset, .01));
      expect(store.writes, 0);
      expect(store.source, isNot(contains('Draft across touch widths')));
      expect(t.takeException(), isNull);
    },
    variant: android,
  );

  for (final (platform, width, supportsWebImport) in [
    (TargetPlatform.android, 360.0, true),
    (TargetPlatform.linux, 360.0, false),
    (TargetPlatform.windows, 660.0, true),
  ]) {
    testWidgets(
      'school edit exposes its independent enabled semantics in a narrow $platform window',
      (t) async {
        final semantics = t.ensureSemantics();
        try {
          final (store, l) = await _openPage(t, width: width);
          final row = _key('school-site-row-0');
          final option = t.widget<ExpressiveDialogOption>(
            find.descendant(
              of: row,
              matching: find.byType(ExpressiveDialogOption),
            ),
          );
          expect(option.enabled, supportsWebImport);
          expect(option.onTap, supportsWebImport ? isNotNull : isNull);
          if (!supportsWebImport) {
            expect(
              t
                  .getSemantics(row)
                  .getSemanticsData()
                  .hasAction(SemanticsAction.tap),
              isFalse,
            );
            await t.tap(find.text(_shortSite.name));
            await t.pumpAndSettle();
            expect(find.byType(AppSheetScaffold), findsNothing);
            expect(
              find.byType(SchoolWebImportPage, skipOffstage: false),
              findsNothing,
            );
          }
          final edit = _key('school-site-edit-0');
          expect(edit.hitTestable(), findsOneWidget);
          final node = t.getSemantics(edit);
          final data = node.getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
          expect(
            [data.label, data.tooltip].join(' '),
            contains(l.schoolSitesEdit),
          );
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          expect(node.id, isNot(t.getSemantics(row).id));
          node.owner!.performAction(node.id, SemanticsAction.tap);
          await t.pumpAndSettle();
          expect(find.byType(AppSheetScaffold), findsOneWidget);
          expect(t.widget<TextField>(_fields().first).controller!.text, 'a');
          expect(
            t.widget<TextField>(_fields().last).controller!.text,
            _shortSite.loginUrl,
          );
          expect(
            find.byType(SchoolWebImportPage, skipOffstage: false),
            findsNothing,
          );
          expect(store.writes, 0);
          expect(t.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
