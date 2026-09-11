import 'question.dart';

/// Which axis the user filtered the question pool on.
enum FilterMode { chapters, topics, objectives }

/// Practice reveals the answer after each question; exam defers all feedback
/// to the results screen and runs a countdown, like the real EX200 sitting.
enum QuizMode { practice, exam }

class QuizConfig {
  final FilterMode filterMode;
  final Set<int> chapters;
  final Set<String> topics;
  final Set<int> objectives;
  final Set<QuestionType> types;
  final Set<int> difficulties;
  final int questionCount;
  final QuizMode mode;
  final bool shuffleOptions;

  /// Restrict the pool to questions previously answered incorrectly.
  final bool weakAreasOnly;

  /// Wall-clock limit for [QuizMode.exam]; null means untimed.
  final Duration? timeLimit;

  const QuizConfig({
    this.filterMode = FilterMode.chapters,
    this.chapters = const {},
    this.topics = const {},
    this.objectives = const {},
    this.types = const {
      QuestionType.mcq,
      QuestionType.multi,
      QuestionType.command,
    },
    this.difficulties = const {1, 2, 3},
    this.questionCount = 20,
    this.mode = QuizMode.practice,
    this.shuffleOptions = true,
    this.weakAreasOnly = false,
    this.timeLimit,
  });

  QuizConfig copyWith({
    FilterMode? filterMode,
    Set<int>? chapters,
    Set<String>? topics,
    Set<int>? objectives,
    Set<QuestionType>? types,
    Set<int>? difficulties,
    int? questionCount,
    QuizMode? mode,
    bool? shuffleOptions,
    bool? weakAreasOnly,
    Duration? timeLimit,
    bool clearTimeLimit = false,
  }) =>
      QuizConfig(
        filterMode: filterMode ?? this.filterMode,
        chapters: chapters ?? this.chapters,
        topics: topics ?? this.topics,
        objectives: objectives ?? this.objectives,
        types: types ?? this.types,
        difficulties: difficulties ?? this.difficulties,
        questionCount: questionCount ?? this.questionCount,
        mode: mode ?? this.mode,
        shuffleOptions: shuffleOptions ?? this.shuffleOptions,
        weakAreasOnly: weakAreasOnly ?? this.weakAreasOnly,
        timeLimit: clearTimeLimit ? null : (timeLimit ?? this.timeLimit),
      );

  /// True when the user has narrowed the pool on the active axis. An empty
  /// selection means "everything", so the pool is unrestricted.
  bool get hasSelection => switch (filterMode) {
        FilterMode.chapters => chapters.isNotEmpty,
        FilterMode.topics => topics.isNotEmpty,
        FilterMode.objectives => objectives.isNotEmpty,
      };
}

/// One question as presented in a session, with its options already shuffled
/// so the displayed order and the recorded response stay in sync.
class QuizItem {
  final Question question;

  /// Display order: `displayOrder[i]` is the index into `question.options`
  /// shown at position `i`.
  final List<int> displayOrder;

  Object? response;

  QuizItem({required this.question, required this.displayOrder});

  bool get answered => switch (question.type) {
        QuestionType.command =>
          response is String && (response as String).trim().isNotEmpty,
        _ => response is Set<int> && (response as Set<int>).isNotEmpty,
      };

  bool get correct => question.isCorrect(response);

  List<String> get displayedOptions =>
      [for (final i in displayOrder) question.options[i]];

  /// Indices into [displayedOptions] that are correct.
  Set<int> get displayedAnswer => {
        for (var i = 0; i < displayOrder.length; i++)
          if (question.answer.contains(displayOrder[i])) i,
      };

  /// Translates a tap on displayed position [displayIndex] into the underlying
  /// option index, then toggles it in the response set.
  void toggleOption(int displayIndex) {
    final underlying = displayOrder[displayIndex];
    final current = response is Set<int> ? (response as Set<int>) : <int>{};
    if (question.type == QuestionType.mcq) {
      response = {underlying};
      return;
    }
    response = current.contains(underlying)
        ? (Set<int>.from(current)..remove(underlying))
        : (Set<int>.from(current)..add(underlying));
  }

  bool isSelected(int displayIndex) =>
      response is Set<int> &&
      (response as Set<int>).contains(displayOrder[displayIndex]);
}

class QuizResult {
  final DateTime finishedAt;
  final List<QuizItem> items;
  final Duration elapsed;
  final QuizConfig config;

  const QuizResult({
    required this.finishedAt,
    required this.items,
    required this.elapsed,
    required this.config,
  });

  int get total => items.length;
  int get correctCount => items.where((i) => i.correct).length;
  double get score => total == 0 ? 0 : correctCount / total;

  /// Red Hat's pass mark for the RHCSA is 210/300.
  bool get passed => score >= 0.70;

  /// Correct/total per chapter, for the post-quiz breakdown.
  Map<int, (int, int)> get byChapter {
    final map = <int, (int, int)>{};
    for (final i in items) {
      final ch = i.question.chapter;
      final (c, t) = map[ch] ?? (0, 0);
      map[ch] = (c + (i.correct ? 1 : 0), t + 1);
    }
    return map;
  }

  /// Correct/total per exam objective. A question tagged with several
  /// objectives counts toward each of them.
  Map<int, (int, int)> get byObjective {
    final map = <int, (int, int)>{};
    for (final i in items) {
      for (final o in i.question.objectives) {
        final (c, t) = map[o] ?? (0, 0);
        map[o] = (c + (i.correct ? 1 : 0), t + 1);
      }
    }
    return map;
  }
}
