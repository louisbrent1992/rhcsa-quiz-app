/// The three question formats supported by the quiz engine.
enum QuestionType {
  /// Single correct answer chosen from a list of options.
  mcq,

  /// One or more correct answers chosen from a list of options.
  multi,

  /// The user types a command; graded against a list of accepted patterns.
  command,
}

QuestionType _typeFromString(String s) {
  switch (s) {
    case 'multi':
      return QuestionType.multi;
    case 'command':
      return QuestionType.command;
    default:
      return QuestionType.mcq;
  }
}

class Question {
  final String id;
  final int chapter;
  final String topic;
  final List<int> objectives;
  final QuestionType type;

  /// 1 = recall, 2 = applied, 3 = exam-hard.
  final int difficulty;
  final String prompt;

  /// Options for [QuestionType.mcq] and [QuestionType.multi]; empty otherwise.
  final List<String> options;

  /// Indices into [options] that are correct.
  final List<int> answer;

  /// Accepted answers for [QuestionType.command], as regular expressions
  /// matched against the normalized user input.
  final List<String> accept;

  /// A canonical answer shown in review for [QuestionType.command].
  final String? canonical;
  final String explanation;

  const Question({
    required this.id,
    required this.chapter,
    required this.topic,
    required this.objectives,
    required this.type,
    required this.difficulty,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.accept,
    required this.canonical,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        chapter: j['chapter'] as int,
        topic: j['topic'] as String,
        objectives:
            (j['objectives'] as List? ?? const []).map((e) => e as int).toList(),
        type: _typeFromString(j['type'] as String? ?? 'mcq'),
        difficulty: j['difficulty'] as int? ?? 2,
        prompt: j['prompt'] as String,
        options:
            (j['options'] as List? ?? const []).map((e) => e as String).toList(),
        answer: (j['answer'] as List? ?? const []).map((e) => e as int).toList(),
        accept:
            (j['accept'] as List? ?? const []).map((e) => e as String).toList(),
        canonical: j['canonical'] as String?,
        explanation: j['explanation'] as String? ?? '',
      );

  /// Normalizes a typed command so grading ignores incidental whitespace and
  /// a leading `#`/`$` prompt or `sudo`, which the book's examples vary on.
  static String normalizeCommand(String input) {
    var s = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceFirst(RegExp(r'^[#$]\s*'), '');
    s = s.replaceFirst(RegExp(r'^sudo\s+'), '');
    return s;
  }

  /// True when [response] is a correct answer to this question.
  ///
  /// For [QuestionType.multi] the selection must match exactly — partial
  /// credit is not awarded, matching how the real exam scores a task.
  bool isCorrect(Object? response) {
    switch (type) {
      case QuestionType.mcq:
      case QuestionType.multi:
        if (response is! Set<int>) return false;
        return response.length == answer.length &&
            response.every(answer.contains);
      case QuestionType.command:
        if (response is! String) return false;
        final s = normalizeCommand(response);
        if (s.isEmpty) return false;
        return accept.any(
          (p) => RegExp('^(?:$p)\$', caseSensitive: true).hasMatch(s),
        );
    }
  }

  String get typeLabel => switch (type) {
        QuestionType.mcq => 'Multiple choice',
        QuestionType.multi => 'Select all that apply',
        QuestionType.command => 'Command entry',
      };

  String get difficultyLabel => switch (difficulty) {
        1 => 'Recall',
        3 => 'Exam-hard',
        _ => 'Applied',
      };
}
