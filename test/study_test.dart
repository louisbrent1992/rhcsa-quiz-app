import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhcsa_quiz/app_scope.dart';
import 'package:rhcsa_quiz/data/repository.dart';
import 'package:rhcsa_quiz/data/study_builder.dart';
import 'package:rhcsa_quiz/models/notes.dart';
import 'package:rhcsa_quiz/models/quiz.dart';
import 'package:rhcsa_quiz/screens/study_screen.dart';
import 'package:rhcsa_quiz/services/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Learn mode has to read correctly both with study notes and without them.
///
/// Which one [Repository.load] produces depends on the machine — the notes are
/// generated locally and gitignored, so a developer has them and CI never
/// does. Asserting against whichever state happens to be on disk means each
/// environment only ever exercises one branch, so both are pinned here.
ChapterNotes _notes() => ChapterNotes.fromJson({
      'chapter': 1,
      'title': 'Local Installation',
      'sections': [
        {
          'heading': 'Installation Basics',
          'level': 1,
          'blocks': [
            {'type': 'p', 'text': 'RHEL installs from bootable media.'},
            {'type': 'bullet', 'text': 'Choose a software selection.'},
            {'type': 'caption', 'text': 'Figure 1-1 The installer'},
          ],
        },
      ],
    });

Future<void> _pump(
  WidgetTester t, {
  required bool withNotes,
}) async {
  SharedPreferences.setMockInitialValues({});
  final loaded = await t.runAsync(
    () async => (await Repository.load(), await ProgressStore.load()),
  );
  final (real, store) = loaded!;

  final repo = Repository.forTest(
    syllabus: real.syllabus,
    questions: real.questions,
    notes: withNotes ? {1: _notes()} : const {},
  );

  await t.pumpWidget(
    AppScope(
      repository: repo,
      progress: store,
      child: MaterialApp(
        home: StudyScreen(
          scope: ChapterScope(1, repo.syllabus.chapter(1).title),
          quizConfig: const QuizConfig(chapters: {1}, questionCount: 10),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('the Notes tab renders the material when notes exist',
      (t) async {
    await _pump(t, withNotes: true);

    expect(find.text('Notes (1)'), findsOneWidget);
    expect(find.text('Installation Basics'), findsOneWidget);
    expect(find.text('RHEL installs from bootable media.'), findsOneWidget);
    expect(find.text('Choose a software selection.'), findsOneWidget);
    // The book draws terminal output as images, so a caption is shown as a
    // gap rather than silently dropped.
    expect(find.textContaining('figure not included'), findsOneWidget);
  });

  testWidgets('the Notes tab explains how to generate them when absent',
      (t) async {
    await _pump(t, withNotes: false);

    expect(find.text('No notes for this scope'), findsOneWidget);
    expect(find.textContaining('extract_notes.py'), findsOneWidget);
  });

  testWidgets('Commands and Cards work with no notes at all', (t) async {
    // The state CI builds in: the bank-derived material has to carry Learn
    // mode on its own.
    await _pump(t, withNotes: false);

    expect(find.textContaining('Commands ('), findsOneWidget);
    expect(find.textContaining('Cards ('), findsOneWidget);

    await t.tap(find.textContaining('Commands ('));
    await t.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsWidgets);

    await t.tap(find.textContaining('Cards ('));
    await t.pumpAndSettle();
    expect(find.text('Tap to reveal'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Reveal'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Next card'), findsOneWidget);
  });
}
