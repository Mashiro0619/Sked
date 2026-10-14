import 'package:flutter/foundation.dart';

/// Publishes a domain only when its references, scalar settings or local UI
/// revisions change. Publication never encodes data or expands occurrences.
abstract class ObservableViewState extends ChangeNotifier {
  Object? _publishedKey;
  var _initialized = false;
  var _closed = false;

  @protected
  Object get publicationKey;

  @protected
  void initializePublication() {
    _publishedKey = publicationKey;
    _initialized = true;
  }

  void publishChanges() {
    if (_closed) return;
    final current = publicationKey;
    if (_initialized && current == _publishedKey) return;
    _publishedKey = current;
    _initialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

/// Coordinates settled view publication without exposing a global Listenable.
/// Consumers subscribe to the domain views they need.
class AppViewUpdates {
  AppViewUpdates(Iterable<ObservableViewState> views)
    : _views = List.unmodifiable(views);

  final List<ObservableViewState> _views;

  void publish() {
    for (final view in _views) {
      view.publishChanges();
    }
  }
}
