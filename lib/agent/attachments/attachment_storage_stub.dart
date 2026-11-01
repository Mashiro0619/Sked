import 'attachment_storage.dart';
import 'attachment_models.dart';

class PlatformAttachmentStorage extends AttachmentStorage {
  PlatformAttachmentStorage() : super.base();
  Never _unsupported() =>
      throw const AttachmentException(AttachmentError.unavailable);
  @override
  Future<void> write(String id, Stream<List<int>> bytes) async =>
      _unsupported();
  @override
  Stream<List<int>> read(String id) async* {
    _unsupported();
  }

  @override
  Future<Set<String>> ids() async => _unsupported();
  @override
  Future<void> delete(String id) async => _unsupported();
}
