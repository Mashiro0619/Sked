import 'dart:convert';

import 'provider_models.dart';

class ProviderSseFrame {
  const ProviderSseFrame(this.event, this.data);
  final String? event;
  final String data;
}

/// Incremental SSE decoder with UTF-8, CR/LF/CRLF, comments and data folding.
/// A stream ending without a blank line never completes its pending frame.
class ProviderSseDecoder {
  ProviderSseDecoder({required this.maxEventBytes});

  final int maxEventBytes;
  final List<int> _line = [];
  final List<String> _data = [];
  String? _event;
  int _eventBytes = 0;
  bool _skipLf = false;
  bool _firstLine = true;

  List<ProviderSseFrame> add(List<int> bytes) {
    final result = <ProviderSseFrame>[];
    for (final byte in bytes) {
      if (_skipLf && byte == 10) {
        _skipLf = false;
        continue;
      }
      _skipLf = false;
      if (++_eventBytes > maxEventBytes) {
        throw const ProviderException(ProviderError.eventBudgetExceeded);
      }
      if (byte == 10 || byte == 13) {
        _skipLf = byte == 13;
        var line = utf8.decode(_line);
        _line.clear();
        if (_firstLine && line.startsWith('\uFEFF')) line = line.substring(1);
        _firstLine = false;
        if (line.isEmpty) {
          if (_data.isNotEmpty) {
            result.add(ProviderSseFrame(_event, _data.join('\n')));
          }
          _data.clear();
          _event = null;
          _eventBytes = 0;
        } else if (!line.startsWith(':')) {
          final colon = line.indexOf(':');
          final field = colon < 0 ? line : line.substring(0, colon);
          var value = colon < 0 ? '' : line.substring(colon + 1);
          if (value.startsWith(' ')) value = value.substring(1);
          if (field == 'event') _event = value;
          if (field == 'data') _data.add(value);
        }
      } else {
        _line.add(byte);
      }
    }
    return result;
  }
}
