import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import 'microsoft_store_update_service.dart';

enum UpdateChannel { github, googlePlay, microsoftStore }

/// Installation metadata chooses the destination, never the version feed.
class UpdateDistribution {
  const UpdateDistribution(
    this.channel, {
    this.urlLauncher,
    this.storeService = const MicrosoftStoreUpdateService(
      productId: '9NWRR6ZP6K6T',
    ),
  });

  final UpdateChannel channel;
  final StoreUrlLauncher? urlLauncher;
  final MicrosoftStoreUpdateService storeService;
  bool get isStore => channel != UpdateChannel.github;

  String label(AppLocalizations l10n) => switch (channel) {
    UpdateChannel.github => 'Github',
    UpdateChannel.googlePlay => 'Google Play',
    UpdateChannel.microsoftStore => l10n.microsoftStoreUpdateButton,
  };

  static Future<UpdateDistribution> resolve({
    TargetPlatform? platform,
    String channel = AppConfig.distributionChannel,
    MicrosoftStoreUpdateService storeService =
        const MicrosoftStoreUpdateService(),
    Future<PackageInfo> Function()? packageInfoLoader,
    StoreUrlLauncher? urlLauncher,
  }) async {
    final target = platform ?? defaultTargetPlatform;
    if (!kIsWeb &&
        target == TargetPlatform.windows &&
        (channel == 'microsoft-store' || storeService.isEnabled)) {
      return UpdateDistribution(
        UpdateChannel.microsoftStore,
        storeService: storeService.isEnabled
            ? storeService
            : MicrosoftStoreUpdateService(
                productId: '9NWRR6ZP6K6T',
                urlLauncher: urlLauncher,
              ),
      );
    }
    if (!kIsWeb && target == TargetPlatform.android) {
      if (channel == 'google-play') {
        return UpdateDistribution(
          UpdateChannel.googlePlay,
          urlLauncher: urlLauncher,
        );
      }
      if (channel != 'github') {
        try {
          final info = await (packageInfoLoader ?? PackageInfo.fromPlatform)();
          if (info.installerStore == 'com.android.vending') {
            return UpdateDistribution(
              UpdateChannel.googlePlay,
              urlLauncher: urlLauncher,
            );
          }
        } catch (_) {
          // Unknown installation source is not evidence of a Store install.
        }
      }
    }
    return UpdateDistribution(UpdateChannel.github, urlLauncher: urlLauncher);
  }

  Future<bool> open(String releaseUrl) async {
    if (channel == UpdateChannel.microsoftStore) {
      return storeService.openProductPage();
    }
    final urls = channel == UpdateChannel.googlePlay
        ? [
            Uri.parse('market://details?id=com.mashiro.sked'),
            Uri.https('play.google.com', '/store/apps/details', {
              'id': 'com.mashiro.sked',
            }),
          ]
        : [Uri.tryParse(releaseUrl)];
    for (final uri in urls) {
      if (uri == null ||
          (uri.scheme != 'https' &&
              !(channel == UpdateChannel.googlePlay &&
                  uri.scheme == 'market')) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        continue;
      }
      try {
        if (await (urlLauncher?.call(uri, LaunchMode.externalApplication) ??
            launchUrl(uri, mode: LaunchMode.externalApplication))) {
          return true;
        }
      } catch (_) {
        // Fall back within the same store, never to a different installer.
      }
    }
    return false;
  }
}
