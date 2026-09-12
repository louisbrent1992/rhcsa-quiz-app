import '../models/question.dart';

/// What a study session is scoped to. Mirrors the quiz filter axes so
/// "learn this, then quiz this" covers the same ground.
sealed class StudyScope {
  const StudyScope();

  String get title;

  bool matches(Question q);
}

class ChapterScope extends StudyScope {
  const ChapterScope(this.chapter, this.chapterTitle);

  final int chapter;
  final String chapterTitle;

  @override
  String get title => chapterTitle;

  @override
  bool matches(Question q) => q.chapter == chapter;
}

class TopicScope extends StudyScope {
  const TopicScope(this.topic);

  final String topic;

  @override
  String get title => topic;

  @override
  bool matches(Question q) => q.topic == topic;
}

class ObjectiveScope extends StudyScope {
  const ObjectiveScope(this.id, this.text);

  final int id;
  final String text;

  @override
  String get title => 'Objective $id';

  @override
  bool matches(Question q) => q.objectives.contains(id);
}

/// One command worth committing to memory, lifted from a command-entry
/// question: the accepted answer plus the explanation that came with it.
class CommandCard {
  const CommandCard({
    required this.questionId,
    required this.command,
    required this.task,
    required this.explanation,
    required this.topic,
  });

  final String questionId;
  final String command;

  /// What the question asked for — reads as the "when you need to..." line.
  final String task;
  final String explanation;
  final String topic;

  /// The program the command invokes, e.g. `usermod`. Used to group the
  /// reference so every `usermod` form sits together.
  String get program {
    final first = command.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? command : first;
  }
}

/// A prompt/answer pair shown as a flip card, built from a choice question.
class ConceptCard {
  const ConceptCard({
    required this.questionId,
    required this.prompt,
    required this.answers,
    required this.explanation,
    required this.topic,
    required this.difficulty,
  });

  final String questionId;
  final String prompt;
  final List<String> answers;
  final String explanation;
  final String topic;
  final int difficulty;
}

/// Turns the question bank into study material.
///
/// The bank is the only content the app ships, so Learn mode is derived from
/// it rather than authored twice: command-entry questions become a command
/// reference, and the choice questions become flashcards. Optional extracted
/// notes, when present, are rendered above this by the study screen.
class StudyBuilder {
  const StudyBuilder(this.all);

  final List<Question> all;

  List<Question> _inScope(StudyScope scope) =>
      all.where(scope.matches).toList();

  /// Commands in scope, grouped by program and ordered so the most-covered
  /// program comes first. Programs are what people actually want to revise —
  /// "show me every usermod form" — rather than question order.
  Map<String, List<CommandCard>> commands(StudyScope scope) {
    final cards = [
      for (final q in _inScope(scope))
        if (q.type == QuestionType.command && q.canonical != null)
          CommandCard(
            questionId: q.id,
            command: q.canonical!,
            task: q.prompt,
            explanation: q.explanation,
            topic: q.topic,
          ),
    ];

    final grouped = <String, List<CommandCard>>{};
    for (final card in cards) {
      grouped.putIfAbsent(card.program, () => []).add(card);
    }

    final order = grouped.keys.toList()
      ..sort((a, b) {
        final byCount = grouped[b]!.length.compareTo(grouped[a]!.length);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return {for (final k in order) k: grouped[k]!};
  }

  /// Flashcards in scope, easiest first so a topic opens with recall before
  /// it asks for exam-hard reasoning.
  List<ConceptCard> concepts(StudyScope scope) {
    final cards = [
      for (final q in _inScope(scope))
        if (q.type != QuestionType.command)
          ConceptCard(
            questionId: q.id,
            prompt: q.prompt,
            answers: [for (final i in q.answer) q.options[i]],
            explanation: q.explanation,
            topic: q.topic,
            difficulty: q.difficulty,
          ),
    ];
    cards.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    return cards;
  }

  /// Distinct topics covered by the questions in scope, in chapter order.
  List<String> topics(StudyScope scope) {
    final seen = <String>{};
    return [
      for (final q in _inScope(scope))
        if (seen.add(q.topic)) q.topic,
    ];
  }
}
