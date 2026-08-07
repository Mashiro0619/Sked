/// Platform-specific layout for Sked's local persistence files.
///
/// Native callers receive the application-support directory implementation;
/// browser callers get a small unsupported stub because browsers persist data
/// through their own storage APIs rather than a filesystem directory.
library;

export 'app_storage_layout_stub.dart'
    if (dart.library.io) 'app_storage_layout_io.dart';
