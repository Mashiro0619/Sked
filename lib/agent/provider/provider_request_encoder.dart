import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'provider_models.dart';
import 'provider_protocol.dart';

/// Exact JSON text and declared binary sizes without opening attachment data.
({int textBytes, int attachmentBytes, int encodedBytes})
measureProviderRequestSize(ProviderRequest request) =>
    _measureRequestValue(encodeProviderRequest(request));

({int textBytes, int attachmentBytes, int encodedBytes}) _measureRequestValue(
  Object? value,
) {
  var rawBytes = 0;
  var encodedBytes = 0;
  var textBytes = 0;
  final pending = <Object?>[value];
  while (pending.isNotEmpty) {
    final value = pending.removeLast();
    if (value is ProviderBinaryEncoding) {
      final a = value.attachment;
      if (a.byteLength < 0 ||
          a.filename.isEmpty ||
          a.filename.contains(RegExp(r'[\x00-\x1f/\\]')) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(a.digest) ||
          !RegExp(r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$')
              .hasMatch(a.mediaType)) {
        throw const ProviderException(ProviderError.invalidRequest);
      }
      rawBytes += a.byteLength;
      encodedBytes += value.encodedLength;
      textBytes += 2;
    } else if (value is List) {
      textBytes += 2 + (value.isEmpty ? 0 : value.length - 1);
      pending.addAll(value);
    } else if (value is Map) {
      textBytes += 2 + (value.isEmpty ? 0 : value.length - 1);
      for (final entry in value.entries) {
        textBytes += utf8.encode(jsonEncode(entry.key)).length + 1;
        pending.add(entry.value);
      }
    } else {
      textBytes += utf8.encode(jsonEncode(value)).length;
    }
  }
  return (
    textBytes: textBytes,
    attachmentBytes: rawBytes,
    encodedBytes: encodedBytes,
  );
}

/// Streams JSON and base64 directly to the HTTP request with backpressure.
/// Attachment identity is checked as its bytes pass through the stream.
Stream<List<int>> encodeProviderRequestBody(
  ProviderRequest request, {
  required Future<void> abortSignal,
  required void Function() checkCancelled,
  void Function(int completed, int total)? onProgress,
}) async* {
  checkCancelled();
  final value = encodeProviderRequest(request);
  final size = _measureRequestValue(value);
  var completedBytes = 0;

  Stream<List<int>> binary(ProviderBinaryEncoding value) async* {
    yield utf8.encode('"${value.prefix}');
    final attachment = value.attachment;
    final digest = _DigestSink();
    final hash = sha256.startChunkedConversion(digest);
    var read = 0;
    final iterator = StreamIterator(attachment.openRead());
    final encoded = <String>[];
    final encoder = base64.encoder.startChunkedConversion(
      _StringSink(encoded.add),
    );
    try {
      while (await Future.any([
        iterator.moveNext(),
        abortSignal.then<bool>(
          (_) => throw const ProviderException(ProviderError.cancelled),
        ),
      ])) {
        checkCancelled();
        final chunk = iterator.current;
        read += chunk.length;
        if (read > attachment.byteLength) {
          throw const ProviderException(ProviderError.attachmentChanged);
        }
        hash.add(chunk);
        for (var offset = 0; offset < chunk.length; offset += 49152) {
          final end = (offset + 49152).clamp(0, chunk.length);
          encoder.add(chunk.sublist(offset, end));
          for (final text in encoded) {
            yield utf8.encode(text);
          }
          encoded.clear();
          completedBytes += end - offset;
          onProgress?.call(completedBytes, size.attachmentBytes);
          await Future<void>.delayed(Duration.zero);
          checkCancelled();
        }
      }
      hash.close();
      if (read != attachment.byteLength ||
          digest.value.toString() != attachment.digest) {
        throw const ProviderException(ProviderError.attachmentChanged);
      }
      encoder.close();
      for (final text in encoded) {
        yield utf8.encode(text);
      }
      yield const [34];
    } finally {
      await iterator.cancel();
    }
  }

  final pending = <Object?>[value];
  while (pending.isNotEmpty) {
    checkCancelled();
    final current = pending.removeLast();
    if (current is _JsonToken) {
      yield current.bytes;
    } else if (current is ProviderBinaryEncoding) {
      yield* binary(current);
    } else if (current is List) {
      yield const [91];
      pending.add(const _JsonToken([93]));
      for (var i = current.length - 1; i >= 0; i--) {
        pending.add(current[i]);
        if (i > 0) pending.add(const _JsonToken([44]));
      }
    } else if (current is Map) {
      yield const [123];
      pending.add(const _JsonToken([125]));
      final entries = current.entries.toList();
      for (var i = entries.length - 1; i >= 0; i--) {
        final entry = entries[i];
        pending.add(entry.value);
        pending.add(_JsonToken(utf8.encode('${jsonEncode(entry.key)}:')));
        if (i > 0) pending.add(const _JsonToken([44]));
      }
    } else {
      yield utf8.encode(jsonEncode(current));
    }
  }
  checkCancelled();
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

class _StringSink implements Sink<String> {
  _StringSink(this.write);
  final void Function(String) write;
  @override
  void add(String data) => write(data);
  @override
  void close() {}
}

class _JsonToken {
  const _JsonToken(this.bytes);
  final List<int> bytes;
}
