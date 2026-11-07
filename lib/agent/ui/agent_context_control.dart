import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../widgets/sked_popup_menu.dart';
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
  const AgentContextIndicator({
    super.key,
    required this.usage,
    this.enabled = true,
  });
  final AgentContextUsage? usage;
  final bool enabled;

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
    final status = compacting
        ? l.agentCompactingContext
        : queued
        ? l.agentCompactionQueued
        : failed
        ? l.agentOperationFailed
        : null;
    final utilization = usedPercent == null || remainingPercent == null
        ? null
        : l.agentContextUtilization('$usedPercent', '$remainingPercent');
    final tokenUsage = knownWindow
        ? '${l.agentContextEstimated}: ${l.agentContextTokenUsage(knownEstimate ? '$estimated' : l.agentContextUnset, '$window')}'
        : '${l.agentContextEstimated}: ${knownEstimate ? '$estimated Token' : l.agentContextUnset}';
    final capacity = knownWindow
        ? null
        : '${l.agentContextWindow}: ${l.agentContextUnset}';
    final description = [
      l.agentContextTitle,
      ?status,
      ?utilization,
      tokenUsage,
      ?capacity,
    ].join('\n');
    final desktop = SkedMenuStyle.of(context).desktop;
    final motion = SkedMotionPolicy.of(context);
    final theme = Theme.of(context);
    final bounds = SkedMenuStyle.availableRectOf(context);
    final indicator = SizedBox(
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
                    padding: EdgeInsets.zero,
                    trackGap: 0,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: .45),
                  ),
          ),
        ),
      ),
    );
    final active =
        enabled &&
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false;
    // Keep the overlay traversal anchor in its own semantics container.
    return Semantics(
      key: const ValueKey('agent-context-indicator'),
      container: true,
      child: !active
          ? indicator
          : RawTooltip(
              semanticsTooltip: description,
              hoverDelay: const Duration(milliseconds: 250),
              dismissDelay: const Duration(milliseconds: 200),
              touchDelay: const Duration(seconds: 4),
              triggerMode: TooltipTriggerMode.tap,
              animationStyle: AnimationStyle(
                duration: motion.effects(SkedMotionSpeed.fast),
                reverseDuration: motion.effects(SkedMotionSpeed.fast),
              ),
              positionDelegate: (position) {
                final size = position.tooltipSize;
                final top =
                    position.target.dy -
                    position.targetSize.height / 2 -
                    6 -
                    size.height;
                final y = top >= bounds.top
                    ? top
                    : position.target.dy + position.targetSize.height / 2 + 6;
                return Offset(
                  (position.target.dx - size.width / 2).clamp(
                    bounds.left,
                    math.max(bounds.left, bounds.right - size.width),
                  ),
                  y.clamp(
                    bounds.top,
                    math.max(bounds.top, bounds.bottom - size.height),
                  ),
                );
              },
              tooltipBuilder: (context, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.min(272, bounds.width),
                      maxHeight: bounds.height,
                    ),
                    child: Material(
                      key: const ValueKey('agent-context-card'),
                      color: theme.colorScheme.surfaceContainerHigh,
                      elevation: 3,
                      shadowColor: theme.colorScheme.shadow.withValues(
                        alpha: .16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.agentContextTitle,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            if (utilization != null) ...[
                              Text(
                                utilization,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              tokenUsage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (capacity != null)
                              Text(
                                capacity,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (status != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                status,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: failed
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: indicator,
            ),
    );
  }
}
