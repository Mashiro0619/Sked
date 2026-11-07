import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/context/context_checkpoint.dart';
import 'package:sked/agent/context/context_service.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/models/agent_settings.dart';

const _summary =
    '目标：建立秋季课表。已确认9月1日开学；课表已保存，回执operation-A。待添加英语。参考文件synthetic-file。';

class _Store implements ContextCheckpointStore {
  final rows = <ContextCheckpoint>[];
  final failures = <String, ContextCompactionFailure>{};
  bool fail = false;
  Future<void> Function()? beforeCommit;
  @override
  Future<ContextCheckpoint?> latest(String conversationId) async =>
      rows.where((row) => row.conversationId == conversationId).lastOrNull;
  @override
  Future<void> append(
    ContextCheckpoint checkpoint, {
    void Function()? validate,
  }) async {
    await beforeCommit?.call();
    if (fail) throw StateError('Synthetic storage failure');
    validate?.call();
    rows.add(checkpoint);
    failures.remove(checkpoint.sourceKey);
  }

  @override
  Future<void> clear(String conversationId) async {
    rows.removeWhere((row) => row.conversationId == conversationId);
    failures.removeWhere(
      (_, failure) => failure.conversationId == conversationId,
    );
  }

  @override
  Future<ContextCompactionFailure?> failedSource(
    String conversationId,
    String sourceKey,
  ) async => failures[sourceKey];
  @override
  Future<void> saveFailure(ContextCompactionFailure failure) async =>
      failures[failure.sourceKey] = failure;
  @override
  Future<void> clearFailure(String conversationId, String sourceKey) async =>
      failures.remove(sourceKey);
}

AgentModelConfig _model({
  String id = 'fixture-model',
  int? window,
  int? trigger,
  bool auto = true,
}) => AgentModelConfig(
  id: id,
  reasoningEfforts: const [AgentReasoningEffort.medium],
  defaultReasoningEffort: AgentReasoningEffort.medium,
  maxContextTokens: window,
  autoCompactAtTokens: trigger,
  autoCompact: auto,
);

ContextSnapshot _snapshot({
  AgentModelConfig? model,
  List<ContextEntry>? entries,
  ProviderProtocol protocol = ProviderProtocol.chatCompletions,
}) {
  final selected = model ?? _model(window: 32000);
  final source =
      entries ??
      [
        ContextEntry(
          'goal',
          ProviderMessage(
            role: ProviderRole.user,
            text: '建立秋季课表。${'用户背景 ' * 500}',
          ),
        ),
        ContextEntry(
          'read-call',
          ProviderMessage(
            role: ProviderRole.assistant,
            toolCalls: [
              ProviderToolCall(
                id: 'read',
                name: 'timetables.list',
                arguments: '{}',
              ),
            ],
          ),
        ),
        ContextEntry(
          'read-result',
          ProviderMessage(
            role: ProviderRole.tool,
            toolCallId: 'read',
            text: jsonEncode({'items': [], 'notes': '历史数据 ' * 1800}),
          ),
        ),
        ContextEntry(
          'question',
          ProviderMessage(
            role: ProviderRole.assistant,
            text: '请确认开学日期。${'说明 ' * 500}',
          ),
        ),
        ContextEntry(
          'decision',
          ProviderMessage(
            role: ProviderRole.user,
            text: '9月1日开学。${'补充信息 ' * 500}',
          ),
        ),
        ContextEntry(
          'saved',
          ProviderMessage(
            role: ProviderRole.assistant,
            text: '课表已保存，operation-A。${'旧过程 ' * 600}',
          ),
        ),
        ContextEntry(
          'latest',
          ProviderMessage(role: ProviderRole.user, text: '接下来添加英语课程。'),
        ),
        ContextEntry(
          'recent',
          ProviderMessage(role: ProviderRole.assistant, text: '正在添加英语课程。'),
        ),
      ];
  return ContextSnapshot(
    conversationId: 'conversation',
    model: selected,
    entries: source,
    request: ProviderRequest(
      endpoint: Uri.parse(
        'https://fixture.example/v1/${protocol == ProviderProtocol.responses ? 'responses' : 'chat/completions'}',
      ),
      model: selected.id,
      protocol: protocol,
      maxOutputTokens: 2048,
      reasoningEffort: 'medium',
      tools: [
        ToolDefinition(
          name: 'timetables.list',
          description: 'Read timetables',
          parameters: const {'type': 'object', 'properties': {}},
        ),
      ],
      messages: [
        ProviderMessage(
          role: ProviderRole.system,
          text: 'Synthetic system instructions',
        ),
        ...source.map((entry) => entry.message),
      ],
    ),
  );
}

http.Response _response({
  String summary = _summary,
  ProviderProtocol protocol = ProviderProtocol.chatCompletions,
}) => http.Response(
  jsonEncode(
    protocol == ProviderProtocol.responses
        ? {
            'status': 'completed',
            'output': [
              {
                'type': 'message',
                'role': 'assistant',
                'content': [
                  {'type': 'output_text', 'text': summary},
                ],
              },
            ],
          }
        : {
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': summary},
                'finish_reason': 'stop',
              },
            ],
            'usage': {
              'prompt_tokens': 900,
              'completion_tokens': 40,
              'total_tokens': 940,
            },
          },
  ),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _paired(Iterable<ProviderMessage> messages) {
  final pending = <String>{};
  for (final message in messages) {
    pending.addAll(message.toolCalls.map((call) => call.id));
    if (message.toolCallId case final id?) {
      expect(
        pending.remove(id),
        isTrue,
        reason: 'Tool result $id must retain its preceding call',
      );
    }
  }
  expect(pending, isEmpty);
}

void main() {
  late _Store store;
  late List<Map<String, dynamic>> requests;
  late Future<http.Response> Function(http.Request) respond;
  late ProviderClient provider;
  late ContextService service;
  setUp(() {
    store = _Store();
    requests = [];
    respond = (_) async => _response();
    provider = ProviderClient(
      client: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return respond(request);
      }),
    );
    var id = 0;
    service = ContextService(
      store: store,
      provider: provider,
      idGenerator: () => 'summary-${id++}',
      clock: () => DateTime.utc(2026, 11, 7),
    );
  });
  tearDown(() => provider.close());

  test('input usage calibrates the current request instead of accumulating billing', () {
    final request = _snapshot().request;
    expect(service.measure(request).estimatedTokens, service.estimate(request));
    service.recordUsage(
      request,
      const ProviderUsage(
        inputTokens: 800,
        outputTokens: 200,
        totalTokens: 1000,
      ),
    );
    expect(service.measure(request).estimatedTokens, 800);
    service.recordUsage(
      request,
      const ProviderUsage(
        inputTokens: 600,
        outputTokens: 200,
        totalTokens: 800,
      ),
    );
    expect(service.measure(request).estimatedTokens, 600);
    final nextRequest = _snapshot().request;
    expect(nextRequest, isNot(same(request)));
    expect(service.measure(nextRequest).estimatedTokens, 600);
    final another = _snapshot(model: _model(id: 'another')).request;
    expect(service.measure(another).estimatedTokens, service.estimate(another));
  });

  test(
    'unknown windows remain unset and an explicit token trigger works',
    () async {
      expect(
        await service.needsCompaction(_snapshot(model: _model())),
        isFalse,
      );
      expect(
        await service.needsCompaction(_snapshot(model: _model(trigger: 100))),
        isTrue,
      );
      expect(
        await service.needsCompaction(
          _snapshot(model: _model(window: 100, auto: false)),
        ),
        isFalse,
      );
      expect(_model(window: 1000).effectiveCompactAtTokens, 800);
    },
  );

  test('system instructions, tool definitions and binary metadata count toward request size', () {
    final plain = _snapshot(
      entries: [
        ContextEntry(
          'small',
          ProviderMessage(role: ProviderRole.user, text: 'hello'),
        ),
      ],
    );
    final full = plain.request;
    final small = ProviderRequest(
      endpoint: full.endpoint,
      model: full.model,
      messages: [ProviderMessage(role: ProviderRole.user, text: 'hello')],
    );
    expect(service.estimate(full), greaterThan(service.estimate(small)));
    final file = ProviderAttachment(
      id: 'file',
      filename: 'fixture.pdf',
      mediaType: 'application/pdf',
      byteLength: 9000,
      digest: 'synthetic-digest',
      openRead: () => throw StateError('Measuring never reads bytes'),
    );
    final attachment = ProviderRequest(
      endpoint: full.endpoint,
      model: full.model,
      messages: [
        ProviderMessage(
          role: ProviderRole.user,
          text: 'hello',
          attachments: [file],
        ),
      ],
    );
    expect(
      service.estimate(attachment),
      greaterThan(service.estimate(small) + 3000),
    );
  });

  for (final protocol in ProviderProtocol.values) {
    test(
      'manual compaction via ${protocol.name} preserves original archive and request options',
      () async {
        respond = (_) async => _response(protocol: protocol);
        final snapshot = _snapshot(
          model: _model(auto: false),
          protocol: protocol,
        );
        final before = contextSourceDigest(snapshot.entries);
        expect(
          await service.compact(
            snapshot,
            apiKey: 'synthetic',
            cancellation: ProviderCancellationToken(),
            manual: true,
          ),
          isTrue,
        );
        expect(requests, hasLength(1));
        final sent =
            requests.single[protocol == ProviderProtocol.responses
                    ? 'input'
                    : 'messages']
                as List;
        expect(jsonEncode(sent), contains('operation-A'));
        final working = await service.workingRequest(snapshot);
        expect(
          working.messages.map((message) => message.text).join(),
          contains(_summary),
        );
        expect(working.messages.last.text, snapshot.entries.last.message.text);
        expect(working.messages.first.text, 'Synthetic system instructions');
        expect(working.maxOutputTokens, 2048);
        expect(working.tools.single.name, 'timetables.list');
        expect(contextSourceDigest(snapshot.entries), before);
        expect(
          store.rows.single.estimatedTokensAfter,
          lessThan(store.rows.single.tokensBefore),
        );
        expect(
          store.rows.single.sourceMessageIds,
          snapshot.entries.take(6).map((entry) => entry.id),
        );
        _paired(working.messages);
      },
    );
  }

  test('recent tool calls stay paired and source attachment references remain available', () async {
    var reads = 0;
    final file = ProviderAttachment(
      id: 'synthetic-file',
      filename: 'schedule.pdf',
      mediaType: 'application/pdf',
      byteLength: 40,
      digest: 'file-digest',
      openRead: () {
        reads++;
        return Stream.value([1, 2, 3]);
      },
    );
    final base = _snapshot();
    final entries = [
      ContextEntry(
        'goal-file',
        ProviderMessage(
          role: ProviderRole.user,
          text: 'Read this schedule',
          attachments: [file],
        ),
      ),
      ...base.entries.skip(1).take(5),
      ContextEntry(
        'recent-call',
        ProviderMessage(
          role: ProviderRole.assistant,
          toolCalls: [
            ProviderToolCall(
              id: 'new-call',
              name: 'timetables.list',
              arguments: '{}',
            ),
          ],
        ),
      ),
      ContextEntry(
        'recent-result',
        ProviderMessage(
          role: ProviderRole.tool,
          toolCallId: 'new-call',
          text: '{"items":[]}',
        ),
      ),
    ];
    final snapshot = _snapshot(entries: entries);
    expect(
      await service.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
        manual: true,
      ),
      isTrue,
    );
    final working = await service.workingRequest(snapshot);
    _paired(working.messages);
    expect(
      working.messages.expand((message) => message.attachments).single,
      same(file),
    );
    expect(jsonEncode(requests.single), contains('file-digest'));
    expect(reads, 0);
  });

  test('the latest user decision survives a long single-user tool workflow verbatim', () async {
    final entries = [
      ContextEntry(
        'request',
        ProviderMessage(
          role: ProviderRole.user,
          text: 'Confirmed: start September 1.',
        ),
      ),
      for (var i = 0; i < 4; i++) ...[
        ContextEntry(
          'call-$i',
          ProviderMessage(
            role: ProviderRole.assistant,
            toolCalls: [
              ProviderToolCall(
                id: 'tool-$i',
                name: 'timetables.list',
                arguments: '{}',
              ),
            ],
          ),
        ),
        ContextEntry(
          'result-$i',
          ProviderMessage(
            role: ProviderRole.tool,
            toolCallId: 'tool-$i',
            text: 'Result ' * 2000,
          ),
        ),
      ],
    ];
    final snapshot = _snapshot(entries: entries);
    await service.compact(
      snapshot,
      apiKey: '',
      cancellation: ProviderCancellationToken(),
      manual: true,
    );
    final working = await service.workingRequest(snapshot);
    expect(
      working.messages.any(
        (message) => message.text == entries.first.message.text,
      ),
      isTrue,
    );
    _paired(working.messages);
  });

  test(
    'summary persistence failure retains the original working context',
    () async {
      final snapshot = _snapshot();
      store.fail = true;
      await expectLater(
        service.compact(
          snapshot,
          apiKey: '',
          cancellation: ProviderCancellationToken(),
          manual: true,
        ),
        throwsStateError,
      );
      expect(store.rows, isEmpty);
      final working = await service.workingRequest(snapshot);
      expect(
        working.messages.map((message) => message.text),
        snapshot.request.messages.map((message) => message.text),
      );
    },
  );

  test('automatic compaction does not repeat the same failed source and manual retry remains available', () async {
    final snapshot = _snapshot();
    respond = (_) async => http.Response('Synthetic upstream failure', 503);
    await expectLater(
      service.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
      ),
      throwsA(isA<ProviderException>()),
    );
    expect(
      await service.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
      ),
      isFalse,
    );
    expect(requests, hasLength(1));
    respond = (_) async => _response();
    expect(
      await service.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
        manual: true,
      ),
      isTrue,
    );
    expect(requests, hasLength(2));
  });

  test('empty or non-reducing summaries are not activated', () async {
    final snapshot = _snapshot();
    respond = (_) async => _response(summary: ' ');
    await expectLater(
      service.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
        manual: true,
      ),
      throwsA(isA<ContextCompactionException>()),
    );
    respond = (_) async => _response(summary: 'This is too long ' * 20000);
    await expectLater(
      service.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
        manual: true,
      ),
      throwsA(isA<ContextCompactionException>()),
    );
    expect(store.rows, isEmpty);
  });

  for (final cancel in [true, false]) {
    test(
      '${cancel ? 'cancellation' : 'source replacement'} during save preserves the old checkpoint',
      () async {
        final snapshot = _snapshot();
        await service.compact(
          snapshot,
          apiKey: '',
          cancellation: ProviderCancellationToken(),
          manual: true,
        );
        final old = store.rows.single;
        final next = _snapshot(
          entries: [
            ...snapshot.entries,
            ContextEntry(
              'more',
              ProviderMessage(
                role: ProviderRole.user,
                text: 'Next goal ' * 1500,
              ),
            ),
            ContextEntry(
              'more-reply',
              ProviderMessage(
                role: ProviderRole.assistant,
                text: 'More results ' * 1500,
              ),
            ),
            ContextEntry(
              'last',
              ProviderMessage(role: ProviderRole.user, text: 'Continue'),
            ),
          ],
        );
        final entered = Completer<void>();
        final release = Completer<void>();
        store.beforeCommit = () async {
          entered.complete();
          await release.future;
        };
        final cancellation = ProviderCancellationToken();
        var valid = true;
        final running = service.compact(
          next,
          apiKey: '',
          cancellation: cancellation,
          manual: true,
          validateSource: () {
            if (!valid) throw StateError('Source changed');
          },
        );
        final assertion = expectLater(
          running,
          throwsA(cancel ? isA<ProviderException>() : isA<StateError>()),
        );
        await entered.future;
        if (cancel) {
          cancellation.cancel();
        } else {
          valid = false;
        }
        release.complete();
        await assertion;
        expect(store.rows.single, same(old));
      },
    );
  }

  test('cancelled model generation does not store a checkpoint', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    respond = (_) async {
      entered.complete();
      await release.future;
      return _response();
    };
    final cancellation = ProviderCancellationToken();
    final running = service.compact(
      _snapshot(),
      apiKey: '',
      cancellation: cancellation,
      manual: true,
    );
    final assertion = expectLater(running, throwsA(isA<ProviderException>()));
    await entered.future;
    cancellation.cancel();
    release.complete();
    await assertion;
    expect(store.rows, isEmpty);
  });

  test('edited source and model switch rebuild from originals rather than an old summary', () async {
    final snapshot = _snapshot();
    await service.compact(
      snapshot,
      apiKey: '',
      cancellation: ProviderCancellationToken(),
      manual: true,
    );
    final edited = _snapshot(
      entries: [
        ContextEntry(
          'goal',
          ProviderMessage(role: ProviderRole.user, text: 'NEW DECISION'),
        ),
        ...snapshot.entries.skip(1),
      ],
    );
    final changed = await service.workingRequest(edited);
    expect(
      changed.messages.any((message) => message.text.contains(_summary)),
      isFalse,
    );
    expect(
      changed.messages.any((message) => message.text == 'NEW DECISION'),
      isTrue,
    );
    final other = await service.workingRequest(
      _snapshot(
        model: _model(id: 'different-model'),
        entries: snapshot.entries,
      ),
    );
    expect(
      other.messages.any((message) => message.text.contains(_summary)),
      isFalse,
    );
    expect(other.messages.length, snapshot.request.messages.length);
  });

  test('failed automatic source stays paused after service recreation and manual retry clears it', () async {
    final snapshot = _snapshot();
    respond = (_) async => _response(summary: '');
    await expectLater(
      service.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
      ),
      throwsA(isA<ContextCompactionException>()),
    );
    expect(store.failures, hasLength(1));
    final restarted = ContextService(store: store, provider: provider);
    expect(
      await restarted.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
      ),
      isFalse,
    );
    expect(requests, hasLength(1));
    expect(
      (await restarted.failedSource(snapshot))!.errorCode,
      'empty_or_invalid_summary',
    );
    respond = (_) async => _response();
    expect(
      await restarted.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
        manual: true,
      ),
      isTrue,
    );
    expect(requests, hasLength(2));
    expect(store.failures, isEmpty);
    final recovered = ContextService(store: store, provider: provider);
    expect(
      await recovered.compact(
        snapshot,
        apiKey: '',
        cancellation: ProviderCancellationToken(),
        manual: true,
      ),
      isTrue,
    );
    expect(
      requests,
      hasLength(2),
      reason: 'A saved source is reused when a control was not yet consumed before shutdown.',
    );
  });
}
