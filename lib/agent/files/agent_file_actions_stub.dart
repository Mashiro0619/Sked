bool get isWindows => false;
bool get isAndroid => false;

class AndroidOpenCopy {
  String get path => throw UnsupportedError('File opening is unavailable.');
  Future<void> discard() async {}
}

Future<AndroidOpenCopy> prepareAndroidOpenCopy(
  String source,
  String name,
) async => throw UnsupportedError('Android file opening is unavailable.');
