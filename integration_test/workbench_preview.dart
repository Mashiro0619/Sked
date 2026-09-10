import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../test/support/workspace_harness.dart';
import '../test/support/workbench_dense_data.dart';

/// Interactive native preview. All application data, secrets and site storage
/// are in-memory substitutes; this entry point never opens the user's storage.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await DesktopWindowBridge.instance.initialize();
  final provider = await denseWorkbenchProvider(
    mode: AppMode.general,
    locale: 'zh',
  );
  await provider.updateHomeWorkspaceNavigationCollapsed(false);
  DesktopWindowBridge.instance.prepareClose = provider.prepareForWindowClose;
  runApp(_Preview(provider: provider));
}

class _Preview extends StatefulWidget {
  const _Preview({required this.provider});
  final TimetableProvider provider;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => WorkspaceHarness(
    provider: widget.provider,
    locale: const Locale('zh'),
    textScale: null,
    brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );
}
