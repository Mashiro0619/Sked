import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/settings_data_transfer_controller.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/widgets/settings_list.dart';

Finder k(String id) => find.byKey(ValueKey(id));

Future<void> _page(
  WidgetTester t, {
  required bool student,
  required Size size,
  required double scale,
  required List<Object> actions,
  bool busy = false,
  SettingsTransferDirection? direction,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(
    MaterialApp(
      locale: Locale(scale == 1.3 ? 'en' : 'zh'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(
        seedColor: const Color(0xff6750a4),
        brightness: scale == 2 ? Brightness.dark : Brightness.light,
        themeColorMode: 'single',
        colorfulUiColorValues: const {},
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: scale == 1.3 ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
      ),
      home: Builder(
        builder: (context) {
          const controller = SettingsDataTransferController();
          return Scaffold(
            body: student
                ? controller.studentPageContent(
                    context,
                    busy: busy,
                    direction: direction,
                    onAction: actions.add,
                    additionalImports: [
                      SettingsTransferPageTile(
                        key: const ValueKey('test-web'),
                        icon: Icons.language,
                        title: '学校网页',
                        subtitle: '登录学校网站并选择课表页',
                        onTap: busy ? null : () => actions.add('web'),
                      ),
                    ],
                    importConfiguration: [
                      SettingsTransferPageTile(
                        key: const ValueKey('test-parser'),
                        icon: Icons.tune,
                        title: '解析 API',
                        subtitle: '配置课表导入使用的接口',
                        onTap: busy ? null : () => actions.add('parser'),
                      ),
                    ],
                  )
                : controller.generalPageContent(
                    context,
                    busy: busy,
                    direction: direction,
                    onAction: actions.add,
                  ),
          );
        },
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final student in [true, false]) {
    for (final width in [320.0, 393.0, 800.0, 1280.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'transfer rows fit, align and retain actions: student=$student $width/$scale',
          (t) async {
            final actions = <Object>[];
            await _page(
              t,
              student: student,
              size: Size(width, 1000),
              scale: scale,
              actions: actions,
            );
            final expectedSplit =
                (width - (width < 600 ? 32 : 48)).clamp(0, 1040) >=
                720 * scale + 24;
            expect(
              k('transfer-two-columns'),
              expectedSplit ? findsOneWidget : findsNothing,
            );
            final imports = t.getRect(k('transfer-import-group'));
            final exports = t.getRect(k('transfer-export-group'));
            if (expectedSplit) {
              expect(imports.top, exports.top);
              final gap = imports.left < exports.left
                  ? exports.left - imports.right
                  : imports.left - exports.right;
              expect(gap, closeTo(24, 0.01));
            } else {
              expect(exports.top, greaterThan(imports.bottom));
            }
            final groups = find.byType(SettingsConnectedGroup);
            expect(groups, findsNWidgets(student ? 3 : 2));
            for (final groupElement in groups.evaluate()) {
              final group = groupElement.widget as SettingsConnectedGroup;
              expect(group.tonal, isTrue);
              expect(group.margin, EdgeInsets.zero);
              final surface = t.widget<Material>(
                find.descendant(
                  of: find.byWidget(group),
                  matching: find.byKey(const ValueKey('settings-group-row-0')),
                ),
              );
              final colors = Theme.of(groupElement).colorScheme;
              expect(surface.color, SettingsVisuals.rowColor(colors));
              expect(surface.elevation, 0);
              expect(
                (surface.shape! as RoundedRectangleBorder).side,
                BorderSide.none,
              );
            }
            final rows = find.byType(SettingsTransferPageTile);
            expect(rows, findsNWidgets(student ? 8 : 10));
            for (final element in rows.evaluate()) {
              final row = find.byWidget(element.widget);
              await t.ensureVisible(row);
              await t.pumpAndSettle();
              final rect = t.getRect(row);
              expect(rect.height, greaterThanOrEqualTo(80));
              expect(rect.left, greaterThanOrEqualTo(16));
              expect(rect.right, lessThanOrEqualTo(width - 16));
              final texts = find.descendant(
                of: row,
                matching: find.byType(Text),
              );
              final title = t.getRect(texts.first),
                  subtitle = t.getRect(texts.last);
              expect(subtitle.top - title.bottom, closeTo(4, 0.001));
              expect(title.top - rect.top, greaterThanOrEqualTo(15.99));
              expect(
                rect.bottom - subtitle.bottom,
                greaterThanOrEqualTo(15.99),
              );
              if (scale == 1.3) {
                expect(title.right, closeTo(subtitle.right, 0.001));
              } else {
                expect(title.left, closeTo(subtitle.left, 0.001));
              }
              for (final text in texts.evaluate()) {
                expect(
                  (text.renderObject! as RenderParagraph).didExceedMaxLines,
                  isFalse,
                );
              }
              expect(
                t.widget<Text>(texts.first).style!.fontWeight,
                FontWeight.w400,
              );
              await t.tap(row);
              await t.pumpAndSettle();
            }
            expect(actions.toSet().length, student ? 8 : 10);
            expect(t.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(
            width < 600 ? TargetPlatform.android : TargetPlatform.windows,
          ),
        );
      }
    }
  }

  for (final direction in SettingsTransferDirection.values) {
    testWidgets(
      'focused $direction keeps only its task group and respects disabled state',
      (t) async {
        final actions = <Object>[];
        await _page(
          t,
          student: true,
          size: const Size(1280, 900),
          scale: 1,
          actions: actions,
          direction: direction,
          busy: true,
        );
        expect(k('transfer-two-columns'), findsNothing);
        expect(
          k('transfer-import-group'),
          direction == SettingsTransferDirection.import
              ? findsOneWidget
              : findsNothing,
        );
        expect(
          k('transfer-export-group'),
          direction == SettingsTransferDirection.export
              ? findsOneWidget
              : findsNothing,
        );
        expect(
          k('transfer-configuration-group'),
          direction == SettingsTransferDirection.import
              ? findsOneWidget
              : findsNothing,
        );
        expect(t.getSize(k('transfer-page-content')).width, 680);
        for (final element
            in find.byType(SettingsTransferPageTile).evaluate()) {
          final row = find.byWidget(element.widget);
          await t.ensureVisible(row);
          await t.pumpAndSettle();
          expect(t.widget<SettingsTransferPageTile>(row).onTap, isNull);
          await t.tap(row);
        }
        expect(actions, isEmpty);
        expect(t.takeException(), isNull);
      },
    );
  }
}
