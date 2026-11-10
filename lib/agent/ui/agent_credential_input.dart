import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/sked_task_actions.dart';
import '../provider/provider.dart' show ProviderCancellationToken;
import 'agent_selectable_text.dart';

/// The key is returned only to the owning host callback. It is never serialized
/// as a tool argument, conversation message or credential status value.
Future<String?> requestAgentCredential(
  BuildContext context,
  Uri endpoint, {
  ProviderCancellationToken? cancellation,
}) async {
  if (cancellation?.isCancelled == true) return null;
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<String>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (_) => _AgentCredentialDialog(endpoint: endpoint),
  );
  var settled = false;
  if (cancellation != null) {
    unawaited(
      cancellation.whenCancelled.then((_) {
        // Host rebinding can happen during a build. Remove only this request's
        // route after that frame, including when another dialog is now above it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final owner = route.navigator;
          if (!settled && owner != null && owner.mounted && route.isActive) {
            owner.removeRoute(route);
          }
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      }),
    );
  }
  try {
    final value = await navigator.push(route);
    return cancellation?.isCancelled == true ? null : value;
  } finally {
    settled = true;
  }
}

class _AgentCredentialDialog extends StatefulWidget {
  const _AgentCredentialDialog({required this.endpoint});
  final Uri endpoint;

  @override
  State<_AgentCredentialDialog> createState() => _AgentCredentialDialogState();
}

class _AgentCredentialDialogState extends State<_AgentCredentialDialog> {
  final _key = TextEditingController();
  bool _visible = false;
  bool _submitted = false;

  void _finish([String? value]) {
    if (_submitted || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _submitted = true;
    Navigator.of(context).pop(value);
  }

  void _submit() {
    if (_key.text.trim().isNotEmpty) _finish(_key.text);
  }

  @override
  void dispose() {
    _key.clear();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final endpoint = Uri(
      scheme: widget.endpoint.scheme,
      host: widget.endpoint.host,
      port: widget.endpoint.hasPort ? widget.endpoint.port : null,
      path: widget.endpoint.path,
    );
    return ListenableBuilder(
      listenable: _key,
      builder: (context, _) {
        final editorActions = SkedEditorActions(
          onCancel: _submitted ? null : _finish,
          onSubmit: _submitted || _key.text.trim().isEmpty ? null : _submit,
          enabled: !_submitted,
        );
        return editorActions.wrapShortcuts(
          context,
          AlertDialog(
            scrollable: true,
            title: Text(l.agentApiKey),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.agentEndpoint),
                AgentSelectableText(endpoint.toString()),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('agent-credential-input'),
                  controller: _key,
                  autofocus: true,
                  obscureText: !_visible,
                  autocorrect: false,
                  enableSuggestions: false,

                  decoration: InputDecoration(
                    filled: true,
                    labelText: l.agentApiKey,
                    helperText: l.agentKeyHint,
                    helperMaxLines: 5,
                    counterText: '',
                    suffixIcon: IconButton(
                      tooltip: _visible ? l.agentHideKey : l.agentShowKey,
                      onPressed: () => setState(() => _visible = !_visible),
                      icon: Icon(
                        _visible ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: editorActions.onCancel,
                child: Text(l.cancel),
              ),
              editorActions.wrapSaveTooltip(
                context,
                FilledButton(
                  key: const ValueKey('agent-credential-save'),
                  onPressed: editorActions.onSubmit,
                  child: Text(l.save),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
