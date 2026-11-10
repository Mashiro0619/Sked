import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/desktop_context_menu.dart';
import '../../widgets/expressive_dialog.dart';
import '../../widgets/sked_task_session.dart';
import '../../widgets/ui_command.dart';
import '../conversations/conversation_view_repository.dart';
import 'agent_ui_delegate.dart';

/// Object actions share one target owner across the header and history list.
/// Reading another conversation never changes an accepted action's target.
class AgentConversationActions extends ChangeNotifier {
  AgentConversationActions({
    required this.repository,
    required this.delegate,
    required this.isOwnerActive,
    this.readDatasetGeneration,
    this.recoverConversations,
    this.onExportConversation,
    this.onDeleted,
    this.onExported,
  }) {
    repository.addListener(_changed);
    delegate.state.addListener(_changed);
  }

  final ConversationViewRepository repository;
  final AgentUiDelegate delegate;
  final bool Function() isOwnerActive;
  final String Function()? readDatasetGeneration;
  final Future<void> Function()? recoverConversations;
  final Future<bool> Function(String conversationId)? onExportConversation;
  final void Function(String conversationId)? onDeleted;
  final void Function(String conversationId, bool saved)? onExported;

  final _busy = <(String, String), Object>{};
  final _owners = Expando<_ConversationActionOwner>();
  final _dialogs = <SkedTaskSession>{};
  var _generation = 0;
  var _disposed = false;

  bool isBusy(String targetId, [String? actionId]) => actionId == null
      ? _busy.keys.any((key) => key.$1 == targetId)
      : _busy.containsKey((targetId, actionId));

  void invalidate() {
    if (_disposed) return;
    _generation++;
    for (final dialog in _dialogs.toList()) {
      dialog.invalidate();
    }
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  bool get _available =>
      !_disposed &&
      isOwnerActive() &&
      delegate.state.value.enabled &&
      !delegate.state.value.maintenance;

  bool get _canRecover => repository.blocked && recoverConversations != null;

  List<DesktopAction> buildActions(DesktopActionContext context) {
    if (_disposed || !context.context.mounted) return const [];
    final target = context.target;
    if (target is! String) return const [];
    final conversation = repository.find(target);
    if (conversation == null || repository.isDraft(target)) return const [];
    final l = AppLocalizations.of(context.context);
    // A menu can rebuild its action list before dispatch. Retain the original
    // data/target identity rather than adopting a restored object with this ID.
    final owner = _owners[context] ??= _ConversationActionOwner(
      generation: _generation,
      datasetGeneration: readDatasetGeneration?.call(),
      id: target,
      createdAt: conversation.createdAt,
      title: conversation.title,
      route: ModalRoute.of(context.context),
    );

    DesktopAction action(String id, String label, IconData icon) =>
        DesktopAction(
          id: id,
          label: label,
          icon: icon,
          enabled:
              context.isCurrent() &&
              _ownerCurrent(owner) &&
              _canInvoke(id, conversation),
          onInvoke: () => _invoke(context, owner, id),
        );

    return [
      action('rename', l.rename, Icons.edit_outlined),
      if (!conversation.archived)
        action(
          conversation.pinned ? 'unpin' : 'pin',
          conversation.pinned
              ? l.agentUnpinConversation
              : l.agentPinConversation,
          conversation.pinned ? Icons.push_pin : Icons.push_pin_outlined,
        ),
      action(
        conversation.archived ? 'restore' : 'archive',
        conversation.archived
            ? l.agentRestoreConversation
            : l.agentArchiveConversation,
        conversation.archived
            ? Icons.unarchive_outlined
            : Icons.archive_outlined,
      ),
      if (onExportConversation != null)
        action(
          'export',
          l.agentExportConversation,
          Icons.file_download_outlined,
        ),
      action('delete', l.delete, Icons.delete_outline),
    ];
  }

  bool _ownerCurrent(
    _ConversationActionOwner owner, {
    bool requireTarget = true,
  }) {
    if (_disposed ||
        owner.generation != _generation ||
        !isOwnerActive() ||
        owner.route?.isActive == false ||
        owner.datasetGeneration != readDatasetGeneration?.call()) {
      return false;
    }
    if (!requireTarget) return true;
    final current = repository.find(owner.id);
    return current != null &&
        !repository.isDraft(owner.id) &&
        current.createdAt.isAtSameMomentAs(owner.createdAt);
  }

  bool _canInvoke(String action, AgentConversation target) {
    if (!_available || isBusy(target.id)) return false;
    return switch (action) {
      'pin' =>
        !target.archived &&
            !target.pinned &&
            (repository.canWrite || _canRecover),
      'unpin' =>
        !target.archived &&
            target.pinned &&
            (repository.canWrite || _canRecover),
      'restore' => target.archived && (repository.canWrite || _canRecover),
      'archive' => !target.archived && repository.canWrite,
      'export' => repository.canWrite && onExportConversation != null,
      'rename' || 'delete' => repository.canWrite,
      _ => false,
    };
  }

  Future<void> _invoke(
    DesktopActionContext context,
    _ConversationActionOwner owner,
    String action,
  ) async {
    if (!context.context.mounted ||
        !context.isCurrent() ||
        !_ownerCurrent(owner)) {
      return;
    }
    final target = repository.find(owner.id)!;
    if (!_canInvoke(action, target)) return;

    // From here the command owns its target. The row/menu may retire while a
    // recovery or confirmation completes without cancelling this command.
    final key = (owner.id, action);
    final token = Object();
    _busy[key] = token;
    _changed();
    try {
      if (!await _ensureWritable(
            owner,
            allowRecovery: const {'pin', 'unpin', 'restore'}.contains(action),
          ) ||
          !_ready(owner)) {
        return;
      }
      switch (action) {
        case 'rename':
          if (!context.context.mounted) return;
          final current = repository.find(owner.id)!;
          final title = await _showDialog<String>(
            context.context,
            owner,
            (_) => _RenameConversationDialog(title: current.title),
          );
          if (title == null || !_ready(owner)) return;
          await repository.rename(owner.id, title);
        case 'pin' || 'unpin':
          final current = repository.find(owner.id)!;
          final pinned = action == 'pin';
          if (current.archived || current.pinned == pinned) return;
          await repository.setPinned(owner.id, pinned);
        case 'archive' || 'restore':
          final archived = action == 'archive';
          if (repository.find(owner.id)!.archived == archived) return;
          await delegate.setArchived(owner.id, archived);
        case 'export':
          final export = onExportConversation;
          if (export == null) return;
          final saved = await export(owner.id);
          if (_ownerCurrent(owner, requireTarget: false)) {
            onExported?.call(owner.id, saved);
          }
        case 'delete':
          if (!context.context.mounted) return;
          final confirmed = await _showDialog<bool>(context.context, owner, (
            dialogContext,
          ) {
            final l = AppLocalizations.of(dialogContext);
            return AlertDialog(
              title: Text(l.agentDeleteConversation),
              content: Text(l.agentDeleteConversationMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l.delete),
                ),
              ],
            );
          });
          if (confirmed != true || !_ready(owner)) return;
          await delegate.stop(owner.id);
          if (!_ready(owner)) return;
          await repository.delete(
            owner.id,
            validate: (current) {
              if (!_ready(owner) ||
                  !current.createdAt.isAtSameMomentAs(owner.createdAt)) {
                throw const _RetiredConversationAction();
              }
            },
          );
          if (_ownerCurrent(owner, requireTarget: false)) {
            onDeleted?.call(owner.id);
          }
      }
    } on _RetiredConversationAction {
      // The original target or data session retired before write acceptance.
    } catch (_) {
      if (context.context.mounted &&
          _ownerCurrent(owner, requireTarget: false)) {
        showUiFailureFeedback(
          context: context.context,
          message:
              '${owner.title}: '
              '${AppLocalizations.of(context.context).agentActionFailed}',
        );
      }
    } finally {
      if (identical(_busy[key], token)) {
        _busy.remove(key);
        _changed();
      }
    }
  }

  bool _ready(_ConversationActionOwner owner) =>
      _ownerCurrent(owner) && _available && repository.canWrite;

  Future<bool> _ensureWritable(
    _ConversationActionOwner owner, {
    required bool allowRecovery,
  }) async {
    if (!_ownerCurrent(owner) || !_available) return false;
    if (repository.canWrite) return true;
    final recover = recoverConversations;
    if (!allowRecovery || !repository.blocked || recover == null) return false;
    // Recovery rebuilds the projection and may remove the source row. Check
    // the captured identity only after the owned recovery has finished.
    await recover();
    await WidgetsBinding.instance.endOfFrame;
    if (!_ownerCurrent(owner) || !_available) return false;
    if (!repository.canWrite) {
      throw StateError('Conversation storage is unavailable.');
    }
    return true;
  }

  Future<T?> _showDialog<T>(
    BuildContext context,
    _ConversationActionOwner owner,
    WidgetBuilder builder,
  ) async {
    final session = SkedTaskSession(
      ownerRoute: owner.route,
      targetChanges: this,
      isOwnerActive: () => _ready(owner),
    );
    _dialogs.add(session);
    try {
      return await showExpressiveDialog<T>(
        context: context,
        session: session,
        builder: builder,
      );
    } finally {
      _dialogs.remove(session);
      session.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    repository.removeListener(_changed);
    delegate.state.removeListener(_changed);
    for (final dialog in _dialogs.toList()) {
      dialog.invalidate();
    }
    super.dispose();
  }
}

class _ConversationActionOwner {
  const _ConversationActionOwner({
    required this.generation,
    required this.datasetGeneration,
    required this.id,
    required this.createdAt,
    required this.title,
    required this.route,
  });

  final int generation;
  final String? datasetGeneration;
  final String id;
  final DateTime createdAt;
  final String title;
  final ModalRoute<dynamic>? route;
}

class _RetiredConversationAction implements Exception {
  const _RetiredConversationAction();
}

class _RenameConversationDialog extends StatefulWidget {
  const _RenameConversationDialog({required this.title});
  final String title;

  @override
  State<_RenameConversationDialog> createState() =>
      _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<_RenameConversationDialog> {
  late final _controller = TextEditingController(text: widget.title);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.agentRenameConversation),
      content: TextField(
        key: const ValueKey('agent-rename-input'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(filled: true, labelText: l.name),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.of(context).pop(value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text.trim()),
            child: Text(l.save),
          ),
        ),
      ],
    );
  }
}
