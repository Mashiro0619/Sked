import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:sked/services/text_file_picker.dart';

class OversizedTextFilePicker extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => _OversizedTextFile();
}

class _OversizedTextFile extends XFile {
  _OversizedTextFile() : super('oversized.txt');

  @override
  Future<int> length() async => TextFilePicker.maxBytes + 1;
}
