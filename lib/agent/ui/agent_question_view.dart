import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../interactions/agent_question.dart';
import 'agent_selectable_text.dart';

class AgentQuestionView extends StatefulWidget {
  const AgentQuestionView({
    super.key,
    required this.request,
    required this.enabled,
    required this.onAnswer,
    required this.onDismiss,
  });

  final AgentQuestionRequest request;
  final bool enabled;
  final Future<void> Function(List<AgentQuestionAnswer>) onAnswer;
  final Future<void> Function() onDismiss;

  @override
  State<AgentQuestionView> createState() => _AgentQuestionViewState();
}

class _AgentQuestionViewState extends State<AgentQuestionView> {
  final _text = <String, TextEditingController>{};
  final _selected = <String, Set<String>>{};
  late String _source;
  var _generation = 0;
  Object? _pending;
  var _failed = false;
  var _resolved = false;
  var _skipped = false;

  bool get _editable => widget.enabled && _pending == null && !_resolved;

  bool get _complete => widget.request.questions.every(
    (question) =>
        _selected[question.id]!.isNotEmpty ||
        _text[question.id]!.text.trim().isNotEmpty,
  );

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(AgentQuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_source != jsonEncode(widget.request.toJson())) {
      _reset();
    } else if (oldWidget.enabled != widget.enabled) {
      _generation++;
    }
  }

  void _reset() {
    _generation++;
    _source = jsonEncode(widget.request.toJson());
    _pending = null;
    _failed = false;
    _resolved = widget.request.isResolved;
    _skipped = widget.request.dismissed;
    for (final controller in _text.values) {
      controller.dispose();
    }
    _text.clear();
    _selected.clear();
    final answers = {
      for (final answer in widget.request.answers ?? <AgentQuestionAnswer>[])
        answer.questionId: answer,
    };
    for (final question in widget.request.questions) {
      final answer = answers[question.id];
      _text[question.id] = TextEditingController(text: answer?.text ?? '');
      _selected[question.id] = {...?answer?.optionIds};
    }
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _finish({required int generation, required bool dismiss}) async {
    if (generation != _generation || !_editable || (!dismiss && !_complete)) {
      return;
    }
    final pending = Object();
    setState(() {
      _pending = pending;
      _failed = false;
    });
    var failed = false;
    try {
      if (dismiss) {
        await widget.onDismiss();
      } else {
        final answers = [
          for (final question in widget.request.questions)
            AgentQuestionAnswer(
              questionId: question.id,
              optionIds: [
                for (final option in question.options)
                  if (_selected[question.id]!.contains(option.id)) option.id,
              ],
              text: _text[question.id]!.text,
            ),
        ];
        await widget.onAnswer(answers);
      }
    } catch (_) {
      failed = true;
    }
    if (!mounted || !identical(_pending, pending)) return;
    setState(() {
      _pending = null;
      if (generation == _generation && widget.enabled) {
        _failed = failed;
        _resolved = !failed;
        _skipped = dismiss && !failed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final generation = _generation;
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_skipped)
              Text(l.agentQuestionSkipped)
            else
              for (final question in widget.request.questions) ...[
                if (question != widget.request.questions.first)
                  const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    question.question,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                if (_resolved)
                  _answer(question)
                else ...[
                  if (question.options.isNotEmpty) _options(question),
                  TextField(
                    key: ValueKey('agent-question-text-${question.id}'),
                    controller: _text[question.id],
                    enabled: _editable,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: l.agentQuestionAnswer,
                      filled: true,
                      errorMaxLines: 3,
                    ),
                    onChanged: (_) {
                      if (generation != _generation || !_editable) return;
                      setState(() => _failed = false);
                    },
                  ),
                ],
              ],
            if (_failed) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.agentOperationFailed,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
            if (_pending != null) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(l.agentSaving)),
            ],
            if (!_resolved) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    key: const ValueKey('agent-question-skip'),
                    onPressed: _editable
                        ? () => _finish(generation: generation, dismiss: true)
                        : null,
                    child: Text(
                      l.agentQuestionSkip,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  FilledButton(
                    key: const ValueKey('agent-question-submit'),
                    onPressed: _editable && _complete
                        ? () => _finish(generation: generation, dismiss: false)
                        : null,
                    child: Text(
                      l.agentQuestionSubmit,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _answer(AgentQuestionPrompt question) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final option in question.options)
        if (_selected[question.id]!.contains(option.id))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check),
            title: Text(option.label),
            subtitle: option.description == null
                ? null
                : Text(option.description!),
          ),
      if (_text[question.id]!.text.isNotEmpty)
        AgentSelectableText(_text[question.id]!.text),
    ],
  );

  Widget _options(AgentQuestionPrompt question) {
    final selected = _selected[question.id]!;
    final generation = _generation;
    if (question.multiple) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context).agentQuestionMultiple),
          for (final option in question.options)
            CheckboxListTile(
              key: ValueKey(
                'agent-question-option-${question.id}-${option.id}',
              ),
              value: selected.contains(option.id),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(option.label),
              subtitle: option.description == null
                  ? null
                  : Text(option.description!),
              onChanged: !_editable
                  ? null
                  : (checked) {
                      if (generation != _generation || !_editable) return;
                      setState(() {
                        if (checked == true) {
                          selected.add(option.id);
                        } else {
                          selected.remove(option.id);
                        }
                        _failed = false;
                      });
                    },
            ),
        ],
      );
    }
    return RadioGroup<String>(
      groupValue: selected.firstOrNull,
      onChanged: (value) {
        if (generation != _generation || !_editable) return;
        setState(() {
          selected.clear();
          if (value != null) selected.add(value);
          _failed = false;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in question.options)
            RadioListTile<String>(
              key: ValueKey(
                'agent-question-option-${question.id}-${option.id}',
              ),
              value: option.id,
              enabled: _editable,
              toggleable: true,
              contentPadding: EdgeInsets.zero,
              title: Text(option.label),
              subtitle: option.description == null
                  ? null
                  : Text(option.description!),
            ),
        ],
      ),
    );
  }
}
