import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

typedef StoreUrlLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

/// Store owns update eligibility and installation. Opening its product page is
/// an explicit user action, never an in-app assertion that an update exists.
class MicrosoftStoreUpdateService {
  const MicrosoftStoreUpdateService({
    this.productId = AppConfig.microsoftStoreId,
    this.urlLauncher,
  });

  final String productId;
  final StoreUrlLauncher? urlLauncher;

  bool get isEnabled => productId.isNotEmpty;

  Future<bool> openProductPage() async {
    // Fail closed rather than opening GitHub or accepting a caller-supplied URL.
    if (!RegExp(r'^[A-Z0-9]{12}$').hasMatch(productId)) return false;
    final urls = [
      Uri.parse('ms-windows-store://pdp/?ProductId=$productId'),
      Uri.https('apps.microsoft.com', '/detail/$productId'),
    ];
    for (final uri in urls) {
      try {
        final opened =
            await (urlLauncher?.call(uri, LaunchMode.externalApplication) ??
                launchUrl(uri, mode: LaunchMode.externalApplication));
        if (opened) return true;
      } catch (_) {
        // The Store protocol may be unavailable on a managed/stripped Windows
        // installation. Fall back to the same product on the official website.
      }
    }
    return false;
  }
}
