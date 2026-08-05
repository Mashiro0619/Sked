import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

Future<bool> runUiCommandWithFeedback({
  required BuildContext context,
  required String debugLabel,
  required Future<void> Function() command,
}) async {
  final feedbackHost = UiCommandFeedbackHost._maybeOf(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failureMessage = AppLocalizations.of(context).saveFailedRetry;
  feedbackHost?._clearFailure();
  try {
    await command();
    return true;
  } catch (error, stackTrace) {
    debugPrint('$debugLabel failed: $error\n$stackTrace');
    if (feedbackHost?.mounted ?? false) {
      feedbackHost!._showFailure(failureMessage);
    } else if (messenger?.mounted ?? false) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failureMessage)));
    }
    return false;
  }
}

void showUiFailureFeedback({
  required BuildContext context,
  required String message,
  Duration snackBarDuration = const Duration(seconds: 2),
}) {
  final feedbackHost = UiCommandFeedbackHost._maybeOf(context);
  if (feedbackHost != null) {
    feedbackHost._showFailure(message);
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger?.mounted ?? false) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: snackBarDuration),
      );
  }
}

class UiCommandFeedbackHost extends StatefulWidget {
  const UiCommandFeedbackHost({super.key, required this.builder});

  final WidgetBuilder builder;

  static _UiCommandFeedbackHostState? _maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_UiCommandFeedbackHostState>();
  }

  @override
  State<UiCommandFeedbackHost> createState() => _UiCommandFeedbackHostState();
}

class _UiCommandFeedbackHostState extends State<UiCommandFeedbackHost> {
  String? _failureMessage;
  var _feedbackGeneration = 0;

  void _clearFailure() {
    if (_failureMessage == null || !mounted) return;
    setState(() => _failureMessage = null);
  }

  void _showFailure(String message) {
    if (!mounted) return;
    setState(() {
      _failureMessage = message;
      _feedbackGeneration += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final failureMessage = _failureMessage;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Builder(builder: widget.builder),
        if (failureMessage != null)
          PositionedDirectional(
            top: 12,
            start: 12,
            end: 12,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _UiCommandFailureNotice(
                  message: failureMessage,
                  generation: _feedbackGeneration,
                  onDismiss: _clearFailure,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _UiCommandFailureNotice extends StatelessWidget {
  const _UiCommandFailureNotice({
    required this.message,
    required this.generation,
    required this.onDismiss,
  });

  final String message;
  final int generation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('ui-command-failure-notice'),
      color: colors.errorContainer,
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        container: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: colors.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  key: ValueKey('ui-command-failure-live-region-$generation'),
                  liveRegion: true,
                  child: Text(
                    message,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('ui-command-failure-dismiss'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                color: colors.onErrorContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

mixin UiCommandRunner<T extends StatefulWidget> on State<T> {
  var _uiCommandBusy = false;

  @protected
  bool get uiCommandBusy => _uiCommandBusy;

  @protected
  Future<bool> runUiCommand({
    required String debugLabel,
    required Future<void> Function() command,
  }) async {
    if (_uiCommandBusy || !mounted) return false;

    setState(() => _uiCommandBusy = true);
    try {
      return await runUiCommandWithFeedback(
        context: context,
        debugLabel: debugLabel,
        command: command,
      );
    } finally {
      if (mounted) {
        setState(() => _uiCommandBusy = false);
      }
    }
  }
}

class UiCommandBusyIndicator extends StatelessWidget {
  const UiCommandBusyIndicator({
    super.key,
    required this.busy,
    this.semanticsKey,
  });

  final bool busy;
  final Key? semanticsKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: busy
          ? Semantics(
              key: semanticsKey,
              liveRegion: true,
              label: AppLocalizations.of(context).savingChanges,
              child: const ExcludeSemantics(child: LinearProgressIndicator()),
            )
          : const SizedBox.shrink(),
    );
  }
}
