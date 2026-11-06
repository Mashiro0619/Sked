import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  int measure(Object? value) {
    if (value is ProviderBinaryEncoding) {
      final a = value.attachment;
      if (a.byteLength < 0 ||
          a.filename.isEmpty ||
          a.filename.length > 256 ||
          a.filename.contains(RegExp(r'[\x00-\x1f/\\]')) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(a.digest) ||
          !RegExp(r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$')
              .hasMatch(a.mediaType)) {
        throw const ProviderException(ProviderError.invalidRequest);
      }
      rawBytes += a.byteLength;
      encodedBytes += value.encodedLength;
      return 2;
    }
    if (value is List) {
      return 2 +
          (value.isEmpty ? 0 : value.length - 1) +
          value.fold<int>(0, (sum, item) => sum + measure(item));
    }
    if (value is Map) {
      return 2 +
          (value.isEmpty ? 0 : value.length - 1) +
          value.entries.fold<int>(
            0,
            (sum, entry) =>
                sum +
                utf8.encode(jsonEncode(entry.key)).length +
                1 +
                measure(entry.value),
          );
    }
    return utf8.encode(jsonEncode(value)).length;
  }

  final textBytes = measure(value);
  return (
    textBytes: textBytes,
    attachmentBytes: rawBytes,
    encodedBytes: encodedBytes,
  );
}

/// Encodes cooperatively, keeping text and binary budgets separate. No bytes
/// reach HTTP until every attachment's actual length and digest are verified.
Future<Uint8List> encodeProviderRequestBody(
  ProviderRequest request, {
  required Future<void> abortSignal,
  required void Function() checkCancelled,
  void Function(int completed, int total)? onProgress,
}) async {
  checkCancelled();
  final value = encodeProviderRequest(request);
  final size = _measureRequestValue(value);
  if (size.textBytes > request.limits.maxRequestBytes ||
      size.attachmentBytes > request.limits.maxAttachmentBytes) {
    throw const ProviderException(ProviderError.requestBudgetExceeded);
  }
  final expectedBytes = size.textBytes + size.encodedBytes;
  final output = BytesBuilder(copy: false);
  var completedBytes = 0;
  void append(String text) {
    checkCancelled();
    final bytes = utf8.encode(text);
    if (output.length + bytes.length > expectedBytes) {
      throw const ProviderException(ProviderError.requestBudgetExceeded);
    }
    output.add(bytes);
  }

  Future<void> binary(ProviderBinaryEncoding value) async {
    append('"${value.prefix}');
    final attachment = value.attachment;
    final digest = _DigestSink();
    final hash = sha256.startChunkedConversion(digest);
    var read = 0;
    final iterator = StreamIterator(attachment.openRead());
    final strings = _StringSink(append);
    final encoder = base64.encoder.startChunkedConversion(strings);
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
        // Bound a platform's large chunk before encoding so Stop can be handled
        // even when the picker/browser produced a single large byte buffer.
        for (var offset = 0; offset < chunk.length; offset += 49152) {
          final end = offset + 49152 < chunk.length
              ? offset + 49152
              : chunk.length;
          encoder.add(chunk.sublist(offset, end));
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
      append('"');
    } finally {
      await iterator.cancel();
    }
  }

  Future<void> encode(Object? value) async {
    checkCancelled();
    if (value is ProviderBinaryEncoding) {
      await binary(value);
      return;
    }
    if (value is List) {
      append('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) append(',');
        await encode(value[i]);
      }
      append(']');
    } else if (value is Map) {
      append('{');
      var first = true;
      for (final entry in value.entries) {
        if (!first) append(',');
        first = false;
        append('${jsonEncode(entry.key)}:');
        await encode(entry.value);
      }
      append('}');
    } else {
      append(jsonEncode(value));
    }
  }

  await encode(value);
  checkCancelled();
  if (output.length != expectedBytes) {
    throw const ProviderException(ProviderError.attachmentChanged);
  }
  return output.takeBytes();
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
