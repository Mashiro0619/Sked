import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_localizations.dart';
import '../controllers/app_data_maintenance.dart';
import 'workspace_view_panel.dart';

Future<bool> runUiCommandWithFeedback({
  required BuildContext context,
  required String debugLabel,
  required Future<void> Function() command,
}) async {
  final feedbackHost = UiCommandFeedbackHost._maybeOf(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context);
  feedbackHost?._clearFailure();
  try {
    await command();
    return true;
  } catch (error, stackTrace) {
    debugPrint('$debugLabel failed: $error\n$stackTrace');
    final failureMessage = error is AppBackupRestoreInProgressException
        ? l10n.backupRestoreInProgressMessage
        : l10n.saveFailedRetry;
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
  final _contentKey = GlobalKey(debugLabel: 'ui-command-feedback-content');
  Object? _inlineOwner;
  String? _failureMessage;
  var _feedbackGeneration = 0;

  bool _attachInline(Object owner) {
    if (_inlineOwner != null && !identical(_inlineOwner, owner)) return false;
    _inlineOwner = owner;
    return true;
  }

  void _detachInline(Object owner) {
    if (!identical(_inlineOwner, owner)) return;
    _inlineOwner = null;
    if (_failureMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _inlineOwner == null) setState(() {});
      });
    }
  }

  Widget? _notice() => _failureMessage == null
      ? null
      : _UiCommandFailureNotice(
          message: _failureMessage!,
          generation: _feedbackGeneration,
          onDismiss: _clearFailure,
        );

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
    final failureMessage = _inlineOwner == null ? _failureMessage : null;
    final view = WorkspaceViewTaskScope.maybeOf(context);
    return _UiCommandFeedbackScope(
      host: this,
      generation: _feedbackGeneration,
      failureMessage: _failureMessage,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: _FeedbackContentSize(
          // A route keeps full viewport constraints even for a short view. The
          // loose child measures its content and notice, not that route height.
          // Keep reporting after dismissal so the floating surface shrinks back.
          onHeight: view?.enabled == true ? view!.onContentHeight : null,
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error visibility never changes the parent or identity of a draft.
                // Put feedback after content so floating editors retain their anchor
                // and existing controls do not jump beneath a newly inserted banner.
                if (constraints.hasBoundedHeight)
                  Flexible(
                    key: const ValueKey('ui-command-feedback-content-flex'),
                    fit: FlexFit.loose,
                    child: KeyedSubtree(
                      key: _contentKey,
                      child: Builder(builder: widget.builder),
                    ),
                  )
                else
                  KeyedSubtree(
                    key: _contentKey,
                    child: Builder(builder: widget.builder),
                  ),
                if (failureMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 560,
                          maxHeight: constraints.hasBoundedHeight
                              ? constraints.maxHeight * .4
                              : double.infinity,
                        ),
                        child: _notice(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UiCommandFeedbackScope extends InheritedWidget {
  const _UiCommandFeedbackScope({
    required this.host,
    required this.generation,
    required this.failureMessage,
    required super.child,
  });
  final _UiCommandFeedbackHostState host;
  final int generation;
  final String? failureMessage;

  @override
  bool updateShouldNotify(_UiCommandFeedbackScope oldWidget) =>
      host != oldWidget.host ||
      generation != oldWidget.generation ||
      failureMessage != oldWidget.failureMessage;
}

/// Short dialogs own their feedback area inside their actual surface. The
/// surrounding route can occupy the viewport, so an external sibling would
/// otherwise place its notice outside the dialog or change its floating anchor.
class UiCommandInlineFeedback extends StatefulWidget {
  const UiCommandInlineFeedback({
    super.key,
    required this.builder,
    this.preserveHeight = false,
    this.enabled = true,
  });
  final Widget Function(BuildContext context, Widget? notice) builder;
  final bool preserveHeight;
  final bool enabled;

  @override
  State<UiCommandInlineFeedback> createState() =>
      _UiCommandInlineFeedbackState();
}

class _UiCommandInlineFeedbackState extends State<UiCommandInlineFeedback> {
  _UiCommandFeedbackHostState? _host;
  bool _ownsNotice = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context
        .dependOnInheritedWidgetOfExactType<_UiCommandFeedbackScope>();
    final host = scope?.host;
    if (!identical(host, _host)) {
      _host?._detachInline(this);
      _host = host;
      _ownsNotice = widget.enabled && (host?._attachInline(this) ?? false);
    }
  }

  @override
  void didUpdateWidget(UiCommandInlineFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      _ownsNotice = _host?._attachInline(this) ?? false;
    } else {
      _host?._detachInline(this);
      _ownsNotice = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = _ownsNotice ? _host?._notice() : null;
    return _InlineFeedbackHeight(
      preserve: widget.preserveHeight && notice != null,
      child: widget.builder(context, notice),
    );
  }

  @override
  void dispose() {
    _host?._detachInline(this);
    super.dispose();
  }
}

class _InlineFeedbackHeight extends SingleChildRenderObjectWidget {
  const _InlineFeedbackHeight({required this.preserve, required super.child});
  final bool preserve;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderInlineFeedbackHeight(preserve);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderInlineFeedbackHeight renderObject,
  ) {
    renderObject.preserve = preserve;
  }
}

class _RenderInlineFeedbackHeight extends RenderProxyBox {
  _RenderInlineFeedbackHeight(this._preserve);
  bool _preserve;
  double? _naturalHeight;
  set preserve(bool value) {
    if (_preserve == value) return;
    _preserve = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final height = _preserve ? _naturalHeight : null;
    final childConstraints = height == null
        ? constraints
        : constraints.copyWith(
            minHeight: constraints.constrainHeight(height),
            maxHeight: constraints.constrainHeight(height),
          );
    child!.layout(childConstraints, parentUsesSize: true);
    size = constraints.constrain(child!.size);
    if (!_preserve) _naturalHeight = size.height;
  }
}

/// Viewing tasks report their content size from inside the editor. Include the
/// additional inline notice so the outer paint/hit-test viewport stays aligned.
class _FeedbackContentSize extends SingleChildRenderObjectWidget {
  const _FeedbackContentSize({required this.onHeight, required super.child});
  final ValueChanged<double>? onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFeedbackContentSize(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFeedbackContentSize renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderFeedbackContentSize extends RenderProxyBox {
  _RenderFeedbackContentSize(this._onHeight);
  ValueChanged<double>? _onHeight;
  set onHeight(ValueChanged<double>? value) {
    if (_onHeight == value) return;
    _onHeight = value;
    _reportedHeight = null;
    markNeedsLayout();
  }

  double? _reportedHeight;

  @override
  void performLayout() {
    super.performLayout();
    if (_reportedHeight == size.height) return;
    _reportedHeight = size.height;
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && _reportedHeight == height) _onHeight?.call(height);
    });
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
                child: SingleChildScrollView(
                  key: const ValueKey('ui-command-failure-message-scroll'),
                  child: Semantics(
                    key: ValueKey('ui-command-failure-live-region-$generation'),
                    liveRegion: true,
                    child: Text(
                      message,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
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

class UiCommandBusyIndicator extends StatefulWidget {
  const UiCommandBusyIndicator({
    super.key,
    required this.busy,
    this.semanticsKey,
    this.showDelay = Duration.zero,
  });

  final bool busy;
  final Key? semanticsKey;
  final Duration showDelay;

  @override
  State<UiCommandBusyIndicator> createState() => _UiCommandBusyIndicatorState();
}

class _UiCommandBusyIndicatorState extends State<UiCommandBusyIndicator> {
  Timer? _showTimer;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant UiCommandBusyIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy ||
        oldWidget.showDelay != widget.showDelay) {
      _syncVisibility();
    }
  }

  void _syncVisibility() {
    _showTimer?.cancel();
    _showTimer = null;
    if (!widget.busy) {
      _visible = false;
      return;
    }
    if (widget.showDelay <= Duration.zero) {
      _visible = true;
      return;
    }
    _visible = false;
    _showTimer = Timer(widget.showDelay, () {
      if (mounted && widget.busy) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: _visible
          ? Semantics(
              key: widget.semanticsKey,
              liveRegion: true,
              label: AppLocalizations.of(context).savingChanges,
              child: const ExcludeSemantics(child: LinearProgressIndicator()),
            )
          : const SizedBox.shrink(),
    );
  }
}
