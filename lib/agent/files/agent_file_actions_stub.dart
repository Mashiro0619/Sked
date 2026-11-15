bool get isWindows => false;
bool get isAndroid => false;

class AgentOpenCopy {
  String get path => throw UnsupportedError('File opening is unavailable.');
  Future<void> discard() async {}
}

Future<AgentOpenCopy> prepareOpenCopy(String source, String name) async =>
    throw UnsupportedError('File viewing copies are unavailable.');
