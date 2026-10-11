import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';

/// Keeps asset reads inside the widget test zone while exercising real decoding.
void mockDefaultPeriodTimeAsset() {
  rootBundle.evict(defaultPeriodTimesAssetPath);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final source = encodePeriodTimesEnvelope(buildDefaultPeriodTimes());
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer.asUint8List());
    if (key != defaultPeriodTimesAssetPath) return null;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  });
  addTearDown(() {
    rootBundle.evict(defaultPeriodTimesAssetPath);
    messenger.setMockMessageHandler('flutter/assets', null);
  });
}
