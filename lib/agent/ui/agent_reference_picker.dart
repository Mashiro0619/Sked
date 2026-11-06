import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../references/agent_composer_reference.dart';

class AgentReferenceChoice {
  AgentReferenceChoice({
    required this.label,
    required this.detail,
    required this.type,
    required this.value,
    this.enabled = true,
  }) : _referenceJson = jsonEncode(value.toJson());

  /// Stable identity across the resource types shown in the same picker.
  String get key => value.stableKey;
  final String label;
  final String detail;
  final String type;
  final AgentComposerReference value;
  final bool enabled;
  final String _referenceJson;

  @override
  bool operator ==(Object other) =>
      other is AgentReferenceChoice &&
      other._referenceJson == _referenceJson &&
      other.label == label &&
      other.detail == detail &&
      other.type == type &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(_referenceJson, label, detail, type, enabled);
}

class AgentReferenceSearchResult {
  AgentReferenceSearchResult({
    required Iterable<AgentReferenceChoice> choices,
    this.hasMore = false,
  }) : choices = List.unmodifiable(choices);

  final List<AgentReferenceChoice> choices;
  final bool hasMore;
}

/// Displays search state supplied by the composer without owning its editor.
class AgentReferencePicker extends StatefulWidget {
  const AgentReferencePicker({
    super.key,
    required this.query,
    required this.result,
    required this.onSelect,
    required this.onDismiss,
    this.onLoadMore,
    this.onRetry,
    this.loading = false,
    this.error = false,
    this.enabled = true,
    this.progressLabel,
  });

  final String query;
  final AgentReferenceSearchResult result;
  final bool loading;
  final bool error;
  final bool enabled;
  final String? progressLabel;
  final Future<void> Function(AgentReferenceChoice) onSelect;
  final Future<void> Function()? onLoadMore;
  final Future<void> Function()? onRetry;
  final VoidCallback onDismiss;

  @override
  State<AgentReferencePicker> createState() => _AgentReferencePickerState();
}

class _AgentReferencePickerState extends State<AgentReferencePicker> {
  var _generation = 0;
  Object? _pending;
  var _failed = false;

  bool get _interactive =>
      widget.enabled && !widget.loading && _pending == null;

  @override
  void didUpdateWidget(AgentReferencePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.loading != widget.loading ||
        oldWidget.error != widget.error ||
        oldWidget.result.hasMore != widget.result.hasMore ||
        !listEquals(oldWidget.result.choices, widget.result.choices)) {
      _generation++;
      _pending = null;
      _failed = false;
    }
  }

  Future<void> _perform(int generation, Future<void> Function() action) async {
    if (!mounted || generation != _generation || !_interactive) return;
    final pending = Object();
    setState(() {
      _pending = pending;
      _failed = false;
    });
    var failed = false;
    try {
      await action();
    } catch (_) {
      failed = true;
    }
    if (!mounted ||
        generation != _generation ||
        !identical(_pending, pending)) {
      return;
    }
    setState(() {
      _pending = null;
      _failed = failed;
    });
  }

  void _dismiss(int generation) {
    if (!mounted || generation != _generation || !widget.enabled) return;
    setState(() {
      _generation++;
      _pending = null;
      _failed = false;
    });
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final generation = _generation;
    final failed = widget.error || _failed;
    final progressLabel = widget.progressLabel ?? l.agentReferenceLoading;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = math.min(
          320.0,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.45,
        );
        return Card.filled(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ListView(
              key: const ValueKey('agent-reference-results'),
              primary: false,
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          label: '${l.agentReferenceSearch} ${widget.query}',
                          child: ExcludeSemantics(
                            child: Text(l.agentReferenceSearch),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('agent-reference-dismiss'),
                        tooltip: material.closeButtonTooltip,
                        onPressed: widget.enabled
                            ? () => _dismiss(generation)
                            : null,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (widget.loading || _pending != null) ...[
                  LinearProgressIndicator(
                    key: const ValueKey('agent-reference-loading'),
                    semanticsLabel: progressLabel,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(progressLabel),
                    ),
                  ),
                ],
                if (failed)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        l.agentReferenceFailed,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (failed && widget.onRetry != null)
                  TextButton(
                    key: const ValueKey('agent-reference-retry'),
                    onPressed: _interactive
                        ? () => _perform(generation, widget.onRetry!)
                        : null,
                    child: Text(l.agentRetry),
                  ),
                if (!widget.loading && !failed && widget.result.choices.isEmpty)
                  Padding(
                    key: const ValueKey('agent-reference-empty'),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off),
                        const SizedBox(width: 8),
                        Flexible(child: Text(l.agentReferenceEmpty)),
                      ],
                    ),
                  ),
                for (final choice in widget.result.choices)
                  ListTile(
                    key: ValueKey('agent-reference-choice-${choice.key}'),
                    enabled: _interactive && choice.enabled,
                    title: Text(choice.label),
                    subtitle: _detail(choice),
                    onTap: _interactive && choice.enabled
                        ? () => _perform(
                            generation,
                            () => widget.onSelect(choice),
                          )
                        : null,
                  ),
                if (widget.result.hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextButton(
                      key: const ValueKey('agent-reference-more'),
                      onPressed: _interactive && widget.onLoadMore != null
                          ? () => _perform(generation, widget.onLoadMore!)
                          : null,
                      child: Text(l.more),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _detail(AgentReferenceChoice choice) {
    final parts = [
      if (choice.type.isNotEmpty) choice.type,
      if (choice.detail.isNotEmpty) choice.detail,
    ];
    return parts.isEmpty ? null : Text(parts.join('\n'));
  }
}

class AgentReferenceChips extends StatefulWidget {
  const AgentReferenceChips({
    super.key,
    required this.choices,
    this.onRemove,
    this.enabled = true,
  });

  final List<AgentReferenceChoice> choices;
  final bool enabled;
  final Future<void> Function(AgentReferenceChoice)? onRemove;

  @override
  State<AgentReferenceChips> createState() => _AgentReferenceChipsState();
}

class _AgentReferenceChipsState extends State<AgentReferenceChips> {
  var _generation = 0;
  final _pending = <String, Object>{};
  var _failed = false;

  @override
  void didUpdateWidget(AgentReferenceChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        (oldWidget.onRemove == null) != (widget.onRemove == null) ||
        !listEquals(oldWidget.choices, widget.choices)) {
      _generation++;
      _pending.clear();
      _failed = false;
    }
  }

  Future<void> _remove(int generation, AgentReferenceChoice choice) async {
    if (!mounted ||
        generation != _generation ||
        !widget.enabled ||
        widget.onRemove == null ||
        _pending.containsKey(choice.key)) {
      return;
    }
    final pending = Object();
    setState(() {
      _pending[choice.key] = pending;
      _failed = false;
    });
    var failed = false;
    try {
      await widget.onRemove!(choice);
    } catch (_) {
      failed = true;
    }
    if (!mounted ||
        generation != _generation ||
        !identical(_pending[choice.key], pending)) {
      return;
    }
    setState(() {
      _pending.remove(choice.key);
      _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    final l = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in widget.choices)
                  Tooltip(
                    message: [
                      choice.label,
                      choice.type,
                      choice.detail,
                    ].where((part) => part.isNotEmpty).join('\n'),
                    child: InputChip(
                      key: ValueKey('agent-reference-chip-${choice.key}'),
                      isEnabled:
                          widget.enabled && !_pending.containsKey(choice.key),
                      label: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.max(0, availableWidth - 80),
                        ),
                        child: Text(
                          choice.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close),
                      deleteButtonTooltipMessage: l.agentReferenceRemove,
                      onDeleted:
                          widget.enabled &&
                              widget.onRemove != null &&
                              !_pending.containsKey(choice.key)
                          ? () => _remove(generation, choice)
                          : null,
                    ),
                  ),
              ],
            ),
            if (_pending.isNotEmpty)
              Semantics(liveRegion: true, child: Text(l.agentSaving)),
            if (_failed)
              Semantics(
                liveRegion: true,
                child: Text(
                  l.agentOperationFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
  }
}
