import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/theme/app_theme.dart';

class UiMemoryStorage extends ConversationStorage {
  UiMemoryStorage() : super.base();
  String? source;
  bool fail = false;
  Future<void> Function()? beforeSave;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    await beforeSave?.call();
    if (fail) throw StateError('raw-secret-must-not-be-shown');
    source = value;
  }
}

class UiDelegate extends AgentUiDelegate {
  UiDelegate(this.repository);
  final ConversationRepository repository;
  @override
  final ValueNotifier<AgentUiState> state = ValueNotifier(
    AgentUiState(enabled: true, configured: true),
  );
  final calls = <String>[];
  bool failSend = false;
  int queued = 0;
  @override
  Future<void> send(String conversationId, String text) async {
    calls.add('send:$conversationId:$text');
    if (failSend) throw StateError('raw-secret-must-not-be-shown');
  }

  @override
  Future<void> queueFollowUp(String conversationId, String text) async {
    calls.add('queue:$conversationId:$text');
    queued++;
    await repository.update(
      conversationId,
      (value) => value.copyWith(draft: ''),
    );
  }

  @override
  Future<void> steer(String conversationId, String text) async {
    calls.add('steer:$conversationId:$text');
    queued++;
    await repository.update(
      conversationId,
      (value) => value.copyWith(draft: ''),
    );
  }

  @override
  Future<void> continueConversation(String conversationId) async =>
      calls.add('continue:$conversationId');

  @override
  int pendingInputCount(String conversationId) => queued;

  @override
  Future<void> setArchived(String conversationId, bool archived) async {
    calls.add('archive:$conversationId:$archived');
    await repository.update(
      conversationId,
      (value) => value.copyWith(archived: archived),
    );
  }

  @override
  Future<void> stop(String conversationId) async =>
      calls.add('stop:$conversationId');
  @override
  Future<void> approve(String conversationId, String planId) async =>
      calls.add('approve:$conversationId:$planId');
  @override
  Future<void> reject(String conversationId, String planId) async =>
      calls.add('reject:$conversationId:$planId');
  @override
  Future<void> setMode(String conversationId, AgentPermissionMode mode) async {
    calls.add('mode:$conversationId:${mode.name}');
    await repository.update(
      conversationId,
      (current) => current.copyWith(mode: mode),
    );
  }

  @override
  void openSettings() => calls.add('settings');
}

Future<void> mountAgentUi(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(460, 820),
  double scale = 1,
  double keyboard = 0,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(
        seedColor: const Color(0xff6750a4),
        brightness: brightness,
        themeColorMode: 'solid',
        colorfulUiColorValues: const {},
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}
