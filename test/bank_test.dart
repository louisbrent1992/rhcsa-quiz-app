@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rhcsa_quiz/models/question.dart';
import 'package:rhcsa_quiz/models/syllabus.dart';

/// Validates the shipped question bank without booting a widget tree — the
/// asset JSON is read straight off disk, so these run in milliseconds.
void main() {
  final syllabus = Syllabus.fromJson(
    json.decode(File('assets/syllabus.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  final questions = <Question>[
    for (final chapter in syllabus.chapters)
      ...(json.decode(
        File('assets/questions/ch${chapter.num.toString().padLeft(2, '0')}.json')
            .readAsStringSync(),
      ) as List)
          .map((e) => Question.fromJson(e as Map<String, dynamic>)),
  ];

  test('syllabus covers 22 chapters and 62 objectives', () {
    expect(syllabus.chapters, hasLength(22));
    expect(syllabus.objectives, hasLength(62));
    expect(
      syllabus.chapters.map((c) => c.num).toSet(),
      List.generate(22, (i) => i + 1).toSet(),
    );
  });

  test('bank has questions for every chapter', () {
    final counts = <int, int>{};
    for (final q in questions) {
      counts[q.chapter] = (counts[q.chapter] ?? 0) + 1;
    }
    for (final chapter in syllabus.chapters) {
      expect(
        counts[chapter.num] ?? 0,
        greaterThanOrEqualTo(15),
        reason: 'chapter ${chapter.num} is thin',
      );
    }
    expect(questions.length, greaterThanOrEqualTo(440));
  });

  test('bank has questions for every exam objective', () {
    final covered = {for (final q in questions) ...q.objectives};
    for (final objective in syllabus.objectives) {
      expect(
        covered,
        contains(objective.id),
        reason: 'objective ${objective.id} has no questions',
      );
    }
  });

  test('question ids and prompts are unique', () {
    final ids = questions.map((q) => q.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    final prompts = questions.map((q) => q.prompt.toLowerCase().trim()).toList();
    expect(prompts.toSet(), hasLength(prompts.length));
  });

  test('every topic and objective reference resolves', () {
    final objectiveIds = syllabus.objectives.map((o) => o.id).toSet();
    for (final q in questions) {
      final chapter = syllabus.chapter(q.chapter);
      expect(chapter.topics, contains(q.topic), reason: q.id);
      for (final o in q.objectives) {
        expect(objectiveIds, contains(o), reason: q.id);
      }
      expect(q.difficulty, inInclusiveRange(1, 3), reason: q.id);
      expect(q.explanation.length, greaterThan(40), reason: q.id);
    }
  });

  test('each question type is well formed', () {
    for (final q in questions) {
      switch (q.type) {
        case QuestionType.mcq:
          expect(q.answer, hasLength(1), reason: q.id);
          expect(q.options.length, greaterThanOrEqualTo(3), reason: q.id);
        case QuestionType.multi:
          expect(q.answer.length, greaterThanOrEqualTo(2), reason: q.id);
          // A "select all" question with every option correct teaches nothing.
          expect(q.answer.length, lessThan(q.options.length), reason: q.id);
        case QuestionType.command:
          expect(q.options, isEmpty, reason: q.id);
          expect(q.accept, isNotEmpty, reason: q.id);
          expect(q.canonical, isNotNull, reason: q.id);
      }
      for (final i in q.answer) {
        expect(i, inInclusiveRange(0, q.options.length - 1), reason: q.id);
      }
      expect(q.options.toSet(), hasLength(q.options.length), reason: q.id);
    }
  });

  test('every canonical command answer is graded correct', () {
    final commands = questions.where((q) => q.type == QuestionType.command);
    expect(commands, isNotEmpty);
    for (final q in commands) {
      expect(
        q.isCorrect(q.canonical),
        isTrue,
        reason: '${q.id}: canonical "${q.canonical}" fails its own patterns',
      );
    }
  });

  test('no command question accepts an empty or trivial answer', () {
    for (final q in questions.where((q) => q.type == QuestionType.command)) {
      expect(q.isCorrect(''), isFalse, reason: q.id);
      expect(q.isCorrect('x'), isFalse, reason: q.id);
    }
  });
}
