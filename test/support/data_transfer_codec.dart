import 'dart:async';

import 'package:flutter/foundation.dart' show ComputeCallback;
import 'package:sked/services/data_transfer_codec.dart';

// Widget fakeAsync controls these futures. The codec's service tests exercise
// the production isolate boundary separately with the same pure callbacks.
const inlineDataTransferCodec = DataTransferCodec(
  run: runDataTransferInline,
  localTimeZoneIdResolver: noLocalTimeZoneId,
);

// Ordinary widget fixtures do not depend on a host's platform channel. Tests
// for native timezone discovery opt into the production resolver explicitly.
Future<String?> noLocalTimeZoneId() async => null;

Future<R> runDataTransferInline<M, R>(
  ComputeCallback<M, R> callback,
  M message, {
  String? debugLabel,
}) => Future<R>.sync(() => callback(message));
