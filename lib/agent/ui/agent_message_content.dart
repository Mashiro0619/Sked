import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../widgets/expressive_motion.dart';
import 'agent_selectable_text.dart';

/// Message presentation never interprets a reply as an application operation.
/// Persisted operation receipts have their own host-owned cards.
class AgentMessageContent extends StatefulWidget {
  const AgentMessageContent({
    super.key,
    required this.text,
    required this.roleLabel,
    this.isUser = false,
    this.isNotice = false,
    this.streaming = false,
    this.showCopy = true,
    this.active = true,
    this.interactive = true,
    this.interactionRevision = 0,
  });

  final String text;
  final String roleLabel;
  final bool isUser;
  final bool isNotice;
  final bool streaming;
  final bool showCopy;
  final bool active;
  final bool interactive;
  final int interactionRevision;

  @override
  State<AgentMessageContent> createState() => _AgentMessageContentState();
}

class _AgentMessageContentState extends State<AgentMessageContent> {
  final _pointerSource = _AgentPointerSource();
  int _interactionEpoch = 0;

  bool get _enabled => widget.active && widget.interactive;

  @override
  void didUpdateWidget(AgentMessageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.roleLabel != widget.roleLabel ||
        oldWidget.isUser != widget.isUser ||
        oldWidget.isNotice != widget.isNotice ||
        oldWidget.streaming != widget.streaming ||
        oldWidget.showCopy != widget.showCopy ||
        oldWidget.active != widget.active ||
        oldWidget.interactive != widget.interactive ||
        oldWidget.interactionRevision != widget.interactionRevision) {
      _interactionEpoch++;
    }
  }

  bool _current(int epoch) => mounted && _enabled && epoch == _interactionEpoch;

  Future<void> _openLink(String? href, int epoch) async {
    if (!_current(epoch) || !_pointerSource.permits(epoch)) return;
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null ||
        !const {'https', 'http', 'mailto'}.contains(uri.scheme)) {
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _linkFailed(epoch);
    } catch (_) {
      _linkFailed(epoch);
    }
  }

  void _linkFailed(int epoch) {
    if (!_current(epoch)) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).agentOperationFailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final epoch = _interactionEpoch;
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.55);
    final body = widget.isUser || widget.isNotice
        ? AgentSelectableText(widget.text, style: bodyStyle)
        : MarkdownBody(
            data: widget.text,
            selectable: true,
            fitContent: false,
            softLineBreak: true,
            // material_ui and Flutter expose different ThemeData types. Pass
            // the actual semantic styles rather than Flutter's fallback theme.
            styleSheet: MarkdownStyleSheet(
              a: TextStyle(
                color: colors.primary,
                decoration: TextDecoration.underline,
              ),
              p: bodyStyle,
              h1: theme.textTheme.headlineSmall,
              h2: theme.textTheme.titleLarge,
              h3: theme.textTheme.titleMedium,
              h4: theme.textTheme.titleSmall,
              h5: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
              h6: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              em: const TextStyle(fontStyle: FontStyle.italic),
              strong: const TextStyle(fontWeight: FontWeight.bold),
              del: const TextStyle(decoration: TextDecoration.lineThrough),
              blockquote: bodyStyle,
              listBullet: bodyStyle,
              tableHead: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
              tableBody: bodyStyle,
              tableBorder: TableBorder.all(color: colors.outlineVariant),
              checkbox: bodyStyle?.copyWith(color: colors.primary),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              blockSpacing: 14,
              listIndent: 24,
              code: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: colors.surfaceContainerHigh,
              ),
              blockquoteDecoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                border: BorderDirectional(
                  start: BorderSide(color: colors.outlineVariant, width: 3),
                ),
              ),
            ),
            builders: {'pre': _CodeBlockBuilder()},
            // A remote image embedded in model text must not make an implicit
            // request to a third-party host while reading the conversation.
            imageBuilder: (uri, title, alt) => AgentSelectableText(
              (alt?.isNotEmpty == true ? alt : title) ?? uri.toString(),
              style: bodyStyle,
            ),
            onTapLink: _enabled
                ? (_, href, _) => unawaited(_openLink(href, epoch))
                : null,
          );
    final content = _AgentMessageInteraction(
      active: widget.active,
      interactive: widget.interactive,
      revision: epoch,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Align(
          alignment: widget.isUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: widget.isUser ? 0.88 : 1,
            child: Semantics(
              container: true,
              label: widget.roleLabel,
              child: Column(
                crossAxisAlignment: widget.isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (widget.isNotice) ...[
                    Text(
                      widget.roleLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (widget.isUser)
                    Material(
                      color: colors.surfaceContainerHigh,
                      shape: skedShapeSchemeOf(context).container,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: body,
                      ),
                    )
                  else
                    body,
                  if (widget.showCopy && !widget.streaming && !widget.isNotice)
                    AgentCopyButton(
                      text: widget.text,
                      label: l.agentCopyMessage,
                      active: widget.active,
                      interactive: widget.interactive,
                      interactionRevision: epoch,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return _pointerSource.listen(content, epoch);
  }
}

/// A recognizer may read its latest callback when releasing an older press.
/// Listener receives Up before the gesture arena dispatches that tap, so the
/// activation keeps Down's source. Clear it after this event for nonpointer
/// activations; accepted system operations use only their own source epoch.
class _AgentPointerSource {
  final _pressedEpochs = <int, int>{};
  int? _releasedEpoch;
  Object? _release;

  bool permits(int epoch) => _releasedEpoch == null || _releasedEpoch == epoch;

  Widget listen(Widget child, int epoch) => Listener(
    onPointerDown: (event) => _pressedEpochs[event.pointer] = epoch,
    onPointerUp: _end,
    onPointerCancel: (event) => _pressedEpochs.remove(event.pointer),
    child: child,
  );

  void _end(PointerUpEvent event) {
    final epoch = _pressedEpochs.remove(event.pointer);
    if (epoch == null) return;
    _releasedEpoch = epoch;
    final release = Object();
    _release = release;
    scheduleMicrotask(() {
      if (!identical(_release, release)) return;
      _releasedEpoch = null;
      _release = null;
    });
  }
}

/// Markdown caches its code-block widgets when only host availability changes.
/// Keep copy controls subscribed without rebuilding selectable code content.
class _AgentMessageInteraction extends InheritedWidget {
  const _AgentMessageInteraction({
    required this.active,
    required this.interactive,
    required this.revision,
    required super.child,
  });

  final bool active;
  final bool interactive;
  final int revision;

  static _AgentMessageInteraction of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AgentMessageInteraction>()!;

  @override
  bool updateShouldNotify(_AgentMessageInteraction oldWidget) =>
      active != oldWidget.active ||
      interactive != oldWidget.interactive ||
      revision != oldWidget.revision;
}

class AgentCopyButton extends StatefulWidget {
  const AgentCopyButton({
    super.key,
    required this.text,
    required this.label,
    this.active = true,
    this.interactive = true,
    this.interactionRevision = 0,
  });
  final String text;
  final String label;
  final bool active;
  final bool interactive;
  final int interactionRevision;

  @override
  State<AgentCopyButton> createState() => _AgentCopyButtonState();
}

class _AgentCopyButtonState extends State<AgentCopyButton> {
  final _pointerSource = _AgentPointerSource();
  bool _copied = false;
  bool _copying = false;
  int _interactionEpoch = 0;

  bool get _enabled => widget.active && widget.interactive;

  bool _current(int epoch) => mounted && _enabled && epoch == _interactionEpoch;

  @override
  void didUpdateWidget(AgentCopyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.label != widget.label ||
        oldWidget.active != widget.active ||
        oldWidget.interactive != widget.interactive ||
        oldWidget.interactionRevision != widget.interactionRevision) {
      _interactionEpoch++;
      _copied = false;
      _copying = false;
    }
  }

  Future<void> _copy(int epoch) async {
    if (!_current(epoch) || !_pointerSource.permits(epoch) || _copying) return;
    final text = widget.text;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (_current(epoch)) setState(() => _copied = true);
    } catch (_) {
      _copyFailed(epoch);
    } finally {
      if (_current(epoch)) setState(() => _copying = false);
    }
  }

  void _copyFailed(int epoch) {
    if (!_current(epoch)) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).agentCopyFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final epoch = _interactionEpoch;
    final button = IconButton(
      tooltip: _copied
          ? AppLocalizations.of(context).agentCopied
          : widget.label,
      onPressed: !_enabled || _copying ? null : () => unawaited(_copy(epoch)),
      iconSize: 18,
      icon: ExpressiveSwitcher(
        child: Icon(
          _copied ? Icons.check_rounded : Icons.copy_outlined,
          key: ValueKey(_copied),
        ),
      ),
    );
    return _pointerSource.listen(button, epoch);
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent;
    final codeElement = element.children?.whereType<md.Element>().firstOrNull;
    final language = codeElement?.attributes['class']?.replaceFirst(
      'language-',
      '',
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: skedShapeSchemeOf(context).card,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final interaction = _AgentMessageInteraction.of(context);
                    return AgentCopyButton(
                      text: code,
                      label: AppLocalizations.of(context).agentCopyCode,
                      active: interaction.active,
                      interactive: interaction.interactive,
                      interactionRevision: interaction.revision,
                    );
                  },
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AgentSelectableText(
              code,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
