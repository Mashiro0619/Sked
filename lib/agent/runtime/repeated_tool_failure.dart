import '../../application/mutation_coordinator.dart' show mutationDigest;
import '../../application/operation_contracts.dart';
import '../provider/provider_models.dart';

/// A run-local guard for repeated, known argument/capability failures.
/// Successful calls and genuinely different attempts start a new sequence.
class RepeatedToolFailureTracker {
  String? _fingerprint;
  int _count = 0;

  int record(ProviderToolCall call, Object? failure) {
    if (failure is! OperationProblem ||
        !const {
          OperationErrorCode.invalidArgument,
          OperationErrorCode.notFound,
          OperationErrorCode.unsupported,
        }.contains(failure.code)) {
      _reset();
      return 0;
    }
    String fingerprint;
    try {
      fingerprint = mutationDigest({
        'tool': call.name,
        'arguments': call.decodedArguments,
        'code': failure.code.name,
        'field': failure.field,
      });
    } on OperationProblem {
      // Deep inputs still keep their original tool failure and paired result.
      _reset();
      return 0;
    } on ProviderException {
      _reset();
      return 0;
    } on FormatException {
      _reset();
      return 0;
    }
    _count = _fingerprint == fingerprint ? _count + 1 : 1;
    _fingerprint = fingerprint;
    return _count;
  }

  void _reset() {
    _fingerprint = null;
    _count = 0;
  }
}
