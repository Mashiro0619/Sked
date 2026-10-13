import 'dart:ui' as ui;

/// Replays the native accessibility bridge's incremental traversal tree.
///
/// Widget tests normally accept an orphaned OverlayPortal node silently. The
/// Windows AXTree rejects the whole update if a newly serialized node cannot
/// be reached from node 0, even when the widget's hit-test tree is intact.
class SemanticsUpdateAudit {
  final _nodes = <int, List<int>>{};
  final errors = <String>[];
  int updateCount = 0;

  void reset() {
    _nodes.clear();
    errors.clear();
    updateCount = 0;
  }

  ui.SemanticsUpdateBuilder createBuilder() => _AuditedSemanticsBuilder(this);

  void _record(Map<int, List<int>> updated) {
    updateCount++;
    _nodes.addAll(updated);
    final reachable = <int>{};
    void visit(int id) {
      if (!reachable.add(id)) return;
      final children = _nodes[id];
      if (children == null) {
        errors.add(
          'Update $updateCount: traversal references missing node $id',
        );
        return;
      }
      for (final child in children) {
        visit(child);
      }
    }

    visit(0);
    for (final id in updated.keys) {
      if (!reachable.contains(id)) {
        errors.add('Update $updateCount: node $id is not reachable from root');
      }
    }
    _nodes.removeWhere((id, _) => !reachable.contains(id));
  }
}

class _AuditedSemanticsBuilder implements ui.SemanticsUpdateBuilder {
  _AuditedSemanticsBuilder(this.audit);
  final SemanticsUpdateAudit audit;
  final _delegate = ui.SemanticsUpdateBuilder();
  final _updated = <int, List<int>>{};

  // Forward the complete SDK signature, including fields added in later SDKs.
  // Only traversal children are needed to check the native bridge contract.
  @override
  Object? noSuchMethod(Invocation invocation) {
    final arguments = invocation.namedArguments;
    if (invocation.memberName == #updateNode) {
      _updated[arguments[#id] as int] = List<int>.of(
        arguments[#childrenInTraversalOrder] as Iterable<int>,
      );
      return Function.apply(_delegate.updateNode, [], arguments);
    }
    if (invocation.memberName == #updateCustomAction) {
      return Function.apply(_delegate.updateCustomAction, [], arguments);
    }
    return super.noSuchMethod(invocation);
  }

  @override
  ui.SemanticsUpdate build() {
    audit._record(_updated);
    return _delegate.build();
  }
}
