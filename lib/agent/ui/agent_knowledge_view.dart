import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../utils/unique_id.dart';
import '../../widgets/expressive_dialog.dart';
import '../../widgets/expressive_empty_state.dart';
import '../../widgets/sked_expressive_loading_indicator.dart';
import '../../widgets/settings_list.dart';
import '../../widgets/settings_page_header.dart';
import '../../widgets/sked_task_session.dart';
import '../../widgets/sked_dropdown_menu.dart';
import '../knowledge/knowledge_service.dart';
import 'agent_settings_exit_guard.dart';

enum _KnowledgeOrigin { all, builtIn, custom, modified }

enum _KnowledgeState { all, enabled, disabled, missingTools }

class AgentKnowledgeView extends StatefulWidget {
  const AgentKnowledgeView({
    super.key,
    required this.service,
    required this.kind,
    this.pageEditor = false,
    this.headerSliver,
  });
  final AgentKnowledgeService service;
  final KnowledgeKind kind;
  final bool pageEditor;
  final Widget? headerSliver;
  @override
  State<AgentKnowledgeView> createState() => _AgentKnowledgeViewState();
}

class _AgentKnowledgeViewState extends State<AgentKnowledgeView> {
  final _search = TextEditingController();
  final _uiSessions = <SkedTaskSession>{};
  bool _loading = true, _failed = false;
  bool _routeCurrent = false;
  int _interactionGeneration = 0;
  Object? _loadRequest;
  Object? _openRequest;
  SkedTaskSession? _readSession;
  _KnowledgeOrigin _origin = _KnowledgeOrigin.all;
  _KnowledgeState _state = _KnowledgeState.all;

  bool get _opening => _openRequest != null;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent == true;
    if (_routeCurrent && !current) _interactionGeneration++;
    _routeCurrent = current;
    _checkUiSessions();
  }

  @override
  void didUpdateWidget(AgentKnowledgeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.kind != widget.kind ||
        oldWidget.pageEditor != widget.pageEditor) {
      _interactionGeneration++;
      _checkUiSessions();
      if (oldWidget.kind != widget.kind) {
        _origin = _KnowledgeOrigin.all;
        _state = _KnowledgeState.all;
      }
      if (oldWidget.service != widget.service) unawaited(_load());
    }
  }

  void _checkUiSessions() {
    for (final session in _uiSessions.toList()) {
      session.check();
    }
    final read = _readSession;
    if (read != null && !read.isCurrent) {
      // A local read may not be cancellable. Retire its UI request now so a
      // returned page can open another record before the old read completes.
      _readSession = null;
      _openRequest = null;
      _retireUiSession(read);
    }
  }

  SkedTaskSession _createUiSession() {
    final service = widget.service;
    final kind = widget.kind;
    final pageEditor = widget.pageEditor;
    final route = ModalRoute.of(context);
    final generation = _interactionGeneration;
    final session = SkedTaskSession(
      ownerRoute: route,
      isOwnerActive: () => mounted && route?.isCurrent == true,
      isTargetCurrent: () =>
          mounted &&
          generation == _interactionGeneration &&
          identical(widget.service, service) &&
          widget.kind == kind &&
          widget.pageEditor == pageEditor,
    );
    _uiSessions.add(session);
    return session;
  }

  void _retireUiSession(SkedTaskSession session) {
    _uiSessions.remove(session);
    session.dispose();
  }

  void _showFeedback(String message, {String? undoOperationId}) {
    final session = _createUiSession();
    if (!session.isCurrent) {
      _retireUiSession(session);
      return;
    }
    final l = AppLocalizations.of(context);
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: undoOperationId == null
            ? null
            : SnackBarAction(
                label: l.agentKnowledgeUndo,
                onPressed: () {
                  if (session.isCurrent) unawaited(_undo(undoOperationId));
                },
              ),
      ),
    );
    unawaited(controller.closed.then<void>((_) => _retireUiSession(session)));
  }

  @override
  void dispose() {
    for (final session in _uiSessions.toList()) {
      session.dispose();
    }
    _uiSessions.clear();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reload = false}) async {
    final service = widget.service;
    final request = Object();
    _loadRequest = request;
    bool current() =>
        mounted &&
        identical(widget.service, service) &&
        identical(_loadRequest, request);
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await service.initialize(reload: reload);
    } catch (_) {
      if (current()) setState(() => _failed = true);
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _open({KnowledgeRecord? item, required int generation}) async {
    if (_opening ||
        generation != _interactionGeneration ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final service = widget.service;
    final kind = widget.kind;
    final pageEditor = widget.pageEditor;
    final route = ModalRoute.of(context);
    final request = Object();
    final readSession = _createUiSession();
    _readSession = readSession;
    bool editorOpened = false;
    bool current() =>
        mounted &&
        identical(_openRequest, request) &&
        identical(widget.service, service) &&
        widget.kind == kind &&
        widget.pageEditor == pageEditor &&
        identical(ModalRoute.of(context), route) &&
        route?.isCurrent == true;
    setState(() => _openRequest = request);
    try {
      final record = item == null
          ? null
          : await service.read(item.kind, item.id);
      if (!mounted || !current() || !readSession.isCurrent) return;
      _readSession = null;
      _retireUiSession(readSession);
      editorOpened = true;
      final editor = AgentKnowledgeEditor(
        service: service,
        kind: kind,
        record: record,
        pagePresentation: pageEditor,
      );
      final receipt = pageEditor
          ? await Navigator.of(context).push<KnowledgeReceipt>(
              MaterialPageRoute<KnowledgeReceipt>(builder: (_) => editor),
            )
          : await showExpressiveDialog<KnowledgeReceipt>(
              context: context,
              barrierDismissible: false,
              builder: (_) => editor,
            );
      if (!mounted || !current() || receipt == null) return;
      final l = AppLocalizations.of(context);
      _showFeedback(
        l.agentKnowledgeSaved,
        undoOperationId: receipt.operationId,
      );
    } catch (_) {
      if (mounted && current() && (editorOpened || readSession.isCurrent)) {
        _showFeedback(AppLocalizations.of(context).agentKnowledgeStorageFailed);
      }
    } finally {
      if (identical(_readSession, readSession)) _readSession = null;
      _retireUiSession(readSession);
      if (mounted && identical(_openRequest, request)) {
        setState(() => _openRequest = null);
      }
    }
  }

  Future<void> _undo(String operationId) async {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final service = widget.service;
    final session = _createUiSession();
    try {
      await service.undoFromUi(operationId);
    } catch (_) {
      if (mounted && session.isCurrent) {
        _showFeedback(AppLocalizations.of(context).agentKnowledgeConflict);
      }
    } finally {
      _retireUiSession(session);
    }
  }

  Widget _statusBody(Widget child) {
    final header = widget.headerSliver;
    return CustomScrollView(
      slivers: [
        ?header,
        // Status actions contain LayoutBuilders. Fill the remaining viewport
        // without intrinsic sizing, and let taller feedback scroll normally.
        SliverLayoutBuilder(
          builder: (context, constraints) => SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    (constraints.viewportMainAxisExtent -
                            constraints.precedingScrollExtent)
                        .clamp(0.0, double.infinity)
                        .toDouble(),
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }

  bool _matchesFilters(KnowledgeRecord item) {
    final originMatches =
        item.kind == KnowledgeKind.memory ||
        switch (_origin) {
          _KnowledgeOrigin.all => true,
          _KnowledgeOrigin.builtIn => item.builtIn && item.usesOriginal,
          _KnowledgeOrigin.custom => !item.builtIn,
          _KnowledgeOrigin.modified => item.builtIn && !item.usesOriginal,
        };
    return originMatches &&
        switch (_state) {
          _KnowledgeState.all => true,
          _KnowledgeState.enabled => item.enabled,
          _KnowledgeState.disabled => !item.enabled,
          _KnowledgeState.missingTools =>
            widget.service.missingTools(item).isNotEmpty,
        };
  }

  String _originLabel(AppLocalizations l, _KnowledgeOrigin origin) =>
      switch (origin) {
        _KnowledgeOrigin.all => l.agentKnowledgeAllTypes,
        _KnowledgeOrigin.builtIn => l.agentKnowledgeBuiltin,
        _KnowledgeOrigin.custom => l.agentKnowledgeCustom,
        _KnowledgeOrigin.modified => l.agentKnowledgeModified,
      };

  String _stateLabel(AppLocalizations l, _KnowledgeState state) =>
      switch (state) {
        _KnowledgeState.all => l.agentKnowledgeAllStates,
        _KnowledgeState.enabled => l.agentKnowledgeEnabled,
        _KnowledgeState.disabled => l.agentKnowledgeDisabled,
        _KnowledgeState.missingTools => l.agentKnowledgeMissingTools,
      };

  Widget _filters(AppLocalizations l, bool skill) {
    final state = SkedDropdownMenu<_KnowledgeState>(
      key: ValueKey('knowledge-state-${widget.kind.name}'),
      initialSelection: _state,
      sessionKey: (widget.service, widget.kind),
      dropdownMenuEntries: [
        for (final value in _KnowledgeState.values)
          if (skill || value != _KnowledgeState.missingTools)
            DropdownMenuEntry(value: value, label: _stateLabel(l, value)),
      ],
      onSelected: (value) {
        if (value != null) setState(() => _state = value);
      },
    );
    if (!skill) return state;
    final origin = SkedDropdownMenu<_KnowledgeOrigin>(
      key: const ValueKey('knowledge-origin'),
      initialSelection: _origin,
      sessionKey: (widget.service, widget.kind),
      dropdownMenuEntries: [
        for (final value in _KnowledgeOrigin.values)
          DropdownMenuEntry(value: value, label: _originLabel(l, value)),
      ],
      onSelected: (value) {
        if (value != null) setState(() => _origin = value);
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [origin, const SizedBox(height: 8), state],
          );
        }
        return Row(
          children: [
            Expanded(child: origin),
            const SizedBox(width: 8),
            Expanded(child: state),
          ],
        );
      },
    );
  }

  void _showHelp(AppLocalizations l, bool skill) {
    unawaited(
      showExpressiveDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(skill ? l.agentSkills : l.agentMemories),
          content: Text(
            skill ? l.agentKnowledgeHelp : l.agentKnowledgeMemoryHelp,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).closeButtonTooltip),
            ),
          ],
        ),
      ),
    );
  }

  String _preview(KnowledgeRecord item) {
    final source = item.summary.trim().isNotEmpty
        ? item.summary
        : item.kind == KnowledgeKind.memory
        ? item.body
        : '';
    final text = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = StringBuffer();
    var count = 0;
    for (final character in text.characters) {
      // Keep whole graphemes, but also bound pathological combining sequences.
      // The Text/semantics node must never receive an entire long note.
      if (count == 160 || preview.length + character.length > 1024) {
        return '$preview…';
      }
      preview.write(character);
      count++;
    }
    return preview.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final generation = _interactionGeneration;
    final skill = widget.kind == KnowledgeKind.skill;
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        if (_loading) {
          return _statusBody(
            const Center(child: SkedExpressiveLoadingIndicator()),
          );
        }
        if (_failed || !widget.service.ready) {
          return _statusBody(
            ExpressiveEmptyState(
              icon: Icons.sync_problem_outlined,
              title: l.agentKnowledgeUnavailable,
              message: l.agentKnowledgeStorageFailed,
              actions: [
                FilledButton.tonal(
                  onPressed: () => unawaited(_load(reload: true)),
                  child: Text(l.agentKnowledgeReload),
                ),
              ],
            ),
          );
        }
        final items = widget.service
            .list(widget.kind, query: _search.text)
            .where(_matchesFilters)
            .toList();
        final filtered =
            _search.text.trim().isNotEmpty ||
            _state != _KnowledgeState.all ||
            (skill && _origin != _KnowledgeOrigin.all);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              slivers: [
                ?widget.headerSliver,
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: ValueKey(
                                  'knowledge-search-${widget.kind.name}',
                                ),
                                controller: _search,
                                decoration: InputDecoration(
                                  filled: true,
                                  prefixIcon: const Icon(Icons.search),
                                  labelText: l.agentKnowledgeSearch,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              key: ValueKey(
                                'knowledge-add-${widget.kind.name}',
                              ),
                              onPressed: _opening
                                  ? null
                                  : () => unawaited(
                                      _open(generation: generation),
                                    ),
                              icon: const Icon(Icons.add),
                              tooltip: l.agentKnowledgeAdd,
                            ),
                            IconButton(
                              key: const ValueKey('knowledge-help'),
                              tooltip: skill
                                  ? l.agentKnowledgeHelp
                                  : l.agentKnowledgeMemoryHelp,
                              onPressed: () => _showHelp(l, skill),
                              icon: const Icon(Icons.info_outline),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _filters(l, skill),
                      ],
                    ),
                  ),
                ),
                items.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: ExpressiveEmptyState(
                          icon: skill
                              ? Icons.auto_awesome_outlined
                              : Icons.psychology_outlined,
                          title: filtered
                              ? l.agentKnowledgeNoMatches
                              : l.agentKnowledgeEmpty,
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final preview = _preview(item);
                            final details = <String>[
                              if (skill)
                                item.builtIn
                                    ? (item.usesOriginal
                                          ? l.agentKnowledgeBuiltin
                                          : l.agentKnowledgeModified)
                                    : l.agentKnowledgeCustom,
                              item.enabled
                                  ? l.agentKnowledgeEnabled
                                  : l.agentKnowledgeDisabled,
                              if (skill &&
                                  widget.service.missingTools(item).isNotEmpty)
                                l.agentKnowledgeMissingTools,
                              if (!skill && widget.service.needsRecheck(item))
                                l.agentKnowledgeStaleReference,
                            ];
                            return Material(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              shape: index == 0 || index == items.length - 1
                                  ? skedShapeSchemeOf(context).card
                                  : skedShapeSchemeOf(context).compact,
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                key: ValueKey('knowledge-item-${item.key}'),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (preview.isNotEmpty)
                                      Text(
                                        preview,
                                        key: ValueKey(
                                          'knowledge-preview-${item.key}',
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      details.join(' · '),
                                      key: ValueKey(
                                        'knowledge-status-${item.key}',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _opening
                                    ? null
                                    : () => unawaited(
                                        _open(
                                          item: item,
                                          generation: generation,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AgentKnowledgeEditor extends StatefulWidget {
  const AgentKnowledgeEditor({
    super.key,
    required this.service,
    required this.kind,
    this.record,
    this.pagePresentation = false,
  });
  final AgentKnowledgeService service;
  final KnowledgeKind kind;
  final KnowledgeRecord? record;
  final bool pagePresentation;
  @override
  State<AgentKnowledgeEditor> createState() => _AgentKnowledgeEditorState();
}

class _AgentKnowledgeEditorState extends State<AgentKnowledgeEditor>
    with AgentSettingsExitGuard<AgentKnowledgeEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.record?.title ?? '');
  late final _summary = TextEditingController(
    text: widget.record?.summary ?? '',
  );
  late final _body = TextEditingController(text: widget.record?.body ?? '');
  late final _source = TextEditingController(
    text: widget.record?.sourceNote ?? '',
  );
  late final _triggers = TextEditingController(
    text: widget.record?.triggers.join('\n') ?? '',
  );
  late final _requiredTools = TextEditingController(
    text: widget.record?.requiredTools.join('\n') ?? '',
  );
  late final _optionalTools = TextEditingController(
    text: widget.record?.optionalTools.join('\n') ?? '',
  );
  late final String _newId =
      '${widget.kind == KnowledgeKind.skill ? 'custom' : 'memory'}-${generateUuidV4()}';
  late bool _enabled = widget.record?.enabled ?? true;
  bool _saving = false;
  KnowledgeError? _error;

  @override
  Object get settingsDraftFingerprint => (
    _title.text,
    _summary.text,
    _body.text,
    _source.text,
    _triggers.text,
    _requiredTools.text,
    _optionalTools.text,
    _enabled,
  );

  @override
  bool get settingsExitBlocked => _saving;

  @override
  void initState() {
    super.initState();
    initializeSettingsDraftGuard();
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _summary,
      _body,
      _source,
      _triggers,
      _requiredTools,
      _optionalTools,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save({bool original = false, bool delete = false}) async {
    if (_saving ||
        ModalRoute.of(context)?.isCurrent != true ||
        (!original && !delete && !_form.currentState!.validate())) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final before = widget.record;
      KnowledgeChangeSet plan;
      if (original) {
        plan = widget.service.prepareOriginal(before!);
      } else if (delete) {
        plan = widget.service.prepareDelete(before!);
      } else {
        final draft = before == null
            ? KnowledgeRecord(
                kind: widget.kind,
                id: _newId,
                title: _title.text.trim(),
                body: _body.text,
                summary: _summary.text.trim(),
                enabled: _enabled,
                sourceNote: _source.text.trim(),
                triggers: _lines(_triggers.text),
                requiredTools: _lines(_requiredTools.text),
                optionalTools: _lines(_optionalTools.text),
              )
            : before.copyWith(
                title: _title.text.trim(),
                summary: _summary.text.trim(),
                body: _body.text,
                sourceNote: _source.text.trim(),
                enabled: _enabled,
                triggers: _lines(_triggers.text),
                requiredTools: _lines(_requiredTools.text),
                optionalTools: _lines(_optionalTools.text),
                usesOriginal:
                    before.usesOriginal &&
                    _title.text.trim() == before.title &&
                    _summary.text.trim() == before.summary &&
                    _body.text == before.body &&
                    _triggers.text == before.triggers.join('\n') &&
                    _requiredTools.text == before.requiredTools.join('\n') &&
                    _optionalTools.text == before.optionalTools.join('\n'),
              );
        plan = widget.service.prepareSave(draft);
      }
      final receipt = await widget.service.saveFromUi(plan);
      if (mounted) {
        setState(() => _saving = false);
        completeSettingsSave<KnowledgeReceipt>(receipt);
      }
    } on KnowledgeException catch (error) {
      if (mounted) setState(() => _error = error.code);
    } catch (_) {
      if (mounted) setState(() => _error = KnowledgeError.unknown);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final route = ModalRoute.of(context);
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.agentKnowledgeDeleteConfirm),
        content: Text(widget.record!.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.agentKnowledgeDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && route?.isCurrent == true) {
      await _save(delete: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final skill = widget.kind == KnowledgeKind.skill;
    final colors = Theme.of(context).colorScheme;
    final content = Form(
      key: _form,
      onChanged: () => setState(() {}),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('knowledge-title'),
            controller: _title,
            enabled: !_saving,
            maxLength: 256,
            decoration: InputDecoration(labelText: l.agentKnowledgeTitle),
            validator: (value) => value == null || value.trim().isEmpty
                ? l.agentRequiredField
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('knowledge-summary'),
            controller: _summary,
            enabled: !_saving,
            maxLength: 2048,
            decoration: InputDecoration(labelText: l.agentKnowledgeSummary),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('knowledge-body'),
            controller: _body,
            enabled: !_saving,
            minLines: 6,
            maxLines: 14,
            decoration: InputDecoration(
              filled: true,
              alignLabelWithHint: true,
              labelText: l.agentKnowledgeBody,
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? l.agentRequiredField
                : null,
          ),
          if (widget.record != null &&
              widget.service.originalChanged(widget.record!))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l.agentKnowledgeOriginalChanged),
            ),
          if (!skill) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _source,
              enabled: !_saving,
              maxLength: 2048,
              decoration: InputDecoration(labelText: l.agentKnowledgeSource),
              minLines: 1,
              maxLines: 3,
            ),
          ],
          if (skill)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l.agentSkillAdvanced),
              children: [
                for (final entry in [
                  (_triggers, l.agentSkillTriggers),
                  (_requiredTools, l.agentSkillRequiredTools),
                  (_optionalTools, l.agentSkillOptionalTools),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: entry.$1,
                      enabled: !_saving,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: entry.$2,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
              ],
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l.agentKnowledgeEnabled),
            value: _enabled,
            onChanged: _saving
                ? null
                : (value) => setState(() => _enabled = value),
          ),
          if (_error != null)
            Text(switch (_error) {
              KnowledgeError.conflict => l.agentKnowledgeConflict,
              KnowledgeError.invalid ||
              KnowledgeError.limit => l.agentKnowledgeInvalid,
              _ => l.agentKnowledgeStorageFailed,
            }, style: TextStyle(color: colors.error)),
        ],
      ),
    );
    final actions = <Widget>[
      if (widget.record?.builtIn == true)
        TextButton(
          key: const ValueKey('knowledge-restore-original'),
          onPressed: _saving ? null : () => unawaited(_save(original: true)),
          child: Text(l.agentKnowledgeRestoreOriginal),
        ),
      if (widget.record != null && !widget.record!.builtIn)
        TextButton(
          key: const ValueKey('knowledge-delete'),
          onPressed: _saving ? null : () => unawaited(_delete()),
          child: Text(l.agentKnowledgeDelete),
        ),
      TextButton(
        onPressed: _saving
            ? null
            : widget.pagePresentation
            ? requestSettingsExit
            : () => Navigator.pop(context),
        child: Text(l.cancel),
      ),
      FilledButton(
        key: const ValueKey('knowledge-save'),
        onPressed: _saving ? null : () => unawaited(_save()),
        child: Text(_saving ? l.agentSaving : l.save),
      ),
    ];
    final title = widget.record == null
        ? l.agentKnowledgeAdd
        : widget.pagePresentation
        ? widget.record!.title
        : l.agentKnowledgeEdit;
    if (widget.pagePresentation) {
      return guardSettingsPage(
        SettingsPageScaffold(
          title: title,
          bodyBuilder: (_, header) => ResponsiveSettingsSingleColumnBody(
            headerSliver: header,
            scrollViewKey: const PageStorageKey(
              'agent-knowledge-editor-scroll',
            ),
            children: [
              content,
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 640,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: SingleChildScrollView(child: content),
          ),
        ),
        actions: actions,
      ),
    );
  }
}

List<String> _lines(String text) => text
    .split(RegExp(r'\r?\n'))
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toSet()
    .toList();
