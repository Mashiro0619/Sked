import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_menu_style.dart';

/// Keeps message operations beside their owner. Hidden desktop controls retain
/// keyboard traversal, reveal on focus, and cannot receive invisible clicks.
/// A requested semantics tree reveals the same real buttons for screen readers.
/// Touch controls stay visible with their full 48dp effective target.
class AgentMessageActions extends StatefulWidget {
  const AgentMessageActions({
    super.key,
    required this.messageId,
    required this.child,
    required this.copyText,
    this.isUser = false,
    this.active = true,
    this.interactive = true,
    this.alwaysVisible = false,
    this.onEditAndRedo,
    this.onRegenerate,
    this.showEditAndRedo = false,
    this.showRegenerate = false,
    this.versionIndex = 0,
    this.versionCount = 1,
    this.onVersionSelected,
  }) : assert(versionCount > 0),
       assert(versionIndex >= 0 && versionIndex < versionCount);

  final String messageId;
  final Widget child;
  final String copyText;
  final bool isUser;
  final bool active;
  final bool interactive;
  final bool alwaysVisible;
  final VoidCallback? onEditAndRedo;
  final VoidCallback? onRegenerate;
  final bool showEditAndRedo;
  final bool showRegenerate;

  /// Version navigation is presentation-only. The host decides which saved
  /// text to display and never changes the executable business history here.
  final int versionIndex;
  final int versionCount;
  final ValueChanged<int>? onVersionSelected;

  @override
  State<AgentMessageActions> createState() => _AgentMessageActionsState();
}

class _AgentMessageActionsState extends State<AgentMessageActions> {
  bool _hovered = false;
  bool _focused = false;
  bool _copying = false;
  bool _copied = false;
  int _generation = 0;

  bool get _enabled => widget.active && widget.interactive;

  @override
  void initState() {
    super.initState();
    SemanticsBinding.instance.addSemanticsEnabledListener(_semanticsChanged);
  }

  void _semanticsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SemanticsBinding.instance.removeSemanticsEnabledListener(_semanticsChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(AgentMessageActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId ||
        oldWidget.copyText != widget.copyText ||
        oldWidget.versionIndex != widget.versionIndex ||
        oldWidget.versionCount != widget.versionCount ||
        (oldWidget.active && !widget.active) ||
        (oldWidget.interactive && !widget.interactive)) {
      _generation++;
      _copying = false;
      _copied = false;
    }
    if (!_enabled) {
      _hovered = false;
      _focused = false;
    }
  }

  Future<void> _copy() async {
    if (!_enabled || _copying || widget.copyText.isEmpty) return;
    final generation = _generation;
    final text = widget.copyText;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted && _enabled && generation == _generation) {
        setState(() => _copied = true);
      }
    } catch (_) {
      if (mounted && _enabled && generation == _generation) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).agentCopyFailed)),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _copying = false);
      }
    }
  }

  void _selectVersion(int index, int generation) {
    if (!_enabled ||
        generation != _generation ||
        index < 0 ||
        index >= widget.versionCount) {
      return;
    }
    widget.onVersionSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final desktop = SkedMenuStyle.of(context).desktop;
    final extent = desktop ? 32.0 : 48.0;
    final generation = _generation;
    final visible =
        _enabled &&
        (!desktop ||
            widget.alwaysVisible ||
            MediaQuery.accessibleNavigationOf(context) ||
            SemanticsBinding.instance.semanticsEnabled ||
            _hovered ||
            _focused);
    Widget action({
      required String id,
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
    }) => IconButton(
      key: ValueKey('$id-${widget.messageId}'),
      tooltip: label,
      onPressed: _enabled && onPressed != null
          ? () {
              if (_enabled && generation == _generation) onPressed();
            }
          : null,
      icon: Icon(icon, size: 18),
      style: IconButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        minimumSize: Size.square(extent),
        maximumSize: Size.square(extent),
        padding: EdgeInsets.zero,
        tapTargetSize: desktop
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
      ),
    );

    final actions = Wrap(
      alignment: widget.isUser ? WrapAlignment.end : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (widget.copyText.isNotEmpty)
          action(
            id: 'agent-copy',
            label: _copied ? l.agentCopied : l.agentCopyMessage,
            icon: _copied ? Icons.check_rounded : Icons.copy_outlined,
            onPressed: _copying ? null : _copy,
          ),
        if (widget.showEditAndRedo || widget.onEditAndRedo != null)
          action(
            id: 'agent-edit-redo',
            label: l.agentEditAndRedo,
            icon: Icons.edit_outlined,
            onPressed: widget.onEditAndRedo == null
                ? null
                : () {
                    if (_enabled) widget.onEditAndRedo?.call();
                  },
          ),
        if (widget.showRegenerate || widget.onRegenerate != null)
          action(
            id: 'agent-regenerate',
            label: l.agentRegenerateReply,
            icon: Icons.refresh_rounded,
            onPressed: widget.onRegenerate == null
                ? null
                : () {
                    if (_enabled) widget.onRegenerate?.call();
                  },
          ),
        if (widget.versionCount > 1) ...[
          action(
            id: 'agent-reply-previous',
            label: l.agentPreviousReply,
            icon: Icons.chevron_left_rounded,
            onPressed:
                widget.onVersionSelected != null && widget.versionIndex > 0
                ? () => _selectVersion(widget.versionIndex - 1, generation)
                : null,
          ),
          Semantics(
            label:
                '${l.agentHistoryVersions}: '
                '${l.agentReplyVersion(widget.versionIndex + 1, widget.versionCount)}',
            child: Text(
              l.agentReplyVersion(widget.versionIndex + 1, widget.versionCount),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          action(
            id: 'agent-reply-next',
            label: l.agentNextReply,
            icon: Icons.chevron_right_rounded,
            onPressed:
                widget.onVersionSelected != null &&
                    widget.versionIndex < widget.versionCount - 1
                ? () => _selectVersion(widget.versionIndex + 1, generation)
                : null,
          ),
        ],
      ],
    );
    return MouseRegion(
      onEnter: (_) {
        if (_enabled) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: _enabled,
        descendantsAreTraversable: _enabled,
        onFocusChange: (value) {
          if (_focused != value) setState(() => _focused = value && _enabled);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.child,
            Align(
              alignment: widget.isUser
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: IgnorePointer(
                ignoring: !visible,
                child: ExcludeSemantics(
                  excluding: !visible,
                  child: Opacity(opacity: visible ? 1 : 0, child: actions),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
