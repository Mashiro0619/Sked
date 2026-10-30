import 'provider_models.dart';

/// A bijection within the wire protocol's 64-character function-name limit.
/// Dots become double underscores; original underscores are escaped as _u.
abstract final class ToolNameCodec {
  static final _logical = RegExp(r'^[A-Za-z][A-Za-z0-9_.-]*$');
  static final _wire = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,63}$');

  static String encode(String name) {
    if (!_logical.hasMatch(name)) {
      throw const ProviderException(ProviderError.invalidRequest);
    }
    final encoded = name.replaceAll('_', '_u').replaceAll('.', '__');
    if (!_wire.hasMatch(encoded)) {
      throw const ProviderException(ProviderError.invalidRequest);
    }
    return encoded;
  }

  static String decode(String name) {
    if (!_wire.hasMatch(name)) {
      throw const ProviderException(ProviderError.unknownTool);
    }
    final result = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      if (name[i] != '_') {
        result.write(name[i]);
        continue;
      }
      if (++i == name.length || (name[i] != '_' && name[i] != 'u')) {
        throw const ProviderException(ProviderError.unknownTool);
      }
      result.write(name[i] == '_' ? '.' : '_');
    }
    return result.toString();
  }
}
