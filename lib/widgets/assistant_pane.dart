import '../theme/sked_surface.dart';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/workspace_context_snapshot.dart';
import '../models/timetable_models.dart';

const aiLayoutPreviewEnabled = bool.fromEnvironment('SKED_AI_LAYOUT_PREVIEW');

class AssistantPaneController extends ChangeNotifier {
  final draft = TextEditingController();
  bool _open = false;
  bool get isOpen => _open;
  double width = 400;
  void toggle() => setOpen(!_open);
  void setOpen(bool value) {
    if (_open == value) return;
    _open = value;
    notifyListeners();
  }

  void resize(double value) {
    width = value.clamp(360, 640);
    notifyListeners();
  }

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }
}

class AssistantPaneScope extends InheritedWidget {
  const AssistantPaneScope({
    super.key,
    required this.controller,
    required this.enabled,
    required super.child,
    this.onToggle,
    this.interactive = true,
  });
  final VoidCallback? onToggle;
  final bool interactive;
  final AssistantPaneController controller;
  final bool enabled;
  static AssistantPaneScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AssistantPaneScope>();
  @override
  bool updateShouldNotify(AssistantPaneScope oldWidget) =>
      controller != oldWidget.controller ||
      enabled != oldWidget.enabled ||
      interactive != oldWidget.interactive;
}

class AssistantPaneToggle extends StatelessWidget {
  const AssistantPaneToggle({super.key});
  @override
  Widget build(BuildContext context) {
    final scope = AssistantPaneScope.of(context);
    if (scope == null || !scope.enabled) return const SizedBox.shrink();
    return IconButton(
      key: const ValueKey('assistant-toggle'),
      tooltip: AppLocalizations.of(context).assistantLayoutPreview,
      icon: const Icon(Icons.chat_bubble_outline),
      onPressed: scope.interactive
          ? (scope.onToggle ?? scope.controller.toggle)
          : null,
    );
  }
}

class AssistantPreviewPane extends StatelessWidget {
  const AssistantPreviewPane({
    super.key,
    required this.controller,
    this.snapshot,
    this.onClose,
    this.closeEnabled = true,
  });
  final AssistantPaneController controller;
  final WorkspaceContextSnapshot? snapshot;
  final VoidCallback? onClose;
  final bool closeEnabled;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SkedSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.assistantLayoutPreview,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: closeEnabled
                      ? (onClose ?? () => controller.setOpen(false))
                      : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (snapshot case final data?) ...[
                    Text(
                      data.mode == AppMode.student
                          ? l.studentTimetable
                          : l.generalSchedule,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (data.date case final date?)
                      Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(date),
                      ),
                    if (data.selectionId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(l.assistantSelectionContext),
                      ),
                    const SizedBox(height: 24),
                  ],
                  const Icon(Icons.chat_bubble_outline, size: 28),
                  const SizedBox(height: 12),
                  Text(
                    l.assistantPreviewDescription,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey('assistant-draft'),
              controller: controller.draft,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l.assistantDraftLabel,
                helperText: l.assistantPreviewNoSend,
                helperMaxLines: 3,
                suffixIcon: const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.arrow_upward),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
