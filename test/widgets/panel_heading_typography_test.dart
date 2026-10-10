import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_panel_header.dart';
import 'package:sked/widgets/sked_task_dialog.dart';
import 'package:sked/widgets/workspace_editor.dart';
import 'package:sked/widgets/workspace_editor_form.dart';
import 'package:sked/widgets/workspace_view_panel.dart';

const _titleKey = ValueKey('heading-title');
const _subtitleKey = ValueKey('heading-subtitle');
const _title = '选择周次 · Edit course';

Finder _key(String value) => find.byKey(ValueKey(value));

RenderParagraph _paragraph(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)),
    );

ThemeData _theme({
  TargetPlatform platform = TargetPlatform.windows,
  String? fontFamily,
  List<String>? fallbacks,
}) {
  final theme = ThemeData(
    platform: platform,
    fontFamily: fontFamily,
    fontFamilyFallback: fallbacks,
  );
  return theme.copyWith(
    textTheme: theme.textTheme.copyWith(
      // A compact field theme must not become the title of its child picker.
      titleMedium: theme.textTheme.titleMedium!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.25,
      ),
    ),
  );
}

Widget _app(
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
  double width = 480,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  theme: theme ?? _theme(),
  locale: locale,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(textDirection: direction, child: child!),
  ),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        height: 500,
        child: Align(
          alignment: Alignment.topCenter,
          child: DefaultTextStyle(
            style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic),
            child: child,
          ),
        ),
      ),
    ),
  ),
);

enum _Host { header, editor, collection, task }

Widget _host(_Host host) {
  const title = Text(_title, key: _titleKey);
  const content = Text('Body content');
  return switch (host) {
    _Host.header => SkedPanelHeader(title: title, onClose: () {}),
    _Host.editor => WorkspaceEditorScope(
      enabled: true,
      floating: true,
      onHeight: (_) {},
      child: WorkspaceEditorScaffold(
        title: title,
        onClose: () {},
        closeEnabled: true,
        actions: const [],
        child: content,
      ),
    ),
    _Host.collection => WorkspaceViewTaskScope(
      enabled: true,
      onClose: () {},
      onContentHeight: (_) {},
      child: const WorkspaceViewLayoutScope(
        compact: true,
        child: WorkspaceViewPanel(title: title, child: content),
      ),
    ),
    _Host.task => SkedTaskDialogScope(
      onClose: () {},
      child: const SkedTaskDialog(title: title, content: content),
    ),
  };
}

void _expectTaskStyle(RenderParagraph paragraph) {
  final style = paragraph.text.style!;
  expect(style.fontSize, 16);
  expect(style.fontWeight, FontWeight.w600);
  expect(style.fontStyle, FontStyle.normal);
  expect(style.height, 1.35);
  expect(style.letterSpacing, 0);
}

void main() {
  for (final host in _Host.values) {
    testWidgets('${host.name} renders the common desktop task hierarchy', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_app(_host(host), locale: const Locale('zh')));
        await tester.pumpAndSettle();
        final title = find.byKey(_titleKey);
        _expectTaskStyle(_paragraph(tester, title));
        expect(tester.getSemantics(title).flagsCollection.isHeader, isTrue);
        expect(
          tester.getCenter(title).dy,
          closeTo(tester.getCenter(find.byTooltip('关闭')).dy, 0.1),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets(
    'object names and editable names retain their distinct emphasis',
    (tester) async {
      await tester.pumpWidget(
        _app(
          WorkspaceViewPanel(
            prominentTitle: true,
            title: const Text('计算方法', key: _titleKey),
            subtitle: const Text('学生课表', key: _subtitleKey),
            child: Builder(
              builder: (context) => Text(
                '计算方法',
                key: const ValueKey('editable-name'),
                style: workspaceEditorTitleStyle(context),
              ),
            ),
          ),
        ),
      );
      final object = _paragraph(tester, find.byKey(_titleKey)).text.style!;
      final editable = _paragraph(tester, _key('editable-name')).text.style!;
      final subtitle = _paragraph(tester, find.byKey(_subtitleKey)).text.style!;
      expect(object.fontSize, 18);
      expect(object.fontWeight, FontWeight.w600);
      expect(object.height, 1.35);
      expect(editable.fontSize, 22);
      expect(editable.fontWeight, FontWeight.w600);
      expect(editable.height, 1.25);
      expect(editable.letterSpacing, 0);
      expect(subtitle.fontSize, 12);
      expect(subtitle.fontWeight, FontWeight.w400);
      expect(tester.takeException(), isNull);
    },
  );

  for (final localeFonts in [
    (
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      fonts: const ['Microsoft YaHei UI', 'Microsoft YaHei'],
    ),
    (
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      fonts: const ['Microsoft JhengHei UI', 'Microsoft JhengHei'],
    ),
    (locale: const Locale('ja'), fonts: const ['Yu Gothic UI', 'Meiryo']),
    (locale: const Locale('ko'), fonts: const ['Malgun Gothic']),
  ]) {
    testWidgets('Windows ${localeFonts.locale} preserves font preferences', (
      tester,
    ) async {
      const customFallbacks = ['Existing CJK font', 'Existing symbol font'];
      await tester.pumpWidget(
        _app(
          const SkedPanelHeader(
            title: Text('课程 · Course', key: _titleKey),
            showClose: false,
          ),
          locale: localeFonts.locale,
          theme: _theme(
            fontFamily: 'User preferred font',
            fallbacks: customFallbacks,
          ),
        ),
      );
      final style = _paragraph(tester, find.byKey(_titleKey)).text.style!;
      expect(style.fontFamily, 'User preferred font');
      expect(
        style.fontFamilyFallback,
        containsAllInOrder([...customFallbacks, ...localeFonts.fonts]),
      );
      expect(style.fontFamilyFallback!.take(2), customFallbacks);
      _expectTaskStyle(_paragraph(tester, find.byKey(_titleKey)));
    });
  }

  testWidgets('mobile retains native dialog and inherited header typography', (
    tester,
  ) async {
    const inherited = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      height: 1.6,
      letterSpacing: 0.7,
    );
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 280,
              child: Row(
                children: [
                  Expanded(
                    child: SkedTaskDialog(
                      title: Text('Original', key: ValueKey('mobile-task')),
                      content: Text('Content'),
                    ),
                  ),
                  Expanded(
                    child: AlertDialog(
                      title: Text('Native', key: ValueKey('native-dialog')),
                      content: Text('Content'),
                    ),
                  ),
                ],
              ),
            ),
            const DefaultTextStyle(
              style: inherited,
              child: SkedPanelHeader(
                prominentTitle: true,
                showClose: false,
                title: Text('Mobile header', key: _titleKey),
              ),
            ),
          ],
        ),
        width: 720,
        theme: _theme(platform: TargetPlatform.android),
      ),
    );
    expect(find.byType(AlertDialog), findsNWidgets(2));
    expect(
      _paragraph(tester, _key('mobile-task')).text.style,
      _paragraph(tester, _key('native-dialog')).text.style,
    );
    final mobileHeader = _paragraph(tester, find.byKey(_titleKey)).text.style!;
    expect(mobileHeader.fontSize, inherited.fontSize);
    expect(mobileHeader.fontWeight, inherited.fontWeight);
    expect(mobileHeader.fontStyle, inherited.fontStyle);
    expect(mobileHeader.height, inherited.height);
    expect(mobileHeader.letterSpacing, inherited.letterSpacing);
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'wrapped and composite headers keep centered chrome: $direction',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          for (final configuration in [
            (long: false, close: true, subtitle: false, drag: false),
            (long: true, close: true, subtitle: true, drag: true),
            (long: true, close: false, subtitle: true, drag: false),
            (long: false, close: false, subtitle: false, drag: true),
          ]) {
            var drags = 0;
            var closes = 0;
            final titleText = configuration.long
                ? '选择周次 · Course teaching weeks across the semester'
                : '选择周次';
            final text = Text(titleText, key: _titleKey);
            final title = configuration.long
                ? Row(
                    key: const ValueKey('title-slot'),
                    children: [
                      const ExcludeSemantics(
                        child: Icon(Icons.date_range, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: text),
                    ],
                  )
                : SizedBox(key: const ValueKey('title-slot'), child: text);
            await tester.pumpWidget(
              _app(
                SkedPanelHeader(
                  title: title,
                  subtitle: configuration.subtitle
                      ? const Text(
                          'Term 2026 · Draft selection',
                          key: _subtitleKey,
                        )
                      : null,
                  onDrag: configuration.drag ? (_) => drags++ : null,
                  showClose: configuration.close,
                  onClose: () => closes++,
                  closeKey: const ValueKey('heading-close'),
                ),
                width: 280,
                scale: 1.5,
                direction: direction,
              ),
            );
            await tester.pumpAndSettle();
            final heading = tester.getRect(_key('title-slot'));
            final panel = tester.getRect(find.byType(SkedPanelHeader));
            final titleRow = tester.getRect(
              find
                  .ancestor(of: _key('title-slot'), matching: find.byType(Row))
                  .last,
            );
            expect(heading.center.dy, closeTo(titleRow.center.dy, 0.1));
            expect(titleRow.height, greaterThanOrEqualTo(32));
            if (configuration.subtitle) {
              expect(
                tester.getRect(find.byKey(_subtitleKey)).top - titleRow.bottom,
                closeTo(4, 0.1),
              );
            }
            expect(
              direction == TextDirection.ltr ? heading.left : heading.right,
              closeTo(
                direction == TextDirection.ltr ? panel.left : panel.right,
                0.1,
              ),
            );
            final paragraph = _paragraph(tester, find.byKey(_titleKey));
            _expectTaskStyle(paragraph);
            expect(paragraph.didExceedMaxLines, isFalse);
            if (configuration.long) {
              expect(paragraph.size.height, greaterThan(16 * 1.5 * 1.35 * 2));
            }
            expect(
              tester
                  .getSemantics(find.byKey(_titleKey))
                  .flagsCollection
                  .isHeader,
              isTrue,
            );
            final close = _key('heading-close');
            if (configuration.close) {
              expect(
                tester.getCenter(close).dy,
                closeTo(heading.center.dy, 0.1),
              );
              await tester.tap(close);
              expect(closes, 1);
              expect(drags, 0);
            } else {
              expect(close, findsNothing);
            }
            if (configuration.drag) {
              await tester.drag(_key('title-slot'), const Offset(40, 12));
              expect(drags, greaterThan(0));
            } else {
              expect(find.byType(SkedFloatingTitleDragHandle), findsNothing);
            }
            expect(tester.takeException(), isNull);
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
