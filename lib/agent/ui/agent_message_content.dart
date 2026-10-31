import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../widgets/expressive_motion.dart';

/// Message presentation never interprets a reply as an application operation.
/// Persisted operation receipts have their own host-owned cards.
class AgentMessageContent extends StatelessWidget {
  const AgentMessageContent({
    super.key,
    required this.text,
    required this.roleLabel,
    this.isUser = false,
    this.isNotice = false,
    this.streaming = false,
  });

  final String text;
  final String roleLabel;
  final bool isUser;
  final bool isNotice;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.55);
    final body = isUser || isNotice
        ? SelectableText(text, style: bodyStyle)
        : MarkdownBody(
            data: text,
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
            imageBuilder: (uri, title, alt) => SelectableText(
              (alt?.isNotEmpty == true ? alt : title) ?? uri.toString(),
              style: bodyStyle,
            ),
            onTapLink: (_, href, _) async {
              final uri = href == null ? null : Uri.tryParse(href);
              if (uri == null ||
                  !const {'https', 'http', 'mailto'}.contains(uri.scheme)) {
                return;
              }
              try {
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text(l.agentOperationFailed)),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text(l.agentOperationFailed)),
                  );
                }
              }
            },
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: isUser
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: isUser ? 0.88 : 1,
          child: Semantics(
            container: true,
            label: roleLabel,
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (isNotice) ...[
                  Text(
                    roleLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (isUser)
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
                if (!streaming && !isNotice)
                  AgentCopyButton(text: text, label: l.agentCopyMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AgentCopyButton extends StatefulWidget {
  const AgentCopyButton({super.key, required this.text, required this.label});
  final String text;
  final String label;

  @override
  State<AgentCopyButton> createState() => _AgentCopyButtonState();
}

class _AgentCopyButtonState extends State<AgentCopyButton> {
  bool _copied = false;
  bool _copying = false;

  @override
  void didUpdateWidget(AgentCopyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _copied = false;
  }

  Future<void> _copy() async {
    if (_copying) return;
    final text = widget.text;
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted && text == widget.text) setState(() => _copied = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).agentCopyFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _copied ? AppLocalizations.of(context).agentCopied : widget.label,
    onPressed: _copying ? null : _copy,
    iconSize: 18,
    icon: ExpressiveSwitcher(
      child: Icon(
        _copied ? Icons.check_rounded : Icons.copy_outlined,
        key: ValueKey(_copied),
      ),
    ),
  );
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
                AgentCopyButton(
                  text: code,
                  label: AppLocalizations.of(context).agentCopyCode,
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
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
