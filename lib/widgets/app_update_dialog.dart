import '../theme/sked_surface.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/update_distribution.dart';
import '../services/update_service.dart';
import 'sked_floating_surface.dart';
import 'sked_panel_header.dart';
import 'workbench_chrome_metrics.dart';
import 'sked_task_route.dart';
import 'sked_task_session.dart';

/// Only HTTPS release-note links may leave the app. Images never load remotely.
Uri? resolveUpdateNoteLink(String? href, String releaseUrl) {
  if (href == null) return null;
  final base = Uri.tryParse(releaseUrl);
  if (base?.scheme != 'https' || base!.host.isEmpty) return null;
  final target = Uri.tryParse(href);
  if (target == null) return null;
  final resolved = base.resolveUri(target);
  return resolved.scheme == 'https' &&
          resolved.host.isNotEmpty &&
          resolved.userInfo.isEmpty
      ? resolved
      : null;
}

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.distribution,
    required this.session,
    required this.retry,
    required this.recordResult,
    required this.ignoreVersion,
    required this.startup,
    required this.fallbackUrl,
    this.result,
    this.initialError,
  });
  final UpdateDistribution distribution;
  final SkedTaskSession session;
  final Future<UpdateCheckResult> Function() retry;
  final Future<void> Function(UpdateCheckResult) recordResult;
  final Future<void> Function(String) ignoreVersion;
  final bool startup;
  final String fallbackUrl;
  final UpdateCheckResult? result;
  final String? initialError;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  late UpdateCheckResult? _result = widget.result;
  late String? _error = widget.initialError;
  bool _busy = false;
  final _scroll = ScrollController();
  bool get _current => mounted && widget.session.isCurrent;

  void _close() {
    if (!_busy && _current) completeSkedTaskRoute(context);
  }

  Future<void> _operate(Future<void> Function() action) async {
    if (_busy || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _report(String error) {
    if (!mounted || !_current) return;
    setState(() => _error = error);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _retry() => _operate(() async {
    final l10n = AppLocalizations.of(context);
    UpdateCheckResult result;
    try {
      result = await widget.retry();
    } catch (_) {
      _report(l10n.updateNetworkFailure);
      return;
    }
    if (!mounted || !_current) return;
    setState(() => _result = result);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    try {
      await widget.recordResult(result);
    } catch (_) {
      _report(l10n.saveFailedRetry);
    }
  });

  Future<void> _open([Uri? noteLink]) => _operate(() async {
    final l10n = AppLocalizations.of(context);
    final destination = noteLink == null
        ? widget.distribution
        : UpdateDistribution(
            UpdateChannel.github,
            urlLauncher: widget.distribution.urlLauncher,
          );
    final opened = await destination.open(
      noteLink?.toString() ?? _result?.releaseUrl ?? widget.fallbackUrl,
    );
    if (!mounted || !_current) return;
    if (!opened) {
      _report(l10n.openUpdatesFailed);
      return;
    }
    if (noteLink == null) completeSkedTaskRoute(context);
  });

  Future<void> _ignore() => _operate(() async {
    final version = _result?.remoteVersion;
    if (version == null) return;
    final l10n = AppLocalizations.of(context);
    try {
      await widget.ignoreVersion(version);
    } catch (_) {
      _report(l10n.saveFailedRetry);
      return;
    }
    if (mounted && _current) completeSkedTaskRoute(context);
  });

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _buildDesktop(BuildContext context, {required double width}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final result = _result;
    final failed = result == null;
    final found = result?.hasUpdate == true;
    final title = failed
        ? l10n.updateCheckFailedTitle
        : found
        ? l10n.updateFoundTitle
        : l10n.updateNoNewerVersion(result.localVersion);
    final buttonStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(72, metrics.commandHeight)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      textStyle: WidgetStatePropertyAll(theme.textTheme.labelLarge),
    );
    final secondary = OutlinedButton(
      style: buttonStyle,
      onPressed: _busy ? null : _close,
      child: Text(widget.startup ? l10n.updateLater : l10n.cancel),
    );
    final channel = FilledButton(
      style: buttonStyle,
      onPressed: _busy ? null : _open,
      child: Text(widget.distribution.label(l10n)),
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        secondary,
        if (failed) ...[
          OutlinedButton(
            style: buttonStyle,
            onPressed: _busy ? null : _open,
            child: Text(widget.distribution.label(l10n)),
          ),
          FilledButton(
            style: buttonStyle,
            onPressed: _busy ? null : _retry,
            child: Text(l10n.updateRetry),
          ),
        ] else if (found)
          channel,
      ],
    );
    final ignore = TextButton(
      style: buttonStyle.copyWith(
        minimumSize: WidgetStatePropertyAll(Size(0, metrics.commandHeight)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
      ),
      onPressed: _busy ? null : _ignore,
      child: Text(l10n.ignoreThisVersion),
    );
    final footer = LayoutBuilder(
      builder: (context, constraints) {
        if (!widget.startup || !found) {
          return Align(
            alignment: AlignmentDirectional.centerEnd,
            child: actions,
          );
        }
        // Reserve space for translated labels instead of squeezing button text.
        if (constraints.maxWidth >= 460 * metrics.textScale) {
          return Row(
            children: [
              ignore,
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: AlignmentDirectional.centerStart, child: ignore),
            const SizedBox(height: 4),
            Align(alignment: AlignmentDirectional.centerEnd, child: actions),
          ],
        );
      },
    );
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        key: const ValueKey('app-update-dialog'),
        insetPadding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: width),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        child: SkedFloatingSurface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              return SizedBox(
                key: const ValueKey('app-update-content'),
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: height * .4),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            16,
                            4,
                            12,
                            4,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 40),
                            child: SkedPanelHeader(
                              title: Text(
                                title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              verticalAlignment: CrossAxisAlignment.center,
                              closeKey: const ValueKey('app-update-close'),
                              closeEnabled: !_busy,
                              onClose: _close,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: math.min(460, height),
                        ),
                        child: Scrollbar(
                          controller: _scroll,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (found) ...[
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        result!.remoteVersion,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (isPrereleaseUpdateVersion(
                                        result.remoteVersion,
                                      ))
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            color: colors.secondaryContainer,
                                          ),
                                          child: Text(
                                            l10n.updatePrerelease,
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: colors
                                                      .onSecondaryContainer,
                                                ),
                                          ),
                                        ),
                                      Text(
                                        '${l10n.currentVersionLabel} ${result.localVersion}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                _buildNotes(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.outlineVariant,
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: height * .4),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: footer,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNotes(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = _result;
    final failed = result == null;
    final found = result?.hasUpdate == true;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
              semanticsLabel: _error,
            ),
          ),
        if (widget.distribution.isStore) ...[
          Text(
            l10n.storeUpdateDelay,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (found && isPrereleaseUpdateVersion(result!.remoteVersion))
            Text(l10n.storePrereleaseNotice, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
        ],
        if (failed && _error == null) Text(l10n.updateNetworkFailure),
        if (found)
          result!.updateContent.trim().isEmpty
              ? Text(l10n.updateNoNotes, style: theme.textTheme.bodyMedium)
              : MarkdownBody(
                  data: result.updateContent,
                  selectable: true,
                  fitContent: false,
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodyMedium,
                    h1: theme.textTheme.titleLarge,
                    h2: theme.textTheme.titleMedium,
                    h3: theme.textTheme.titleSmall,
                    a: TextStyle(
                      color: skedReadableAccent(
                        theme.colorScheme,
                        surface: SkedSurface.colorOf(context),
                      ),
                    ),
                    tableColumnWidth: const IntrinsicColumnWidth(),
                    code: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                    blockSpacing: 12,
                  ),
                  imageBuilder: (uri, title, alt) => Text(alt ?? title ?? ''),
                  onTapLink: (text, href, title) {
                    final uri = resolveUpdateNoteLink(href, result.releaseUrl);
                    if (uri != null) {
                      unawaited(_open(uri));
                    }
                  },
                ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = _result;
    final failed = result == null;
    final found = result?.hasUpdate == true;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final width = (560 * scale).clamp(560.0, 640.0);
    if (WorkbenchChromeMetrics.of(context).desktop) {
      return _buildDesktop(context, width: width);
    }
    final header = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          failed
              ? l10n.updateCheckFailedTitle
              : found
              ? l10n.updateFoundTitle
              : l10n.updateNoNewerVersion(result.localVersion),
          style: theme.textTheme.titleLarge,
        ),
        if (found) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                result!.remoteVersion,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isPrereleaseUpdateVersion(result.remoteVersion))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l10n.updatePrerelease,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.currentVersionLabel} ${result.localVersion}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: _busy ? null : _close,
          child: Text(widget.startup ? l10n.updateLater : l10n.cancel),
        ),
        if (widget.startup && found)
          TextButton(
            onPressed: _busy ? null : _ignore,
            child: Text(l10n.ignoreThisVersion),
          ),
        if (failed)
          TextButton(
            onPressed: _busy ? null : _open,
            child: Text(widget.distribution.label(l10n)),
          ),
        if (failed)
          FilledButton(
            onPressed: _busy ? null : _retry,
            child: Text(l10n.updateRetry),
          )
        else if (found)
          FilledButton(
            onPressed: _busy ? null : _open,
            child: Text(widget.distribution.label(l10n)),
          ),
      ],
    );
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        key: const ValueKey('app-update-dialog'),
        insetPadding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              return SizedBox(
                key: const ValueKey('app-update-content'),
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: height * .45),
                      child: SingleChildScrollView(child: header),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: math.min(400, height),
                          ),
                          child: SingleChildScrollView(
                            controller: _scroll,
                            child: _buildNotes(context),
                          ),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: height * .4),
                      child: SingleChildScrollView(child: actions),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
