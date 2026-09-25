/// Removes a release-tag prefix and build metadata, retaining prerelease
/// identifiers. Empty or malformed values normalize to an empty string.
String normalizeUpdateVersion(String value) {
  return _UpdateVersion.tryParse(value)?.normalized ?? '';
}

/// Compares SemVer precedence. Build metadata never affects precedence.
/// Historical one- and two-component versions are padded with zeroes.
int compareUpdateVersions(String a, String b) {
  return _UpdateVersion.parse(a).compareTo(_UpdateVersion.parse(b));
}

bool isPrereleaseUpdateVersion(String value) {
  return _UpdateVersion.parse(value).prerelease.isNotEmpty;
}

class _UpdateVersion {
  const _UpdateVersion(this.normalized, this.core, this.prerelease);

  static final _pattern = RegExp(
    r'^([0-9]+(?:\.[0-9]+){0,2})(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );
  static final _numeric = RegExp(r'^[0-9]+$');

  final String normalized;
  final List<String> core;
  final List<String> prerelease;

  static _UpdateVersion parse(String value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw FormatException('Invalid update version: $value');
    }
    return parsed;
  }

  static _UpdateVersion? tryParse(String value) {
    var normalized = value.trim();
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    final match = _pattern.firstMatch(normalized);
    if (match == null) return null;
    final core = match.group(1)!.split('.');
    final prerelease = match.group(2)?.split('.') ?? const <String>[];
    // SemVer permits leading zeroes in build metadata, but not in numeric
    // core components or numeric prerelease identifiers.
    for (final part in [...core, ...prerelease]) {
      if (_numeric.hasMatch(part) && part.length > 1 && part.startsWith('0')) {
        return null;
      }
    }
    while (core.length < 3) {
      core.add('0');
    }
    return _UpdateVersion(normalized.split('+').first, core, prerelease);
  }

  int compareTo(_UpdateVersion other) {
    for (var index = 0; index < core.length; index++) {
      final comparison = _compareNumeric(core[index], other.core[index]);
      if (comparison != 0) return comparison;
    }
    if (prerelease.isEmpty || other.prerelease.isEmpty) {
      if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
      return prerelease.isEmpty ? 1 : -1;
    }
    final commonLength = prerelease.length < other.prerelease.length
        ? prerelease.length
        : other.prerelease.length;
    for (var index = 0; index < commonLength; index++) {
      final left = prerelease[index];
      final right = other.prerelease[index];
      final leftNumeric = _numeric.hasMatch(left);
      final rightNumeric = _numeric.hasMatch(right);
      final int comparison;
      if (leftNumeric && rightNumeric) {
        comparison = _compareNumeric(left, right);
      } else if (leftNumeric != rightNumeric) {
        comparison = leftNumeric ? -1 : 1;
      } else {
        comparison = left.compareTo(right);
      }
      if (comparison != 0) return comparison;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  // Compare decimal strings without int/double conversion, including on web.
  static int _compareNumeric(String left, String right) {
    final lengthComparison = left.length.compareTo(right.length);
    return lengthComparison != 0 ? lengthComparison : left.compareTo(right);
  }
}
