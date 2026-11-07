import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';

enum AgentLiveStage {
  create,
  preview,
  questionAndApproval;

  String get label => switch (this) {
    create => 'create',
    preview => 'preview',
    questionAndApproval => 'question-and-approval',
  };

  String get answerText => switch (this) {
    create =>
      '创建“Agent合成验收”课表，2026-09-07开学，共18周，使用现有节次时间集。'
          '数学周一第1节，英语周二第2节，两门课均在第1至18周每周上课，其余配置保持默认。',
    preview =>
      '只规划空课表“仅预览验收”，2026-09-07开学，共18周，'
          '沿用“Agent合成验收”的节次时间集；不添加课程，不执行保存。',
    questionAndApproval => '2026-09-14',
  };
}

/// Records the model's questions before they become answerable, then submits
/// each answer once at the same waitingUser boundary used by the product UI.
class AgentLiveQuestionResponder {
  AgentLiveQuestionResponder({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _claimed = <String>{};
  final _observed = <String, Map<String, Object?>>{};
  final records = <Map<String, Object?>>[];

  String _now() => _clock().toUtc().toIso8601String();

  Future<void>? respond({
    required AgentLiveStage stage,
    required AgentUiPhase phase,
    required AgentQuestionRequest? question,
    required Future<void> Function(
      String questionId,
      List<AgentQuestionAnswer> answers,
    )
    answer,
  }) {
    if (question == null) return null;
    final record = _observed.putIfAbsent(question.id, () {
      final value = <String, Object?>{
        'stage': stage.label,
        'request': question.toJson(),
        'firstObservedPhase': phase.name,
        'firstObservedAt': _now(),
        'status': 'observed',
      };
      records.add(value);
      return value;
    });
    if (question.isResolved || phase != AgentUiPhase.waitingUser) return null;
    if (!_claimed.add(question.id)) return null;
    final answers = [
      for (final prompt in question.questions)
        AgentQuestionAnswer(questionId: prompt.id, text: stage.answerText),
    ];
    record.addAll({
      'answerStage': stage.label,
      'answerPhase': phase.name,
      'answers': answers.map((answer) => answer.toJson()).toList(),
      'submittedAt': _now(),
      'status': 'submitting',
    });
    return _submit(record, () => answer(question.id, answers));
  }

  Future<void> _submit(
    Map<String, Object?> record,
    Future<void> Function() answer,
  ) async {
    try {
      await answer();
      record['status'] = 'answered';
    } catch (error) {
      record['status'] = 'failed';
      record['failureType'] = error.runtimeType.toString();
      record['failure'] = error.toString();
      rethrow;
    } finally {
      record['finishedAt'] = _now();
    }
  }
}
