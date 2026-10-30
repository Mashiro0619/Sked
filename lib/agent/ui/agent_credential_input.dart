import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

/// The key is returned only to the owning host callback. It is never serialized
/// as a tool argument, conversation message or credential status value.
Future<String?> requestAgentCredential(BuildContext context, Uri endpoint) =>
    showDialog<String>(
      context: context,
      builder: (_) => _AgentCredentialDialog(endpoint: endpoint),
    );

class _AgentCredentialDialog extends StatefulWidget {
  const _AgentCredentialDialog({required this.endpoint});
  final Uri endpoint;

  @override
  State<_AgentCredentialDialog> createState() => _AgentCredentialDialogState();
}

class _AgentCredentialDialogState extends State<_AgentCredentialDialog> {
  final _key = TextEditingController();
  bool _visible = false;

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
    return AlertDialog(
      scrollable: true,
      title: Text(l.agentApiKey),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.agentEndpoint),
          SelectableText(endpoint.toString()),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('agent-credential-input'),
            controller: _key,
            autofocus: true,
            obscureText: !_visible,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 16 * 1024,
            decoration: InputDecoration(
              filled: true,
              labelText: l.agentApiKey,
              helperText: l.agentKeyHint,
              helperMaxLines: 5,
              counterText: '',
              suffixIcon: IconButton(
                tooltip: _visible ? l.agentHideKey : l.agentShowKey,
                onPressed: () => setState(() => _visible = !_visible),
                icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) Navigator.of(context).pop(value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        ListenableBuilder(
          listenable: _key,
          builder: (context, _) => FilledButton(
            key: const ValueKey('agent-credential-save'),
            onPressed: _key.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_key.text),
            child: Text(l.save),
          ),
        ),
      ],
    );
  }
}
