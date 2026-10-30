import 'dart:convert';

import 'provider_models.dart';
import 'sse_decoder.dart';
import 'tool_name_codec.dart';

Map<String, Object?> encodeProviderRequest(ProviderRequest request) {
  final names = <String>{};
  for (final tool in request.tools) {
    if (!names.add(ToolNameCodec.encode(tool.name))) {
      throw const ProviderException(ProviderError.invalidRequest);
    }
  }
  for (final message in request.messages) {
    if ((message.toolCalls.isNotEmpty || message.responseItems.isNotEmpty) &&
        message.role != ProviderRole.assistant) {
      throw const ProviderException(ProviderError.invalidRequest);
    }
    if (message.role == ProviderRole.tool &&
        (message.toolCallId?.isEmpty ?? true)) {
      throw const ProviderException(ProviderError.invalidRequest);
    }
  }
  final tools = request.tools
      .map(
        (tool) => <String, Object?>{
          'name': ToolNameCodec.encode(tool.name),
          'description': tool.description,
          'parameters': tool.parameters,
          'strict': tool.strict,
        },
      )
      .toList();
  if (request.protocol == ProviderProtocol.chatCompletions) {
    return {
      'model': request.model,
      'stream': true,
      'stream_options': {'include_usage': true},
      'max_completion_tokens': request.limits.maxOutputTokens,
      'messages': request.messages
          .map(
            (message) => <String, Object?>{
              'role': message.role.name,
              'content': message.text,
              if (message.role == ProviderRole.tool)
                'tool_call_id': message.toolCallId,
              if (message.toolCalls.isNotEmpty)
                'tool_calls': message.toolCalls
                    .map(
                      (call) => {
                        'id': call.id,
                        'type': 'function',
                        'function': {
                          'name': ToolNameCodec.encode(call.name),
                          'arguments': call.arguments,
                        },
                      },
                    )
                    .toList(),
            },
          )
          .toList(),
      if (tools.isNotEmpty)
        'tools': tools
            .map((tool) => {'type': 'function', 'function': tool})
            .toList(),
    };
  }
  final input = <Map<String, Object?>>[];
  for (final message in request.messages) {
    if (message.role == ProviderRole.tool) {
      input.add({
        'type': 'function_call_output',
        'call_id': message.toolCallId,
        'output': message.text,
      });
    } else if (message.responseItems.isNotEmpty) {
      input.addAll(message.responseItems);
    } else {
      if (message.text.isNotEmpty || message.toolCalls.isEmpty) {
        input.add({'role': message.role.name, 'content': message.text});
      }
      for (final call in message.toolCalls) {
        input.add({
          'type': 'function_call',
          'call_id': call.id,
          'name': ToolNameCodec.encode(call.name),
          'arguments': call.arguments,
        });
      }
    }
  }
  return {
    'model': request.model,
    'stream': true,
    'store': false,
    'max_output_tokens': request.limits.maxOutputTokens,
    'input': input,
    if (tools.isNotEmpty)
      'tools': tools.map((tool) => {'type': 'function', ...tool}).toList(),
  };
}

class ProviderResponseDecoder {
  ProviderResponseDecoder(this.request)
    : _knownNames = {
        for (final t in request.tools) ToolNameCodec.encode(t.name): t.name,
      };

  final ProviderRequest request;
  final Map<String, String> _knownNames;
  final StringBuffer _text = StringBuffer();
  final Map<int, _ToolBuffer> _tools = {};
  ProviderUsage? _usage;
  String? _finishReason;
  List<Map<String, Object?>> _responseItems = const [];
  bool get isComplete => _complete;
  bool _complete = false;

  List<ProviderEvent> add(ProviderSseFrame frame) {
    if (_complete) {
      throw const ProviderException(ProviderError.invalidResponse);
    }
    if (request.protocol == ProviderProtocol.chatCompletions &&
        frame.data.trim() == '[DONE]') {
      return [_finish()];
    }
    final json = _map(jsonDecode(frame.data));
    if (json.containsKey('error')) {
      throw const ProviderException(ProviderError.httpFailure);
    }
    return request.protocol == ProviderProtocol.chatCompletions
        ? _chat(json)
        : _responses(json, frame.event);
  }

  List<ProviderEvent> addJson(Map<String, Object?> json) {
    if (json.containsKey('error')) {
      throw const ProviderException(ProviderError.httpFailure);
    }
    if (request.protocol == ProviderProtocol.responses) {
      return _responses({'type': 'response.completed', 'response': json}, null);
    }
    final choices = _list(json['choices']);
    if (choices.length != 1) {
      throw const ProviderException(ProviderError.invalidResponse);
    }
    final choice = _map(choices.single);
    final message = _map(choice['message']);
    final toolCalls = message['tool_calls'];
    final events = _chat({
      ...json,
      'choices': [
        {
          ...choice,
          'index': 0,
          'delta': {
            ...message,
            if (toolCalls is List)
              'tool_calls': [
                for (var i = 0; i < toolCalls.length; i++)
                  {..._map(toolCalls[i]), 'index': i},
              ],
          },
        },
      ],
    });
    return [...events, _finish()];
  }

  List<ProviderEvent> _chat(Map<String, Object?> json) {
    final events = <ProviderEvent>[];
    _readUsage(json['usage'], events);
    for (final value in _list(json['choices'])) {
      final choice = _map(value);
      if (choice['index'] != 0 || _finishReason != null) {
        throw const ProviderException(ProviderError.invalidResponse);
      }
      final delta = _map(choice['delta']);
      if (delta['content'] case final String text) _addText(text, events);
      if (delta['refusal'] case final String refusal when refusal.isNotEmpty) {
        throw const ProviderException(ProviderError.incompleteResponse);
      }
      if (delta['tool_calls'] case final List calls) {
        for (final raw in calls) {
          final call = _map(raw);
          final index = _index(call['index']);
          final tool = _tool(index);
          if (call['id'] case final String id) tool.id.write(id);
          if (call['type'] != null && call['type'] != 'function') {
            throw const ProviderException(ProviderError.invalidResponse);
          }
          final function = call['function'] == null
              ? const <String, Object?>{}
              : _map(call['function']);
          if (function['name'] case final String name) tool.name.write(name);
          if (function['arguments'] case final String arguments) {
            _addArguments(index, arguments, events);
          }
        }
      }
      if (choice['finish_reason'] case final String reason) {
        _finishReason = reason;
      }
    }
    return events;
  }

  List<ProviderEvent> _responses(Map<String, Object?> json, String? eventName) {
    final events = <ProviderEvent>[];
    final type = json['type'] ?? eventName;
    if (eventName != null && json['type'] != null && type != eventName) {
      throw const ProviderException(ProviderError.invalidResponse);
    }
    switch (type) {
      case 'response.output_text.delta':
        _addText(_string(json['delta']), events);
      case 'response.output_item.added':
        final item = _map(json['item']);
        if (item['type'] == 'function_call') {
          final index = _index(json['output_index']);
          if (_tools.containsKey(index)) {
            throw const ProviderException(ProviderError.duplicateToolCall);
          }
          final tool = _tool(index);
          tool.itemId = _string(item['id']);
          tool.id.write(_string(item['call_id']));
          tool.name.write(_string(item['name']));
          _addArguments(index, _string(item['arguments']), events);
        }
      case 'response.function_call_arguments.delta':
        final index = _index(json['output_index']);
        _existingResponseTool(index, json['item_id']);
        _addArguments(index, _string(json['delta']), events);
      case 'response.function_call_arguments.done':
        final index = _index(json['output_index']);
        final tool = _existingResponseTool(index, json['item_id']);
        if (tool.arguments.toString() != _string(json['arguments'])) {
          throw const ProviderException(ProviderError.invalidResponse);
        }
      case 'response.completed':
        final response = _map(json['response']);
        if (response['status'] != 'completed') {
          throw const ProviderException(ProviderError.incompleteResponse);
        }
        _readUsage(response['usage'], events);
        _reconcileOutput(_list(response['output']), events);
        _finishReason = _tools.isEmpty ? 'stop' : 'tool_calls';
        events.add(_finish());
      case 'response.failed':
      case 'error':
        throw const ProviderException(ProviderError.httpFailure);
      case 'response.incomplete':
      case 'response.cancelled':
        throw const ProviderException(ProviderError.incompleteResponse);
      default:
        // Other documented lifecycle, reasoning and content-part events carry
        // no executable calls. Final output retains continuation state.
        break;
    }
    return events;
  }

  void _reconcileOutput(List<Object?> output, List<ProviderEvent> events) {
    final finalText = StringBuffer();
    final finalTools = <int, _ToolBuffer>{};
    final items = <Map<String, Object?>>[];
    for (var i = 0; i < output.length; i++) {
      final item = _map(output[i]);
      items.add(item);
      if (item['type'] == 'message') {
        for (final raw in _list(item['content'])) {
          final content = _map(raw);
          if (content['type'] == 'output_text') {
            finalText.write(_string(content['text']));
          }
          if (content['type'] == 'refusal') {
            throw const ProviderException(ProviderError.incompleteResponse);
          }
        }
      } else if (item['type'] == 'function_call') {
        final tool = _ToolBuffer()
          ..id.write(_string(item['call_id']))
          ..name.write(_string(item['name']))
          ..arguments.write(_string(item['arguments']));
        finalTools[i] = tool;
      }
    }
    if (_text.isNotEmpty && _text.toString() != finalText.toString()) {
      throw const ProviderException(ProviderError.invalidResponse);
    }
    if (_text.isEmpty) _addText(finalText.toString(), events);
    for (final entry in _tools.entries) {
      final finalTool = finalTools[entry.key];
      if (finalTool == null || !entry.value.matches(finalTool)) {
        throw const ProviderException(ProviderError.invalidResponse);
      }
    }
    _tools.clear();
    _tools.addAll(finalTools);
    _responseItems = items;
  }

  _ToolBuffer _existingResponseTool(int index, Object? itemId) {
    final tool = _tools[index];
    if (tool == null || tool.itemId != itemId) {
      throw const ProviderException(ProviderError.invalidResponse);
    }
    return tool;
  }

  _ToolBuffer _tool(int index) {
    if (!_tools.containsKey(index) &&
        _tools.length >= request.limits.maxToolCalls) {
      throw const ProviderException(ProviderError.toolBudgetExceeded);
    }
    return _tools.putIfAbsent(index, _ToolBuffer.new);
  }

  void _addText(String text, List<ProviderEvent> events) {
    if (text.isEmpty) return;
    _text.write(text);
    events.add(ProviderTextDelta(text));
  }

  void _addArguments(int index, String arguments, List<ProviderEvent> events) {
    final tool = _tool(index);
    tool.argumentBytes += utf8.encode(arguments).length;
    if (tool.argumentBytes > request.limits.maxToolArgumentBytes) {
      throw const ProviderException(ProviderError.toolBudgetExceeded);
    }
    tool.arguments.write(arguments);
    if (arguments.isNotEmpty) {
      events.add(
        ProviderToolCallDelta(index: index, argumentsDelta: arguments),
      );
    }
  }

  void _readUsage(Object? value, List<ProviderEvent> events) {
    if (value == null) return;
    final usage = _map(value);
    final responses = request.protocol == ProviderProtocol.responses;
    final input = _count(usage[responses ? 'input_tokens' : 'prompt_tokens']);
    final output = _count(
      usage[responses ? 'output_tokens' : 'completion_tokens'],
    );
    final total = usage['total_tokens'] == null
        ? input + output
        : _count(usage['total_tokens']);
    if (total < input + output) {
      throw const ProviderException(ProviderError.invalidResponse);
    }
    final inputDetails =
        usage[responses ? 'input_tokens_details' : 'prompt_tokens_details'];
    final outputDetails =
        usage[responses
            ? 'output_tokens_details'
            : 'completion_tokens_details'];
    _usage = ProviderUsage(
      inputTokens: input,
      outputTokens: output,
      totalTokens: total,
      cachedInputTokens:
          inputDetails is Map && inputDetails['cached_tokens'] != null
          ? _count(inputDetails['cached_tokens'])
          : null,
      reasoningTokens:
          outputDetails is Map && outputDetails['reasoning_tokens'] != null
          ? _count(outputDetails['reasoning_tokens'])
          : null,
    );
    if (total > request.limits.maxTotalTokens) {
      throw const ProviderException(ProviderError.tokenBudgetExceeded);
    }
    events.add(ProviderUsageEvent(_usage!));
  }

  ProviderCompleted _finish() {
    if (_finishReason != 'stop' && _finishReason != 'tool_calls') {
      throw const ProviderException(ProviderError.incompleteResponse);
    }
    if (_tools.length > request.limits.maxToolCalls) {
      throw const ProviderException(ProviderError.toolBudgetExceeded);
    }
    if ((_finishReason == 'tool_calls') != _tools.isNotEmpty) {
      throw const ProviderException(ProviderError.invalidResponse);
    }
    final calls = <ProviderToolCall>[];
    final ids = <String>{};
    for (final index in _tools.keys.toList()..sort()) {
      final tool = _tools[index]!;
      final id = tool.id.toString();
      if (id.isEmpty) {
        throw const ProviderException(ProviderError.invalidResponse);
      }
      if (!ids.add(id)) {
        throw const ProviderException(ProviderError.duplicateToolCall);
      }
      final name = _knownNames[tool.name.toString()];
      if (name == null) {
        throw const ProviderException(ProviderError.unknownTool);
      }
      final arguments = tool.arguments.toString();
      if (utf8.encode(arguments).length > request.limits.maxToolArgumentBytes) {
        throw const ProviderException(ProviderError.toolBudgetExceeded);
      }
      try {
        if (jsonDecode(arguments) is! Map<String, dynamic>) {
          throw const FormatException();
        }
      } on FormatException {
        throw const ProviderException(ProviderError.invalidToolArguments);
      }
      calls.add(ProviderToolCall(id: id, name: name, arguments: arguments));
    }
    _complete = true;
    return ProviderCompleted(
      ProviderResponse(
        text: _text.toString(),
        toolCalls: calls,
        finishReason: _finishReason!,
        usage: _usage,
        responseItems: _responseItems,
      ),
    );
  }
}

class _ToolBuffer {
  final StringBuffer id = StringBuffer();
  final StringBuffer name = StringBuffer();
  final StringBuffer arguments = StringBuffer();
  String? itemId;
  int argumentBytes = 0;

  bool matches(_ToolBuffer other) =>
      id.toString() == other.id.toString() &&
      name.toString() == other.name.toString() &&
      arguments.toString() == other.arguments.toString();
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  throw const ProviderException(ProviderError.invalidResponse);
}

List<Object?> _list(Object? value) {
  if (value is List<Object?>) return value;
  throw const ProviderException(ProviderError.invalidResponse);
}

String _string(Object? value) {
  if (value is String) return value;
  throw const ProviderException(ProviderError.invalidResponse);
}

int _index(Object? value) {
  if (value is int && value >= 0 && value < 1000000) return value;
  throw const ProviderException(ProviderError.invalidResponse);
}

int _count(Object? value) {
  if (value is int && value >= 0) return value;
  throw const ProviderException(ProviderError.invalidResponse);
}
