import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A single header, scrollable content and fixed command area. Hosts supply
/// geometry and surfaces; business widgets supply only their task contents.
class SkedTaskBody extends StatelessWidget {
  const SkedTaskBody({
    super.key,
    required this.header,
    required this.child,
    this.footer,
    this.status,
    this.fillHeight = false,
    this.divider = false,
    this.headerDivider = false,
    this.headerHeightFraction = .3,
    this.bodyKey,
    this.viewportKey,
    this.headerPadding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.footerPadding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final Widget header, child;
  final Widget? footer, status;
  final bool fillHeight, divider, headerDivider;
  final double headerHeightFraction;
  final Key? bodyKey, viewportKey;
  final EdgeInsetsGeometry headerPadding, contentPadding, footerPadding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final shortViewport = constraints.maxHeight < 240;
      final padding = footerPadding.resolve(Directionality.of(context));
      final compactFooterPadding = constraints.maxHeight < 160
          ? EdgeInsets.fromLTRB(
              padding.left,
              constraints.maxHeight < 80 ? 0 : 4,
              padding.right,
              constraints.maxHeight < 80 ? 0 : 4,
            )
          : padding;
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final minimumFooter =
          math.max(48.0, 20 * textScale + 16) + compactFooterPadding.vertical;
      final footerBudget = math.min(
        math.max(constraints.maxHeight * .35, minimumFooter),
        math.max(
          0.0,
          constraints.maxHeight - (constraints.maxHeight >= 80 ? 24 : 0),
        ),
      );
      return Column(
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!shortViewport) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * headerHeightFraction,
              ),
              child: SingleChildScrollView(
                child: Padding(padding: headerPadding, child: header),
              ),
            ),
            if (headerDivider) const Divider(height: 1),
          ],
          ?status,
          Flexible(
            key: const ValueKey('sked-task-body-slot'),
            fit: fillHeight ? FlexFit.tight : FlexFit.loose,
            child: SizedBox(
              key: viewportKey,
              child: _FocusedTaskViewport(
                scrollKey: bodyKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (shortViewport) ...[
                      Padding(padding: headerPadding, child: header),
                      if (headerDivider) const Divider(height: 1),
                    ],
                    // A stable slot keeps field state when the short-window
                    // fallback moves the title into this same scroll viewport.
                    Padding(
                      key: const ValueKey('sked-task-content'),
                      padding: contentPadding,
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (footer != null) ...[
            if (divider) const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: footerBudget),
              child: SingleChildScrollView(
                child: Padding(padding: compactFooterPadding, child: footer),
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// A very short IME viewport cannot satisfy EditableText's usual 20dp scroll
/// padding plus selection-handle clearance. Reveal the actual caret after the
/// viewport resizes instead, without replacing the field or its controller.
class _FocusedTaskViewport extends StatefulWidget {
  const _FocusedTaskViewport({required this.child, this.scrollKey});
  final Widget child;
  final Key? scrollKey;

  @override
  State<_FocusedTaskViewport> createState() => _FocusedTaskViewportState();
}

class _FocusedTaskViewportState extends State<_FocusedTaskViewport> {
  double? _height;
  bool _revealPending = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_revealCaret);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_revealCaret);
    super.dispose();
  }

  void _revealCaret() {
    if (!mounted || (_height ?? double.infinity) >= 144 || _revealPending) {
      return;
    }
    _revealPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealPending = false;
      if (!mounted) return;
      EditableTextState? focused;
      void visit(Element element) {
        if (element case StatefulElement(widget: final EditableText input)) {
          if (input.focusNode.hasFocus && input.controller.selection.isValid) {
            focused = element.state as EditableTextState;
          }
        }
        if (focused == null) element.visitChildren(visit);
      }

      context.visitChildElements(visit);
      final field = focused;
      if (field != null && field.mounted) {
        field.bringIntoView(field.widget.controller.selection.extent);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (_height != bounds.maxHeight) {
        _height = bounds.maxHeight;
        _revealCaret();
      }
      return SingleChildScrollView(key: widget.scrollKey, child: widget.child);
    },
  );
}
