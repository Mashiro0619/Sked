import 'constants.dart';

/// One source of truth for toolbar placement and its overflow recovery entries.
/// Hidden essential actions always move to More, regardless of the shortcut
/// hiding policy. More itself may never hide those recovery entries.
class MobileToolbarLayout {
  MobileToolbarLayout._(this.toolbarIds, this.menuIds, this.moreRequired);
  final List<String> toolbarIds;
  final List<String> menuIds;
  final bool moreRequired;

  factory MobileToolbarLayout.resolve({
    required List<String> order,
    required List<String> hiddenIds,
    required String hiddenBehavior,
    required List<String> defaultOrder,
    required Set<String> availableIds,
    bool hasFixedMenuItems = false,
  }) {
    final normalized = normalizeToolbarNavigationOrder(
      order,
      knownIds: defaultOrder,
      defaultOrder: defaultOrder,
    );
    final hidden = hiddenIds.toSet();
    final essential = {'settings', 'workspace'}.intersection(availableIds);
    final requiredMore = hasFixedMenuItems || essential.any(hidden.contains);
    final revealOrdinary =
        hiddenBehavior == toolbarHiddenItemsBehaviorMore &&
        !hidden.contains('more');
    final menu = [
      for (final id in normalized)
        if (id != 'more' &&
            availableIds.contains(id) &&
            hidden.contains(id) &&
            (essential.contains(id) || revealOrdinary))
          id,
    ];
    final showMore = requiredMore || menu.isNotEmpty;
    return MobileToolbarLayout._(
      [
        for (final id in normalized)
          if (id == 'more'
              ? showMore
              : availableIds.contains(id) && !hidden.contains(id))
            id,
      ],
      menu,
      requiredMore,
    );
  }
}
