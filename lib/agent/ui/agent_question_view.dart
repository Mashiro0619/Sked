import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../interactions/agent_question.dart';
import 'agent_selectable_text.dart';
import 'agent_ui_style.dart';

class AgentQuestionView extends StatefulWidget {
  const AgentQuestionView({
    super.key,
    required this.request,
    required this.enabled,
    required this.onAnswer,
    required this.onDismiss,
    this.docked = false,
  });

  final AgentQuestionRequest request;
  final bool enabled;
  final bool docked;
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
        (question.allowFreeText && _text[question.id]!.text.trim().isNotEmpty),
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
              text: question.allowFreeText ? _text[question.id]!.text : '',
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
    final style = AgentUiStyle.of(context);
    final generation = _generation;
    final question = widget.request.questions[_page];
    final count = widget.request.questions.length;
    final target = style.desktop ? 32.0 : 48.0;
    return Material(
      key: const ValueKey('agent-question-card'),
      color: widget.docked ? Colors.transparent : style.popover,
      shape: widget.docked ? null : style.popoverShape,
      clipBehavior: widget.docked ? Clip.none : Clip.antiAlias,
      child: Container(
        decoration: widget.docked
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: style.border)),
              )
            : const BoxDecoration(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_skipped)
              Text(l.agentQuestionSkipped, style: style.label)
            else ...[
              _header(question, count, generation, target),
              const SizedBox(height: 6),
              if (_resolved)
                _answer(question)
              else ...[
                if (question.options.isNotEmpty) _options(question),
                if (question.allowFreeText)
                  TextField(
                    key: ValueKey('agent-question-text-${question.id}'),
                    controller: _text[question.id],
                    enabled: _editable,
                    minLines: 1,
                    maxLines: 4,
                    style: style.label,
                    decoration: InputDecoration(
                      hintText: l.agentQuestionAnswer,
                      hintStyle: style.label.copyWith(color: style.muted),
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      prefixIconConstraints: BoxConstraints(
                        minWidth: 32,
                        minHeight: target,
                      ),
                      prefixIcon: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: style.muted,
                      ),
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
                  style: style.label.copyWith(color: style.colors.error),
                ),
              ),
            ],
            if (_pending != null)
              Semantics(
                liveRegion: true,
                child: Text(l.agentSaving, style: style.caption),
              ),
            if (!_resolved) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    key: const ValueKey('agent-question-skip'),
                    style: style.controlStyle,
                    onPressed: _editable
                        ? () => _finish(generation: generation, dismiss: true)
                        : null,
                    child: Text(l.agentQuestionSkip),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FilledButton(
                      key: const ValueKey('agent-question-submit'),
                      style: style.filledControlStyle,
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
    final style = AgentUiStyle.of(context);
    final title = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        header: true,
        child: Text(question.question, style: style.title),
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
          style: style.controlStyle.copyWith(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          ),
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
            style: style.caption,
          ),
        ),
        IconButton(
          key: const ValueKey('agent-question-next'),
          tooltip: MaterialLocalizations.of(context).nextPageTooltip,
          onPressed: _pending == null && _page < count - 1
              ? () => _showPage(_page + 1, generation)
              : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          style: style.controlStyle.copyWith(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          ),
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

  Widget _answer(AgentQuestionPrompt question) {
    final style = AgentUiStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in question.options)
          if (_selected[question.id]!.contains(option.id))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 18, color: style.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.label, style: style.label),
                        if (option.description case final description?)
                          Text(description, style: style.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        if (_text[question.id]!.text.isNotEmpty)
          AgentSelectableText(_text[question.id]!.text, style: style.label),
      ],
    );
  }

  Widget _options(AgentQuestionPrompt question) {
    final selected = _selected[question.id]!;
    final generation = _generation;
    final style = AgentUiStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (question.multiple)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              AppLocalizations.of(context).agentQuestionMultiple,
              style: style.caption,
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
                  child: _AgentQuestionOptionSurface(
                    key: ValueKey((question.id, option.id)),
                    inkKey: ValueKey(
                      'agent-question-option-${question.id}-${option.id}',
                    ),
                    selected: checked,
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
                        minHeight: style.desktop ? 32 : 48,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
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
                                  ? style.foreground
                                  : style.subtleSurface,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: style.caption.copyWith(
                                color: checked ? style.canvas : style.muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: style.label.copyWith(fontSize: 14),
                                ),
                                if (option.description
                                    case final description?) ...[
                                  const SizedBox(height: 2),
                                  Text(description, style: style.caption),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 22,
                            child: Align(
                              alignment: AlignmentDirectional.topEnd,
                              child: checked
                                  ? Icon(
                                      Icons.check,
                                      size: 16,
                                      color: style.foreground,
                                    )
                                  : const SizedBox(height: 16),
                            ),
                          ),
                        ],
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

class _AgentQuestionOptionSurface extends StatefulWidget {
  const _AgentQuestionOptionSurface({
    super.key,
    required this.inkKey,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final Key inkKey;
  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_AgentQuestionOptionSurface> createState() =>
      _AgentQuestionOptionSurfaceState();
}

class _AgentQuestionOptionSurfaceState
    extends State<_AgentQuestionOptionSurface> {
  late final WidgetStatesController _states;

  @override
  void initState() {
    super.initState();
    _states = WidgetStatesController({
      if (widget.onTap == null) WidgetState.disabled,
    });
  }

  @override
  void didUpdateWidget(_AgentQuestionOptionSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Publish disabled state before the descendant InkWell updates itself.
    _states.update(WidgetState.disabled, widget.onTap == null);
    if (widget.onTap == null) _states.update(WidgetState.pressed, false);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Set<WidgetState>>(
        valueListenable: _states,
        child: widget.child,
        builder: (context, value, child) {
          final style = AgentUiStyle.of(context);
          final control = style.controlStyle;
          final states = {
            ...value,
            if (widget.onTap == null) WidgetState.disabled,
          };
          final shape = control.shape!
              .resolve(states)!
              .copyWith(side: control.side!.resolve(states));
          return Material(
            color: widget.selected
                ? style.selected
                : control.backgroundColor!.resolve(states),
            shape: shape,
            child: InkWell(
              key: widget.inkKey,
              statesController: _states,
              customBorder: shape,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
              onTap: widget.onTap,
              child: child,
            ),
          );
        },
      );
}
