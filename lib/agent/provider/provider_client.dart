import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'provider_models.dart';
import 'provider_protocol.dart';
import 'provider_request_encoder.dart';
import 'sse_decoder.dart';

/// API keys are transient arguments and only enter the Authorization header.
/// The adapter never executes tools and never retries an uncertain request.
class ProviderClient {
  ProviderClient({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  Future<ProviderResponse> collect(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async {
    ProviderResponse? result;
    await for (final event in stream(
      request,
      apiKey: apiKey,
      cancellation: cancellation,
    )) {
      if (event is ProviderCompleted) result = event.response;
    }
    if (result == null) {
      throw const ProviderException(ProviderError.incompleteResponse);
    }
    return result;
  }

  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    final stopped = Completer<ProviderException>();
    final aborted = Completer<void>();
    Timer? totalTimer;
    Timer? idleTimer;
    var finished = false;
    var subscriptionCancelled = false;
    StreamIterator<List<int>>? iterator;
    late StreamController<ProviderEvent> controller;

    void stop(ProviderError error) {
      if (finished) return;
      if (!stopped.isCompleted) stopped.complete(ProviderException(error));
      if (!aborted.isCompleted) aborted.complete();
    }

    void resetIdle() {
      idleTimer?.cancel();
      idleTimer = Timer(
        request.limits.idleTimeout,
        () => stop(ProviderError.timeout),
      );
    }

    Future<T> guarded<T>(Future<T> work) =>
        Future.any([work, stopped.future.then<T>((error) => throw error)]);

    Future<void> pump() async {
      ProviderResponseDecoder? decoder;
      ProviderUsage? emittedUsage;
      final diagnostic = _ResponseDiagnostic();
      void emit(ProviderEvent event) {
        if (subscriptionCancelled) return;
        if (event is ProviderUsageEvent) emittedUsage = event.usage;
        controller.add(event);
      }

      try {
        _validate(request, apiKey);
        if (cancellation?.isCancelled ?? false) {
          throw const ProviderException(ProviderError.cancelled);
        }
        totalTimer = Timer(
          request.limits.totalTimeout,
          () => stop(ProviderError.timeout),
        );
        if (cancellation != null) {
          unawaited(
            cancellation.whenCancelled.then(
              (_) => stop(ProviderError.cancelled),
            ),
          );
        }
        void checkEncoding() {
          if (stopped.isCompleted || (cancellation?.isCancelled ?? false)) {
            throw const ProviderException(ProviderError.cancelled);
          }
        }

        final body = await guarded(
          encodeProviderRequestBody(
            request,
            abortSignal: aborted.future,
            checkCancelled: checkEncoding,
            onProgress: (completed, total) {
              if (!subscriptionCancelled) {
                controller.add(
                  ProviderUploadProgress(
                    ProviderUploadPhase.encoding,
                    completedBytes: completed,
                    totalBytes: total,
                  ),
                );
              }
            },
          ),
        );
        checkEncoding();
        resetIdle();
        final hasAttachments = request.messages.any(
          (message) => message.attachments.isNotEmpty,
        );
        if (hasAttachments && !subscriptionCancelled) {
          controller.add(
            ProviderUploadProgress(
              ProviderUploadPhase.sending,
              completedBytes: 0,
              totalBytes: body.length,
            ),
          );
        }
        final wire =
            http.AbortableRequest(
                'POST',
                request.endpoint,
                abortTrigger: aborted.future,
              )
              ..followRedirects = false
              ..maxRedirects = 0
              ..headers.addAll({
                'Content-Type': 'application/json',
                'Accept': 'text/event-stream, application/json',
                if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
              })
              ..bodyBytes = body;
        final response = await guarded(
          _client.send(wire).then((response) {
            if (stopped.isCompleted) {
              unawaited(response.stream.listen(null).cancel());
              throw const ProviderException(ProviderError.cancelled);
            }
            return response;
          }),
        );
        iterator = StreamIterator(response.stream);
        final contentType = response.headers['content-type']
            ?.split(';')
            .first
            .trim()
            .toLowerCase();
        final isJson = contentType == 'application/json';
        final rejected =
            response.statusCode < 200 || response.statusCode >= 300;
        if (rejected || (!isJson && contentType != 'text/event-stream')) {
          final errorBytes = <int>[];
          final limit = request.limits.maxResponseBytes.clamp(1, 32768);
          try {
            while (errorBytes.length < limit &&
                await guarded(iterator!.moveNext())) {
              resetIdle();
              errorBytes.addAll(
                iterator!.current.take(limit - errorBytes.length),
              );
            }
          } catch (_) {
            if (stopped.isCompleted) {
              final reason = await stopped.future;
              if (reason.code != ProviderError.timeout) throw reason;
            }
            if (cancellation?.isCancelled ?? false) {
              throw const ProviderException(ProviderError.cancelled);
            }
            // Diagnostic reads can time out after a known HTTP rejection.
            // Retain its status and any complete message already received.
          }
          Object? errorBody;
          final rawBody = utf8.decode(errorBytes, allowMalformed: true);
          final text = rawBody.trim();
          try {
            errorBody = jsonDecode(text);
          } on FormatException {
            final contentType = response.headers['content-type']
                ?.split(';')
                .first
                .trim()
                .toLowerCase();
            if ((contentType == null ||
                    contentType.isEmpty ||
                    contentType == 'text/plain') &&
                !text.startsWith('<') &&
                !text.startsWith('{') &&
                !text.startsWith('[')) {
              errorBody = text;
            }
          }
          throw ProviderException.fromResponse(
            !rejected
                ? ProviderError.invalidResponse
                : switch (response.statusCode) {
                    >= 300 && < 400 => ProviderError.redirectRejected,
                    401 || 403 => ProviderError.authentication,
                    429 => ProviderError.rateLimited,
                    _ => ProviderError.httpFailure,
                  },
            errorBody,
            statusCode: rejected ? response.statusCode : null,
            apiKey: apiKey,
          ).withResponseBody(
            rawBody,
            apiKey: apiKey,
            truncatedEnd: errorBytes.length >= limit,
          );
        }
        if (hasAttachments && !subscriptionCancelled) {
          controller.add(
            ProviderUploadProgress(
              ProviderUploadPhase.accepted,
              completedBytes: body.length,
              totalBytes: body.length,
            ),
          );
        }
        if ((response.contentLength ?? 0) > request.limits.maxResponseBytes) {
          throw const ProviderException(ProviderError.responseBudgetExceeded);
        }
        decoder = ProviderResponseDecoder(request, apiKey: apiKey);
        final sse = ProviderSseDecoder(
          maxEventBytes: request.limits.maxEventBytes,
        );
        final jsonBytes = <int>[];
        var bytes = 0;
        resetIdle();
        while (await guarded(iterator!.moveNext())) {
          resetIdle();
          final chunk = iterator!.current;
          diagnostic.add(chunk);
          bytes += chunk.length;
          if (bytes > request.limits.maxResponseBytes) {
            throw const ProviderException(ProviderError.responseBudgetExceeded);
          }
          if (isJson) {
            jsonBytes.addAll(chunk);
          } else {
            for (final frame in sse.add(chunk)) {
              for (final event in decoder.add(frame)) {
                emit(event);
              }
              if (decoder.isComplete) break;
            }
          }
          if (decoder.isComplete) break;
        }
        if (isJson) {
          final value = jsonDecode(utf8.decode(jsonBytes));
          if (value is! Map<String, dynamic>) {
            throw const ProviderException(ProviderError.invalidResponse);
          }
          for (final event in decoder.addJson(value)) {
            emit(event);
          }
        }
        if (!decoder.isComplete) {
          throw const ProviderException(ProviderError.incompleteResponse);
        }
      } catch (error) {
        if (!subscriptionCancelled) {
          final safe = error is ProviderException
              ? error
              : stopped.isCompleted
              ? await stopped.future
              : error is FormatException
              ? const ProviderException(ProviderError.invalidResponse)
              : const ProviderException(ProviderError.transportFailure);
          final usage = decoder?.reportedUsage;
          if (usage != null && !identical(usage, emittedUsage)) {
            // add()/addJson() may fail after reading usage but before returning
            // their event list. Deliver that evidence before the error event.
            emit(ProviderUsageEvent(usage));
          }
          final terminal = decoder?.hasTerminalResponse == true;
          // Do not attach the original stack: clients may put request secrets
          // or URLs into exception messages and async stack annotations.
          controller.addError(
            safe.code == ProviderError.cancelled
                ? safe
                : safe.withResponseBody(
                    diagnostic.text,
                    apiKey: apiKey,
                    truncated: diagnostic.truncated,
                    responseTerminated: terminal,
                  ),
            StackTrace.empty,
          );
        }
      } finally {
        finished = true;
        totalTimer?.cancel();
        idleTimer?.cancel();
        if (!aborted.isCompleted) aborted.complete();
        unawaited(iterator?.cancel());
        unawaited(controller.close());
      }
    }

    controller = StreamController<ProviderEvent>(
      onListen: () => unawaited(pump()),
      onCancel: () {
        subscriptionCancelled = true;
        stop(ProviderError.cancelled);
        unawaited(iterator?.cancel());
      },
    );
    return controller.stream;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

/// Keep the failing end of a stream even after a long successful prefix.
class _ResponseDiagnostic {
  static const limit = 32768;
  final _bytes = <int>[];
  bool truncated = false;

  void add(List<int> chunk) {
    final overflow = _bytes.length + chunk.length - limit;
    if (overflow > 0) {
      truncated = true;
      _bytes.removeRange(0, overflow.clamp(0, _bytes.length));
    }
    _bytes.addAll(chunk.skip((chunk.length - limit).clamp(0, chunk.length)));
  }

  String get text => utf8.decode(_bytes, allowMalformed: true);
}

void _validate(ProviderRequest request, String apiKey) {
  if (request.reasoningEffort != null &&
      !const {
        'none',
        'minimal',
        'low',
        'medium',
        'high',
        'xhigh',
        'max',
      }.contains(request.reasoningEffort)) {
    throw const ProviderException(ProviderError.invalidRequest);
  }
  final uri = request.endpoint;
  if (!uri.isAbsolute ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      request.model.trim().isEmpty ||
      request.messages.isEmpty ||
      apiKey.contains('\r') ||
      apiKey.contains('\n')) {
    throw const ProviderException(ProviderError.invalidRequest);
  }
  if (uri.scheme == 'http' && !request.allowInsecureHttp) {
    throw const ProviderException(ProviderError.insecureEndpoint);
  }
  final limits = request.limits;
  if (limits.totalTimeout <= Duration.zero ||
      limits.idleTimeout <= Duration.zero ||
      [
        limits.maxRequestBytes,
        limits.maxAttachmentBytes,
        limits.maxResponseBytes,
        limits.maxEventBytes,
        limits.maxToolArgumentBytes,
        limits.maxToolCalls,
        limits.maxOutputTokens,
        limits.maxTotalTokens,
      ].any((value) => value <= 0)) {
    throw const ProviderException(ProviderError.invalidRequest);
  }
}
