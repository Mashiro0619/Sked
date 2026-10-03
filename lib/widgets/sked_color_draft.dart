/// Mutable task-local color draft. Raw values can be theme slots; resolving a
/// preview never changes the value that will be persisted. No route or storage.
class SkedColorDraft {
  SkedColorDraft(this.originalValue) : value = originalValue;
  final int originalValue;
  int value;
  bool validHex = true;
  int inputRevision = 0;
  bool get changed => value != originalValue;
  int preview(int Function(int) resolve) => resolve(value);
  void select(int rawValue) {
    value = rawValue;
    validHex = true;
    inputRevision++;
  }

  void setValidity(bool valid) => validHex = valid;

  /// Returns null without modifying the last valid color on malformed input.
  static int? parseHex(String input) {
    final hex = input.trim().replaceFirst(RegExp(r'^#'), '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    return 0xff000000 | int.parse(hex, radix: 16);
  }
}
