/// A global presentation preference, independent of any panel's open state.
enum WorkspacePanelDisplayMode {
  overlay('overlay'),
  sideBySide('sideBySide'),
  automatic('automatic');

  const WorkspacePanelDisplayMode(this.value);
  final String value;

  static WorkspacePanelDisplayMode fromJson(Object? value) {
    for (final mode in values) {
      if (mode.value == value) return mode;
    }
    throw const FormatException('Workspace panel display mode is invalid.');
  }
}
