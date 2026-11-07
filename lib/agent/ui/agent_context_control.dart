import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../widgets/sked_popup_menu.dart';
import '../../widgets/sked_tooltip.dart';
import '../../theme/sked_menu_style.dart';
import 'agent_ui_delegate.dart';

class AgentContextControl extends StatelessWidget {
  const AgentContextControl({
    super.key,
    required this.usage,
    this.onCompact,
    this.moreMenu = false,
    this.attachLabel,
    this.onAttach,
    this.enabled = true,
    this.canAttach = true,
    this.canCompact = true,
  });
  final AgentContextUsage? usage;
  final VoidCallback? onCompact;
  final bool moreMenu;
  final String? attachLabel;
  final VoidCallback? onAttach;
  final bool enabled;
  final bool canAttach;
  final bool canCompact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final estimated = usage?.estimatedTokens;
    final window = usage?.maxContextTokens;
    final compacting = usage?.isCompacting == true;
    final queued = usage?.isCompactionQueued == true;
    final failed = usage?.errorMessage != null;
    final description =
        '${l.agentContextEstimated}: ${estimated ?? l.agentContextUnset}'
        ' / ${window ?? l.agentContextUnset} Token';
    return SkedPopupMenuButton<String>(
      key: ValueKey(moreMenu ? 'agent-composer-more' : 'agent-context-control'),
      padding: EdgeInsets.all(SkedMenuStyle.of(context).desktop ? 6 : 8),
      enabled: enabled && (moreMenu || onCompact != null),
      tooltip: moreMenu
          ? l.more
          : compacting
          ? l.agentCompactingContext
          : queued
          ? l.agentCompactionQueued
          : failed
          ? l.agentOperationFailed
          : description,
      icon: moreMenu
          ? const Icon(Icons.add_rounded)
          : SizedBox.square(
              dimension: 18,
              child: compacting
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : failed
                  ? Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    )
                  : window != null && estimated != null
                  ? CircularProgressIndicator(
                      value: (estimated / window).clamp(0.0, 1.0),
                      strokeWidth: 2,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .outlineVariant,
                    )
                  : const Icon(Icons.data_usage_rounded, size: 18),
            ),
      onSelected: (value) {
        if (value == 'attach') onAttach?.call();
        if (value == 'compact') onCompact?.call();
      },
      itemBuilder: (context) => [
        if (attachLabel case final label?) ...[
          PopupMenuItem<String>(
            key: const ValueKey('agent-attach-file'),
            value: 'attach',
            enabled: onAttach != null && canAttach,
            child: Text(label),
          ),
          const PopupMenuDivider(),
        ],
        if (usage?.modelId case final model?)
          PopupMenuItem<String>(
            enabled: false,
            child: Text('${l.agentModel}: $model'),
          ),
        PopupMenuItem<String>(enabled: false, child: Text(description)),
        if (usage?.reportedInputTokens case final reported?)
          PopupMenuItem<String>(
            enabled: false,
            child: Text('${l.agentContextReported}: $reported Token'),
          ),
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            '${l.agentContextThreshold}: '
            '${usage?.autoCompactAtTokens ?? l.agentContextUnset} Token',
          ),
        ),
        if (usage?.errorMessage != null)
          PopupMenuItem<String>(
            enabled: false,
            child: Text(l.agentOperationFailed),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          key: const ValueKey('agent-compact-context'),
          value: 'compact',
          enabled: onCompact != null && canCompact && !compacting && !queued,
          child: Text(
            compacting
                ? l.agentCompactingContext
                : queued
                ? l.agentCompactionQueued
                : l.agentCompactContext,
          ),
        ),
      ],
    );
  }
}

/// The current request estimate stays beside the model; its actions share More.
class AgentContextIndicator extends StatelessWidget {
  const AgentContextIndicator({super.key, required this.usage});
  final AgentContextUsage? usage;

  @override
  Widget build(BuildContext context) {
    final current = usage;
    final l = AppLocalizations.of(context);
    final estimated = current?.estimatedTokens;
    final window = current?.maxContextTokens;
    final knownEstimate = estimated != null && estimated >= 0;
    final knownWindow = window != null && window > 0;
    final ratio =
        estimated != null && estimated >= 0 && window != null && window > 0
        ? estimated / window
        : null;
    final usedPercent = ratio == null ? null : (ratio * 100).round();
    final remainingPercent = usedPercent == null
        ? null
        : (100 - usedPercent).clamp(0, 100);
    final compacting = current?.isCompacting == true;
    final queued = current?.isCompactionQueued == true;
    final failed = current?.errorMessage != null;
    final tooltip = [
      l.agentContextTitle,
      if (compacting)
        l.agentCompactingContext
      else if (queued)
        l.agentCompactionQueued
      else if (failed)
        l.agentOperationFailed,
      if (usedPercent != null && remainingPercent != null)
        l.agentContextUtilization('$usedPercent', '$remainingPercent'),
      '${l.agentContextEstimated}: '
          '${l.agentContextTokenUsage(knownEstimate ? '$estimated' : l.agentContextUnset, knownWindow ? '$window' : l.agentContextUnset)}',
    ].join('\n');
    final desktop = SkedMenuStyle.of(context).desktop;
    final motion = SkedMotionPolicy.of(context);
    return SkedTooltip(
      key: const ValueKey('agent-context-indicator'),
      message: tooltip,
      preferBelow: false,
      verticalOffset: 8,
      textAlign: TextAlign.center,
      child: SizedBox(
        width: desktop ? 24 : 32,
        height: desktop ? 32 : 48,
        child: Center(
          child: ExcludeSemantics(
            child: SizedBox.square(
              key: const ValueKey('agent-context-ring'),
              dimension: 14,
              child: failed && !compacting
                  ? Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.error,
                    )
                  : CircularProgressIndicator(
                      value: compacting
                          ? (motion.spatialAnimationsEnabled ? null : 0.75)
                          : (ratio ?? 0).clamp(0.0, 1.0),
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .outlineVariant,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
