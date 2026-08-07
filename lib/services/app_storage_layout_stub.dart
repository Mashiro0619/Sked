/// Browser fallback for the native storage-layout API.
///
/// Web persistence is implemented by SharedPreferences-backed stores. This
/// stub intentionally exposes no filesystem path so a browser build cannot
/// accidentally suggest that a native file exists.
class AppStorageLayout {
  const AppStorageLayout();

  Never directory() => throw UnsupportedError(
    'A browser build has no application-support directory',
  );
}

Never resolveAppStorageDirectory() => throw UnsupportedError(
  'A browser build has no application-support directory',
);
