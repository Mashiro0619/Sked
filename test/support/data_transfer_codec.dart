import 'dart:async';

import 'package:flutter/foundation.dart' show ComputeCallback;
import 'package:sked/services/data_transfer_codec.dart';

// Widget fakeAsync controls these futures. The codec's service tests exercise
// the production isolate boundary separately with the same pure callbacks.
const inlineDataTransferCodec = DataTransferCodec(run: _runInline);

Future<R> _runInline<M, R>(
  ComputeCallback<M, R> callback,
  M message, {
  String? debugLabel,
}) => Future<R>.sync(() => callback(message));
