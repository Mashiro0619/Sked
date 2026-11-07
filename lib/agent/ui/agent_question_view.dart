import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_menu_style.dart';
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
  var _page = 0;

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
    _page = 0;
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

  void _showPage(int page, int generation) {
    if (!mounted ||
        generation != _generation ||
        _pending != null ||
        page < 0 ||
        page >= widget.request.questions.length) {
      return;
    }
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final generation = _generation;
    final question = widget.request.questions[_page];
    final count = widget.request.questions.length;
    final target = SkedMenuStyle.of(context).desktop ? 32.0 : 48.0;
    return Material(
      key: const ValueKey('agent-question-card'),
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_skipped)
              Text(l.agentQuestionSkipped)
            else ...[
              _header(question, count, generation, target),
              const SizedBox(height: 6),
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
                    hintText: l.agentQuestionAnswer,
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                  onChanged: (_) {
                    if (generation != _generation || !_editable) return;
                    setState(() => _failed = false);
                  },
                ),
              ],
            ],
            if (_failed) ...[
              const SizedBox(height: 6),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.agentOperationFailed,
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
            if (_pending != null)
              Semantics(liveRegion: true, child: Text(l.agentSaving)),
            if (!_resolved) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    key: const ValueKey('agent-question-skip'),
                    onPressed: _editable
                        ? () => _finish(generation: generation, dismiss: true)
                        : null,
                    child: Text(l.agentQuestionSkip),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FilledButton(
                      key: const ValueKey('agent-question-submit'),
                      onPressed: _editable && _complete
                          ? () =>
                                _finish(generation: generation, dismiss: false)
                          : null,
                      child: Text(
                        l.agentQuestionSubmit,
                        textAlign: TextAlign.center,
                      ),
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

  Widget _header(
    AgentQuestionPrompt question,
    int count,
    int generation,
    double target,
  ) {
    final theme = Theme.of(context);
    final title = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        header: true,
        child: Text(question.question, style: theme.textTheme.titleSmall),
      ),
    );
    if (count == 1) return title;
    final navigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('agent-question-previous'),
          tooltip: MaterialLocalizations.of(context).previousPageTooltip,
          onPressed: _pending == null && _page > 0
              ? () => _showPage(_page - 1, generation)
              : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          constraints: BoxConstraints.tightFor(width: target, height: target),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.standard,
        ),
        Flexible(
          child: Text(
            AppLocalizations.of(context)
                .agentQuestionProgress(_page + 1, count),
            key: const ValueKey('agent-question-page'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('agent-question-next'),
          tooltip: MaterialLocalizations.of(context).nextPageTooltip,
          onPressed: _pending == null && _page < count - 1
              ? () => _showPage(_page + 1, generation)
              : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          constraints: BoxConstraints.tightFor(width: target, height: target),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.standard,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              title,
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: navigation,
              ),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 8),
            Flexible(child: navigation),
          ],
        );
      },
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (question.multiple)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              AppLocalizations.of(context).agentQuestionMultiple,
              style: theme.textTheme.labelSmall,
            ),
          ),
        for (var index = 0; index < question.options.length; index++)
          Builder(
            builder: (context) {
              final option = question.options[index];
              final checked = selected.contains(option.id);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Semantics(
                  checked: checked,
                  inMutuallyExclusiveGroup: !question.multiple,
                  enabled: _editable,
                  child: Material(
                    color: checked
                        ? colors.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      key: ValueKey(
                        'agent-question-option-${question.id}-${option.id}',
                      ),
                      borderRadius: BorderRadius.circular(10),
                      onTap: !_editable
                          ? null
                          : () {
                              if (generation != _generation || !_editable) {
                                return;
                              }
                              setState(() {
                                if (checked) {
                                  selected.remove(option.id);
                                } else {
                                  if (!question.multiple) selected.clear();
                                  selected.add(option.id);
                                }
                                _failed = false;
                              });
                            },
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: SkedMenuStyle.of(context).desktop
                              ? 32
                              : 48,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: checked
                                    ? colors.onSecondaryContainer
                                    : colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: checked
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: colors.secondaryContainer,
                                    )
                                  : Text(
                                      '${index + 1}',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelSmall,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  if (option.description
                                      case final description?) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      description,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (checked) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
