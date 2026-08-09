import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'theme/sked_expressive_theme.dart';
import 'l10n/app_locale.dart';
import 'l10n/app_localizations.dart';
import 'models/timetable_models.dart';
import 'providers/timetable_provider.dart';
import 'screens/app_home_screen.dart';
import 'services/app_instance_lease.dart';
import 'widgets/sked_expressive_loading_indicator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _registerLicenses();
  runApp(AppBootstrap());
}

void _registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final notice = await rootBundle.loadString('NOTICE');
    yield LicenseEntryWithLineBreaks(['App icon assets'], notice);
  });
}

typedef TimetableProviderFactory = TimetableProvider Function();

enum _AppBootstrapStatus { acquiring, ready, blocked, failed }

class AppBootstrap extends StatefulWidget {
  AppBootstrap({
    super.key,
    AppInstanceLease? lease,
    TimetableProviderFactory? providerFactory,
  }) : lease = lease ?? AppInstanceLease(),
       providerFactory = providerFactory ?? TimetableProvider.new;

  final AppInstanceLease lease;
  final TimetableProviderFactory providerFactory;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final AppInstanceLease _lease;
  late final TimetableProviderFactory _providerFactory;
  var _status = _AppBootstrapStatus.acquiring;
  TimetableProvider? _provider;
  Future<void>? _providerLoad;
  Future<void>? _acquireOperation;
  var _attemptInProgress = false;
  var _leaseOwned = false;

  @override
  void initState() {
    super.initState();
    _lease = widget.lease;
    _providerFactory = widget.providerFactory;
    _startLeaseAcquisition();
  }

  void _startLeaseAcquisition() {
    if (_attemptInProgress || _provider != null) return;
    final operation = _acquireLease();
    _acquireOperation = operation;
    unawaited(operation);
  }

  Future<void> _acquireLease() async {
    if (_attemptInProgress || _provider != null) return;
    _attemptInProgress = true;
    if (mounted && _status != _AppBootstrapStatus.acquiring) {
      setState(() => _status = _AppBootstrapStatus.acquiring);
    }

    try {
      final acquired = await _lease.tryAcquire();
      if (acquired) {
        _leaseOwned = true;
      }
      if (!mounted) {
        return;
      }
      if (!acquired) {
        setState(() => _status = _AppBootstrapStatus.blocked);
        return;
      }

      try {
        final provider = _providerFactory();
        _provider = provider;
        final load = provider.load();
        _providerLoad = load;
        unawaited(
          load.then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                'Provider load failed unexpectedly: $error\n$stackTrace',
              );
            },
          ),
        );
        setState(() => _status = _AppBootstrapStatus.ready);
      } catch (error, stackTrace) {
        debugPrint('App provider creation failed: $error\n$stackTrace');
        await _releaseLeaseIfOwned();
        if (mounted) {
          setState(() => _status = _AppBootstrapStatus.failed);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('App instance lease acquisition failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _status = _AppBootstrapStatus.failed);
      }
    } finally {
      _attemptInProgress = false;
      if (mounted && _status != _AppBootstrapStatus.ready) {
        setState(() {});
      }
    }
  }

  Future<void> _releaseLeaseIfOwned() async {
    if (!_leaseOwned) return;
    _leaseOwned = false;
    await _lease.release();
  }

  @override
  void dispose() {
    final shutdown = _shutdownResources();
    unawaited(shutdown);
    super.dispose();
  }

  Future<void> _shutdownResources() async {
    final acquisition = _acquireOperation;
    if (acquisition != null) {
      try {
        await acquisition;
      } catch (_) {
        // Acquisition already mapped the failure to the bootstrap gate.
      }
    }

    try {
      final provider = _provider;
      final load = _providerLoad;
      if (load != null) {
        try {
          await load;
        } catch (error, stackTrace) {
          debugPrint(
            'Provider load ended during shutdown: $error\n$stackTrace',
          );
        }
      }
      if (provider != null) {
        try {
          await provider.quiesceForShutdown();
        } finally {
          provider.dispose();
        }
      }
    } catch (error, stackTrace) {
      debugPrint('App provider shutdown failed: $error\n$stackTrace');
    } finally {
      try {
        await _releaseLeaseIfOwned();
      } catch (error, stackTrace) {
        debugPrint('App instance lease release failed: $error\n$stackTrace');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (_status == _AppBootstrapStatus.ready && provider != null) {
      return MyApp(provider: provider);
    }
    return _AppBootstrapGate(
      status: _status,
      onRetry: _attemptInProgress ? null : _startLeaseAcquisition,
    );
  }
}

class _AppBootstrapGate extends StatelessWidget {
  const _AppBootstrapGate({required this.status, required this.onRetry});

  final _AppBootstrapStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // The bootstrap gate has no loaded user locale yet. Keep this transient
      // screen deterministic and LTR until the persisted locale is available.
      locale: const Locale('en'),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildAppTheme(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
        themeColorMode: themeColorModeSingle,
        colorfulUiColorValues: const {},
      ),
      darkTheme: buildAppTheme(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
        themeColorMode: themeColorModeSingle,
        colorfulUiColorValues: const {},
      ),
      home: Builder(
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          final acquiring = status == _AppBootstrapStatus.acquiring;
          final failed = status == _AppBootstrapStatus.failed;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            acquiring
                                ? Icons.hourglass_top_outlined
                                : failed
                                ? Icons.storage_outlined
                                : Icons.copy_all_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          if (acquiring)
                            const SkedExpressiveLoadingIndicator()
                          else ...[
                            Text(
                              failed
                                  ? l10n.appInstanceLeaseFailedTitle
                                  : l10n.appInstanceBlockedTitle,
                              key: const ValueKey('app-instance-gate-title'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              failed
                                  ? l10n.appInstanceLeaseFailedMessage
                                  : l10n.appInstanceBlockedMessage,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh_outlined),
                              label: Text(l10n.dataRecoveryRetryAction),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.provider});

  final TimetableProvider provider;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      _flushPendingUiStateSaves(oldWidget.provider);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _flushPendingUiStateSaves(widget.provider);
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushPendingUiStateSaves(widget.provider);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return SkedMotionPolicyScope(
      disableAnimations: features.disableAnimations,
      reduceMotion: features.reduceMotion,
      child: ChangeNotifierProvider<TimetableProvider>.value(
        value: widget.provider,
        child: Selector<TimetableProvider, _AppShellSnapshot>(
          selector: (_, provider) => _AppShellSnapshot.from(provider),
          builder: (context, snapshot, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context).appTitle,
              locale: appLocaleFromCode(snapshot.localeCode),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              themeMode: themeModeFromValue(snapshot.themeMode),
              themeAnimationStyle: appThemeAnimationStyle,
              theme: buildAppTheme(
                seedColor: Color(snapshot.themeSeedColorValue),
                brightness: Brightness.light,
                themeColorMode: snapshot.themeColorMode,
                colorfulUiColorValues: snapshot.colorfulUiColorValues,
              ),
              darkTheme: buildAppTheme(
                seedColor: Color(snapshot.themeSeedColorValue),
                brightness: Brightness.dark,
                themeColorMode: snapshot.themeColorMode,
                colorfulUiColorValues: snapshot.colorfulUiColorValues,
              ),
              home: const AppHomeScreen(),
            );
          },
        ),
      ),
    );
  }
}

void _flushPendingUiStateSaves(TimetableProvider provider) {
  unawaited(
    provider.flushPendingUiStateSaves().onError((error, stackTrace) {
      debugPrint('Lifecycle UI state flush failed: $error\n$stackTrace');
    }),
  );
}

class _AppShellSnapshot {
  const _AppShellSnapshot({
    required this.localeCode,
    required this.themeMode,
    required this.themeColorMode,
    required this.themeSeedColorValue,
    required this.colorfulUiColorValues,
  });

  factory _AppShellSnapshot.from(TimetableProvider provider) {
    return _AppShellSnapshot(
      localeCode: provider.localeCode,
      themeMode: provider.themeMode,
      themeColorMode: provider.themeColorMode,
      themeSeedColorValue: provider.themeSeedColorValue,
      colorfulUiColorValues: Map.unmodifiable(provider.colorfulUiColorValues),
    );
  }

  final String localeCode;
  final String themeMode;
  final String themeColorMode;
  final int themeSeedColorValue;
  final Map<String, int> colorfulUiColorValues;

  @override
  bool operator ==(Object other) {
    return other is _AppShellSnapshot &&
        other.localeCode == localeCode &&
        other.themeMode == themeMode &&
        other.themeColorMode == themeColorMode &&
        other.themeSeedColorValue == themeSeedColorValue &&
        mapEquals(other.colorfulUiColorValues, colorfulUiColorValues);
  }

  @override
  int get hashCode => Object.hash(
    localeCode,
    themeMode,
    themeColorMode,
    themeSeedColorValue,
    _stableMapHash(colorfulUiColorValues),
  );
}

int _stableMapHash(Map<String, int> values) {
  final keys = values.keys.toList()..sort();
  return Object.hashAll([
    for (final key in keys) Object.hash(key, values[key]),
  ]);
}
