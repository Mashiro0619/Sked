import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../utils/unique_id.dart';
import '../../widgets/expressive_dialog.dart';
import '../../widgets/expressive_empty_state.dart';
import '../../widgets/sked_expressive_loading_indicator.dart';
import '../knowledge/knowledge_service.dart';

class AgentKnowledgeView extends StatefulWidget {
  const AgentKnowledgeView({
    super.key,
    required this.service,
    required this.kind,
  });
  final AgentKnowledgeService service;
  final KnowledgeKind kind;
  @override
  State<AgentKnowledgeView> createState() => _AgentKnowledgeViewState();
}

class _AgentKnowledgeViewState extends State<AgentKnowledgeView> {
  final _search = TextEditingController();
  bool _loading = true, _failed = false, _opening = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reload = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await widget.service.initialize(reload: reload);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open([KnowledgeRecord? item]) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final record = item == null
          ? null
          : await widget.service.read(item.kind, item.id);
      if (!mounted) return;
      final receipt = await showExpressiveDialog<KnowledgeReceipt>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AgentKnowledgeEditor(
          service: widget.service,
          kind: widget.kind,
          record: record,
        ),
      );
      if (!mounted || receipt == null) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.agentKnowledgeSaved),
          action: SnackBarAction(
            label: l.agentKnowledgeUndo,
            onPressed: () => unawaited(_undo(receipt.operationId)),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).agentKnowledgeStorageFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _undo(String operationId) async {
    try {
      await widget.service.undoFromUi(operationId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).agentKnowledgeConflict),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final skill = widget.kind == KnowledgeKind.skill;
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        if (_loading) {
          return const Center(child: SkedExpressiveLoadingIndicator());
        }
        if (_failed || !widget.service.ready) {
          return ExpressiveEmptyState(
            icon: Icons.sync_problem_outlined,
            title: l.agentKnowledgeUnavailable,
            message: l.agentKnowledgeStorageFailed,
            actions: [
              FilledButton.tonal(
                onPressed: () => unawaited(_load(reload: true)),
                child: Text(l.agentKnowledgeReload),
              ),
            ],
          );
        }
        final items = widget.service.list(widget.kind, query: _search.text);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          skill
                              ? l.agentKnowledgeHelp
                              : l.agentKnowledgeMemoryHelp,
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact =
                                constraints.maxWidth < 420 ||
                                MediaQuery.textScalerOf(context).scale(14) > 21;
                            final search = TextField(
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
                            );
                            final add = FilledButton.tonalIcon(
                              key: ValueKey(
                                'knowledge-add-${widget.kind.name}',
                              ),
                              onPressed: _opening
                                  ? null
                                  : () => unawaited(_open()),
                              icon: const Icon(Icons.add),
                              label: Text(l.agentKnowledgeAdd),
                            );
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  search,
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: add,
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: search),
                                const SizedBox(width: 12),
                                add,
                              ],
                            );
                          },
                        ),
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
                          title: l.agentKnowledgeEmpty,
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final details = <String>[
                              if (skill)
                                item.builtIn
                                    ? (item.usesOriginal
                                          ? l.agentKnowledgeBuiltin
                                          : l.agentKnowledgeModified)
                                    : l.agentKnowledgeCustom,
                              if (!item.enabled ||
                                  skill &&
                                      widget.service
                                          .missingTools(item)
                                          .isNotEmpty)
                                l.agentKnowledgeUnavailable,
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
                                  vertical: 8,
                                ),
                                leading: Icon(
                                  skill
                                      ? Icons.auto_awesome_outlined
                                      : Icons.psychology_outlined,
                                ),
                                title: Text(item.title),
                                subtitle: Text(
                                  [
                                    if (item.summary.isNotEmpty) item.summary,
                                    ...details,
                                  ].join(' · '),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _opening
                                    ? null
                                    : () => unawaited(_open(item)),
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
  });
  final AgentKnowledgeService service;
  final KnowledgeKind kind;
  final KnowledgeRecord? record;
  @override
  State<AgentKnowledgeEditor> createState() => _AgentKnowledgeEditorState();
}

class _AgentKnowledgeEditorState extends State<AgentKnowledgeEditor> {
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
    if (_saving || (!original && !delete && !_form.currentState!.validate())) {
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
      if (mounted) Navigator.of(context).pop(receipt);
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
    if (confirmed == true && mounted) await _save(delete: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final skill = widget.kind == KnowledgeKind.skill;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          widget.record == null ? l.agentKnowledgeAdd : l.agentKnowledgeEdit,
        ),
        content: SizedBox(
          width: 640,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const ValueKey('knowledge-title'),
                      controller: _title,
                      enabled: !_saving,
                      maxLength: 256,
                      decoration: InputDecoration(
                        labelText: l.agentKnowledgeTitle,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l.agentRequiredField
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('knowledge-summary'),
                      controller: _summary,
                      enabled: !_saving,
                      maxLength: 2048,
                      decoration: InputDecoration(
                        labelText: l.agentKnowledgeSummary,
                      ),
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
                      validator: (value) =>
                          value == null || value.trim().isEmpty
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
                        decoration: InputDecoration(
                          labelText: l.agentKnowledgeSource,
                        ),
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
              ),
            ),
          ),
        ),
        actions: [
          if (widget.record?.builtIn == true)
            TextButton(
              key: const ValueKey('knowledge-restore-original'),
              onPressed: _saving
                  ? null
                  : () => unawaited(_save(original: true)),
              child: Text(l.agentKnowledgeRestoreOriginal),
            ),
          if (widget.record != null && !widget.record!.builtIn)
            TextButton(
              key: const ValueKey('knowledge-delete'),
              onPressed: _saving ? null : () => unawaited(_delete()),
              child: Text(l.agentKnowledgeDelete),
            ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('knowledge-save'),
            onPressed: _saving ? null : () => unawaited(_save()),
            child: Text(_saving ? l.agentSaving : l.save),
          ),
        ],
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
