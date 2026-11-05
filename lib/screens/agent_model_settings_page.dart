import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../agent/agent_application.dart';
import '../agent/connection/agent_connection_manager.dart';
import '../agent/ui/agent_model_labels.dart';
import '../agent/ui/agent_settings_exit_guard.dart';
import '../l10n/app_localizations.dart';
import '../models/agent_settings.dart';
import '../widgets/settings_list.dart';
import '../widgets/settings_page_header.dart';
import '../widgets/sked_dropdown_menu.dart';

/// Edits one model; the connection page retains its own endpoint/key draft.
class AgentModelSettingsPage extends StatefulWidget {
  const AgentModelSettingsPage({super.key, this.model, this.suggestedId});
  final AgentModelConfig? model;
  final String? suggestedId;
  @override
  State<AgentModelSettingsPage> createState() => _AgentModelSettingsPageState();
}

class _AgentModelSettingsPageState extends State<AgentModelSettingsPage>
    with AgentSettingsExitGuard<AgentModelSettingsPage> {
  final _form = GlobalKey<FormState>();
  late final _id = TextEditingController(
    text: widget.model?.id ?? widget.suggestedId ?? '',
  );
  late final _efforts = <AgentReasoningEffort>{
    ...?widget.model?.reasoningEfforts,
  };
  late AgentReasoningEffort? _defaultEffort =
      widget.model?.defaultReasoningEffort;
  late AgentSettings _baseline;
  bool _defaultModel = false;
  bool _initialized = false;
  bool _saving = false;
  bool _incomplete = false;
  String? _error;

  @override
  Object get settingsDraftFingerprint => (
    _id.text,
    _efforts.fold<int>(0, (bits, effort) => bits | 1 << effort.index),
    _defaultEffort,
    _defaultModel,
  );
  @override
  bool get settingsExitBlocked => _saving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _baseline = context.read<AgentApplication>().settings;
    _defaultModel =
        _baseline.model.isEmpty || widget.model?.id == _baseline.model;
    initializeSettingsDraftGuard();
  }

  bool _unchanged(AgentSettings current) =>
      current.endpoint == _baseline.endpoint &&
      current.protocol == _baseline.protocol &&
      current.credentialRef == _baseline.credentialRef &&
      current.model == _baseline.model &&
      (widget.model == null ||
          current.modelConfig(widget.model!.id) == widget.model);

  Future<void> _save({bool remove = false}) async {
    if (_saving ||
        ModalRoute.of(context)?.isCurrent != true ||
        (!remove && !_form.currentState!.validate())) {
      return;
    }
    final application = context.read<AgentApplication>();
    final current = application.settings;
    final l = AppLocalizations.of(context);
    if (!_unchanged(current)) {
      setState(() => _error = l.agentSettingsChanged);
      return;
    }
    final id = _id.text.trim();
    if (!remove && (_efforts.isEmpty || !_efforts.contains(_defaultEffort))) {
      setState(() => _incomplete = true);
      return;
    }
    if (widget.model == null && current.modelConfig(id) != null) {
      setState(() => _error = l.agentModelIdExists);
      return;
    }
    final models = <AgentModelConfig>[
      for (final model in current.availableModels)
        if (model.id != widget.model?.id) model,
    ];
    if (!remove) {
      final model = AgentModelConfig(
        id: id,
        reasoningEfforts: [
          for (final effort in AgentReasoningEffort.values)
            if (_efforts.contains(effort)) effort,
        ],
        defaultReasoningEffort: _defaultEffort!,
      );
      final index = widget.model == null
          ? models.length
          : current.availableModels.indexOf(widget.model!);
      models.insert(
        index < 0 || index > models.length ? models.length : index,
        model,
      );
    }
    final defaultId = !remove && (_defaultModel || current.model.isEmpty)
        ? id
        : models.any((model) => model.id == current.model) &&
              (current.model != id || _defaultModel)
        ? current.model
        : models.where((model) => model.id != id).firstOrNull?.id ??
              models.firstOrNull?.id ??
              '';
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await application.configure(
        current.copyWith(models: models, model: defaultId),
        expectedSettings: current,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      completeSettingsSave<void>();
    } on AgentConnectionException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error.code == AgentConnectionErrorCode.configurationChanged
              ? l.agentSettingsChanged
              : l.agentSettingsSaveFailed,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = l.agentSettingsSaveFailed);
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return guardSettingsPage(
      SettingsPageScaffold(
        title: widget.model?.id ?? l.agentAddModel,
        bodyBuilder: (_, header) => Form(
          key: _form,
          child: ResponsiveSettingsSingleColumnBody(
            headerSliver: header,
            scrollViewKey: const PageStorageKey('agent-single-model-scroll'),
            children: [
              TextFormField(
                key: const ValueKey('agent-model'),
                controller: _id,
                enabled: !_saving,
                readOnly: widget.model != null,
                autocorrect: false,
                maxLength: 256,
                decoration: InputDecoration(
                  labelText: l.agentManualModelId,
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) =>
                    value?.trim().isNotEmpty == true &&
                        value!.trim().length <= 256
                    ? null
                    : l.agentRequiredField,
              ),
              const SizedBox(height: 20),
              Text(
                l.agentAllowedEfforts,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l.agentModelCapabilityHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _EffortChoices(
                selected: _efforts,
                onChanged: _saving
                    ? null
                    : (effort, selected) => setState(() {
                        if (selected) {
                          _efforts.add(effort);
                        } else {
                          _efforts.remove(effort);
                          if (_defaultEffort == effort) _defaultEffort = null;
                        }
                      }),
              ),
              const SizedBox(height: 12),
              SkedDropdownMenu<AgentReasoningEffort>(
                key: ValueKey('agent-default-effort-${_defaultEffort?.name}'),
                initialSelection: _defaultEffort,
                enabled: !_saving && _efforts.isNotEmpty,
                label: Text(l.agentDefaultEffort),
                dropdownMenuEntries: [
                  for (final effort in AgentReasoningEffort.values)
                    if (_efforts.contains(effort))
                      DropdownMenuEntry(
                        value: effort,
                        label: agentReasoningEffortLabel(l, effort),
                      ),
                ],
                onSelected: _saving
                    ? null
                    : (effort) => setState(() => _defaultEffort = effort),
              ),
              const SizedBox(height: 12),
              if (_baseline.models.length < 2 && widget.model != null)
                SettingsConnectedTile(
                  key: const ValueKey('agent-model-default-status'),
                  leading: const Icon(Icons.check_circle_outline),
                  title: l.agentDefaultModel,
                  informational: true,
                )
              else
                SwitchListTile.adaptive(
                  key: const ValueKey('agent-model-make-default'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.agentMakeDefaultModel),
                  value: _defaultModel,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _defaultModel = value),
                ),
              if (_incomplete) ...[
                const SizedBox(height: 12),
                Text(
                  l.agentModelEffortsRequired,
                  key: const ValueKey('agent-model-efforts-required'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  key: const ValueKey('agent-settings-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (widget.model != null)
                    TextButton(
                      key: const ValueKey('agent-remove-model'),
                      onPressed: _saving
                          ? null
                          : () => unawaited(_save(remove: true)),
                      child: Text(l.agentRemoveModel),
                    ),
                  FilledButton(
                    key: const ValueKey('agent-save-model'),
                    onPressed: _saving ? null : () => unawaited(_save()),
                    child: Text(_saving ? l.agentSaving : l.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The widest localized option fixes the column budget before selection, so
/// checkmarks cannot move an option into another row while it is being edited.
class _EffortChoices extends StatelessWidget {
  const _EffortChoices({required this.selected, required this.onChanged});

  final Set<AgentReasoningEffort> selected;
  final void Function(AgentReasoningEffort effort, bool selected)? onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.labelLarge;
    final labels = {
      for (final effort in AgentReasoningEffort.values)
        effort: agentReasoningEffortLabel(l, effort),
    };
    var minimumWidth = 80.0;
    for (final label in labels.values) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      final width = painter.width + 56;
      if (width > minimumWidth) minimumWidth = width;
      painter.dispose();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final columns = ((constraints.maxWidth + gap) / (minimumWidth + gap))
            .floor()
            .clamp(1, 4);
        final availableWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final width = minimumWidth < availableWidth
            ? minimumWidth
            : availableWidth;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: width * columns + gap * (columns - 1),
            child: Wrap(
              key: const ValueKey('agent-model-effort-choices'),
              spacing: gap,
              runSpacing: 4,
              children: [
                for (final entry in labels.entries)
                  SizedBox(
                    width: width,
                    child: FilterChip(
                      key: ValueKey('agent-model-effort-${entry.key.name}'),
                      label: Text(entry.value, style: style),
                      selected: selected.contains(entry.key),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      visualDensity: VisualDensity.standard,
                      onSelected: onChanged == null
                          ? null
                          : (value) => onChanged!(entry.key, value),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
