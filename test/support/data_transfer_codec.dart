import 'dart:async';

import 'package:flutter/foundation.dart' show ComputeCallback;
import 'package:sked/services/data_transfer_codec.dart';

// Widget fakeAsync controls these futures. The codec's service tests exercise
// the production isolate boundary separately with the same pure callbacks.
const inlineDataTransferCodec = DataTransferCodec(run: runDataTransferInline);

Future<R> runDataTransferInline<M, R>(
  ComputeCallback<M, R> callback,
  M message, {
  String? debugLabel,
}) => Future<R>.sync(() => callback(message));
