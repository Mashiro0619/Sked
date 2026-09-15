import 'dart:convert';

/// Acceptance by the scheduler is not evidence that the OS displayed a card.
/// Pending also represents an interrupted/ambiguous platform call. Only a
/// proven pre-submission rejection may be retried automatically after due time.
enum AgendaNotificationRegistrationState { pending, accepted, rejected }

enum AgendaNotificationRegistrationKind { normal, lateRecovery, snooze }

class AgendaNotificationRegistration {
  const AgendaNotificationRegistration({
    required this.key,
    required this.originalFireAt,
    required this.fireAt,
    required this.state,
    required this.kind,
    required this.recordedAt,
    this.notificationId,
  });

  final String key;
  final DateTime originalFireAt;
  final DateTime fireAt;
  final DateTime recordedAt;
  final AgendaNotificationRegistrationState state;
  final AgendaNotificationRegistrationKind kind;
  final int? notificationId;

  /// Generation is supplied by the store namespace, not by user data.
  String get identity => identityFor(key, originalFireAt);
  static String identityFor(String key, DateTime originalFireAt) =>
      jsonEncode([key, originalFireAt.toUtc().microsecondsSinceEpoch]);
  static const retention = Duration(days: 2);
  DateTime get expiresAt =>
      (fireAt.isAfter(originalFireAt) ? fireAt : originalFireAt).add(retention);

  AgendaNotificationRegistration copyWith({
    AgendaNotificationRegistrationState? state,
    int? notificationId,
  }) => AgendaNotificationRegistration(
    key: key,
    originalFireAt: originalFireAt,
    fireAt: fireAt,
    recordedAt: recordedAt,
    state: state ?? this.state,
    kind: kind,
    notificationId: notificationId ?? this.notificationId,
  );

  Map<String, Object?> toJson() => {
    'v': 1,
    'key': key,
    'originalFireAt': originalFireAt.toUtc().toIso8601String(),
    'fireAt': fireAt.toUtc().toIso8601String(),
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'state': state.name,
    'kind': kind.name,
    if (notificationId != null) 'notificationId': notificationId,
  };

  static AgendaNotificationRegistration? tryDecode(Object? value) {
    if (value is! Map || value['v'] != 1) return null;
    final key = value['key'];
    final original = _date(value['originalFireAt']);
    final fireAt = _date(value['fireAt']);
    final recordedAt = _date(value['recordedAt']);
    final state = _named(
      AgendaNotificationRegistrationState.values,
      value['state'],
    );
    final kind = _named(
      AgendaNotificationRegistrationKind.values,
      value['kind'],
    );
    final id = value['notificationId'];
    if (key is! String ||
        key.trim().isEmpty ||
        key.length > 1024 ||
        original == null ||
        fireAt == null ||
        recordedAt == null ||
        state == null ||
        kind == null ||
        !_validId(id)) {
      return null;
    }
    return AgendaNotificationRegistration(
      key: key,
      originalFireAt: original,
      fireAt: fireAt,
      recordedAt: recordedAt,
      state: state,
      kind: kind,
      notificationId: id as int?,
    );
  }
}

/// A receipt for a single user action on a specific notification card. Its
/// fixed target survives retries, process restarts, and the original snooze
/// expiring. A later card has a different identity and can be snoozed again.
class AgendaNotificationSnoozeReceipt {
  const AgendaNotificationSnoozeReceipt({
    required this.actionIdentity,
    required this.fireAt,
  });
  final String actionIdentity;
  final DateTime fireAt;
  DateTime get expiresAt =>
      fireAt.add(AgendaNotificationRegistration.retention);
  Map<String, Object?> toJson() => {
    'v': 1,
    'actionIdentity': actionIdentity,
    'fireAt': fireAt.toUtc().toIso8601String(),
  };
  static AgendaNotificationSnoozeReceipt? tryDecode(Object? value) {
    if (value is! Map || value['v'] != 1) return null;
    final id = value['actionIdentity'];
    final at = _date(value['fireAt']);
    if (id is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(id) ||
        at == null) {
      return null;
    }
    return AgendaNotificationSnoozeReceipt(actionIdentity: id, fireAt: at);
  }
}

class AgendaNotificationRegistrationSnapshot {
  const AgendaNotificationRegistrationSnapshot({
    this.initializedAt,
    this.records = const {},
    this.snoozeReceipts = const {},
  });

  /// No evidence before this first migration boundary means unknown history,
  /// not permission to replay an old reminder.
  final DateTime? initializedAt;
  final Map<String, AgendaNotificationRegistration> records;
  final Map<String, AgendaNotificationSnoozeReceipt> snoozeReceipts;
  AgendaNotificationRegistration? forReminder(String key, DateTime original) =>
      records[AgendaNotificationRegistration.identityFor(key, original)];
}

class AgendaNotificationRegistrationDiagnostic {
  const AgendaNotificationRegistrationDiagnostic({
    required this.key,
    required this.originalFireAt,
    required this.reason,
    this.fireAt,
    this.state,
    this.notificationId,
  });
  final String key;
  final DateTime originalFireAt;
  final DateTime? fireAt;
  final String reason;
  final AgendaNotificationRegistrationState? state;
  final int? notificationId;
  Map<String, Object?> toJson() => {
    'key': key,
    'originalFireAt': originalFireAt.toUtc().toIso8601String(),
    'reason': reason,
    if (fireAt != null) 'fireAt': fireAt!.toUtc().toIso8601String(),
    if (state != null) 'state': state!.name,
    if (notificationId != null) 'notificationId': notificationId,
    'displayed': 'unknown',
  };
  static AgendaNotificationRegistrationDiagnostic? tryDecode(Object? value) {
    if (value is! Map) return null;
    final key = value['key'];
    final original = _date(value['originalFireAt']);
    final fire = _date(value['fireAt']);
    final reason = value['reason'];
    final state = _named(
      AgendaNotificationRegistrationState.values,
      value['state'],
    );
    final id = value['notificationId'];
    if (key is! String ||
        key.isEmpty ||
        key.length > 1024 ||
        original == null ||
        reason is! String ||
        reason.isEmpty ||
        reason.length > 128 ||
        (value['fireAt'] != null && fire == null) ||
        (value['state'] != null && state == null) ||
        !_validId(id)) {
      return null;
    }
    return AgendaNotificationRegistrationDiagnostic(
      key: key,
      originalFireAt: original,
      reason: reason,
      fireAt: fire,
      state: state,
      notificationId: id as int?,
    );
  }
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
T? _named<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

bool _validId(Object? id) =>
    id == null || (id is int && id > 0 && id <= 0x7fffffff);
