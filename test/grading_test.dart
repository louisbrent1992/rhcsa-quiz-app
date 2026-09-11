import 'package:flutter_test/flutter_test.dart';
import 'package:rhcsa_quiz/models/question.dart';
import 'package:rhcsa_quiz/models/quiz.dart';

Question q({
  QuestionType type = QuestionType.mcq,
  List<String> options = const ['a', 'b', 'c', 'd'],
  List<int> answer = const [0],
  List<String> accept = const [],
}) =>
    Question(
      id: 'test',
      chapter: 1,
      topic: 't',
      objectives: const [],
      type: type,
      difficulty: 1,
      prompt: 'p',
      options: options,
      answer: answer,
      accept: accept,
      canonical: null,
      explanation: '',
    );

void main() {
  group('command normalization', () {
    test('collapses whitespace and strips prompt and sudo', () {
      expect(Question.normalizeCommand('  ls   -l  '), 'ls -l');
      expect(Question.normalizeCommand('# ls -l'), 'ls -l');
      expect(Question.normalizeCommand(r'$ ls -l'), 'ls -l');
      expect(Question.normalizeCommand('sudo dnf install vim'),
          'dnf install vim');
    });
  });

  group('command grading', () {
    final question = q(
      type: QuestionType.command,
      options: const [],
      answer: const [],
      accept: const ['whoami', 'id -un'],
    );

    test('accepts any listed alternative', () {
      expect(question.isCorrect('whoami'), isTrue);
      expect(question.isCorrect('id -un'), isTrue);
    });

    test('is anchored, so a superstring is wrong', () {
      expect(question.isCorrect('whoami --help'), isFalse);
      expect(question.isCorrect('echo whoami'), isFalse);
    });

    test('is case sensitive, matching the shell', () {
      expect(question.isCorrect('WHOAMI'), isFalse);
    });

    test('rejects empty input', () {
      expect(question.isCorrect(''), isFalse);
      expect(question.isCorrect('   '), isFalse);
    });

    test('regex metacharacters in accept patterns are honoured', () {
      final ip = q(
        type: QuestionType.command,
        options: const [],
        answer: const [],
        accept: const [r'ssh user1@192\.168\.0\.110'],
      );
      expect(ip.isCorrect('ssh user1@192.168.0.110'), isTrue);
      expect(ip.isCorrect('ssh user1@192x168x0x110'), isFalse);
    });
  });

  group('multi-select grading', () {
    final question = q(type: QuestionType.multi, answer: const [0, 2]);

    test('requires the exact set', () {
      expect(question.isCorrect({0, 2}), isTrue);
      expect(question.isCorrect({2, 0}), isTrue);
    });

    test('awards nothing for a partial selection', () {
      expect(question.isCorrect({0}), isFalse);
    });

    test('rejects a superset', () {
      expect(question.isCorrect({0, 1, 2}), isFalse);
    });
  });

  group('QuizItem option shuffling', () {
    test('maps displayed positions back to the underlying options', () {
      final item = QuizItem(
        question: q(answer: const [2]),
        displayOrder: const [3, 2, 1, 0],
      );

      expect(item.displayedOptions, ['d', 'c', 'b', 'a']);
      // Underlying option 2 ('c') is displayed at position 1.
      expect(item.displayedAnswer, {1});

      item.toggleOption(1);
      expect(item.correct, isTrue);
      expect(item.isSelected(1), isTrue);
    });

    test('mcq selection replaces rather than accumulates', () {
      final item = QuizItem(
        question: q(answer: const [0]),
        displayOrder: const [0, 1, 2, 3],
      );
      item.toggleOption(1);
      item.toggleOption(0);
      expect(item.response, {0});
      expect(item.correct, isTrue);
    });

    test('multi selection toggles off', () {
      final item = QuizItem(
        question: q(type: QuestionType.multi, answer: const [0, 1]),
        displayOrder: const [0, 1, 2, 3],
      );
      item.toggleOption(0);
      item.toggleOption(1);
      item.toggleOption(1);
      expect(item.response, {0});
      expect(item.correct, isFalse);
    });
  });

  test('unanswered question is never correct', () {
    final item = QuizItem(question: q(), displayOrder: const [0, 1, 2, 3]);
    expect(item.answered, isFalse);
    expect(item.correct, isFalse);
  });
}
