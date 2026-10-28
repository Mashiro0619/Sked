import 'dart:async';

/// Serializes workspace availability, mode switches and durable date changes.
///
/// A command may first flush UI state or ask its editor to finish. Only its
/// commit phase blocks ordinary saves, so those preparations cannot deadlock
/// behind the transaction they are preparing. No application data lives here.
class WorkspaceTransactions {
  WorkspaceTransactions({this._onBoundary});

  final void Function()? _onBoundary;
  WorkspaceTransaction? _activeTransaction;
  WorkspaceCommit? _activeCommit;

  bool get isIdle => _activeTransaction == null && _activeCommit == null;

  Future<void> run(
    Future<void> Function(WorkspaceTransaction transaction) command,
  ) async {
    _onBoundary?.call();
    while (_activeTransaction != null) {
      await _activeTransaction!._completed.future;
    }
    final transaction = WorkspaceTransaction._(this);
    _activeTransaction = transaction;
    try {
      await command(transaction);
    } finally {
      _onBoundary?.call();
      _activeTransaction = null;
      // A later command observes the settled state without inheriting a
      // failure that belongs to the caller of this command.
      transaction._completed.complete();
    }
  }

  /// Returns null when a save can start synchronously. That matters when a
  /// backup restore reserves a new data session immediately after the save.
  /// Only the live commit lease can bypass its own barrier.
  Future<void>? waitBeforeSave({WorkspaceCommit? commit}) {
    if (commit != null) {
      if (!identical(commit, _activeCommit)) {
        throw StateError('The workspace commit is no longer active.');
      }
      return null;
    }
    return _activeCommit == null ? null : _waitForCommits();
  }

  Future<void> _waitForCommits() async {
    while (_activeCommit != null) {
      await _activeCommit!._completed.future;
    }
  }

  Future<void> _commit(
    WorkspaceTransaction transaction,
    Future<void> Function(WorkspaceCommit commit) operation,
  ) async {
    if (!identical(transaction, _activeTransaction) || _activeCommit != null) {
      throw StateError('The workspace transaction cannot begin a commit.');
    }
    final commit = WorkspaceCommit._();
    _activeCommit = commit;
    try {
      await operation(commit);
    } finally {
      _activeCommit = null;
      commit._completed.complete();
    }
  }
}

/// A queued command's lease. It cannot start a commit after the command ends.
class WorkspaceTransaction {
  WorkspaceTransaction._(this._owner);

  final WorkspaceTransactions _owner;
  final _completed = Completer<void>();

  Future<void> commit(
    Future<void> Function(WorkspaceCommit commit) operation,
  ) => _owner._commit(this, operation);
}

/// Allows the transaction's own save through its active persistence barrier.
class WorkspaceCommit {
  WorkspaceCommit._();

  final _completed = Completer<void>();
}
