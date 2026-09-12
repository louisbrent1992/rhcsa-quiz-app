import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhcsa_quiz/data/repository.dart';
import 'package:rhcsa_quiz/main.dart';
import 'package:rhcsa_quiz/models/quiz.dart';
import 'package:rhcsa_quiz/screens/quiz_screen.dart';
import 'package:rhcsa_quiz/screens/quiz_setup_screen.dart';
import 'package:rhcsa_quiz/screens/results_screen.dart';
import 'package:rhcsa_quiz/screens/study_screen.dart';
import 'package:rhcsa_quiz/services/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the REAL app root — not a hand-wired MaterialApp — because the wiring
/// itself is what these tests guard. `AppScope` used to live under
/// `MaterialApp.home`, i.e. below the Navigator, so every pushed route built
/// without it and threw "AppScope is missing from the widget tree". A test that
/// assembles its own tree around a single screen cannot see that class of bug;
/// only walking the real root through a real `Navigator.push` can.
Future<void> _boot(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  // Assets must be read on the real event loop: `rootBundle` reads never
  // complete inside the fake-async zone a widget test runs in, which is why
  // the app root accepts a pre-resolved boot future.
  final data = await t.runAsync(() async {
    return (await Repository.load(), await ProgressStore.load());
  });
  await t.pumpWidget(RhcsaQuizApp(boot: Future.value(data!)));
  await t.pumpAndSettle();
}

/// Abandons the running quiz and returns home through the confirm dialog.
Future<void> _quit(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.close));
  await t.pumpAndSettle();
  await t.tap(find.widgetWithText(FilledButton, 'End quiz'));
  await t.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester t, Finder target) async {
  await t.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Build a custom quiz reaches the setup screen', (t) async {
    await _boot(t);

    await _tapVisible(t, find.text('Build a custom quiz'));

    expect(t.takeException(), isNull);
    expect(find.byType(QuizSetupScreen), findsOneWidget);
  });

  testWidgets('the fixed presets skip setup and start immediately', (t) async {
    await _boot(t);

    for (final (label, count) in [('Quick 20', 20), ('Mock exam', 40)]) {
      await _tapVisible(t, find.text(label));

      expect(t.takeException(), isNull, reason: '$label threw on start');
      expect(find.byType(QuizSetupScreen), findsNothing, reason: label);
      expect(find.byType(QuizScreen), findsOneWidget, reason: label);
      expect(find.text('Question 1 of $count'), findsOneWidget, reason: label);

      await _quit(t);
    }
  });

  testWidgets('Mock exam starts timed, Quick 20 does not', (t) async {
    await _boot(t);

    await _tapVisible(t, find.text('Quick 20'));
    expect(
      t.widget<QuizScreen>(find.byType(QuizScreen)).config.timeLimit,
      isNull,
    );
    await _quit(t);

    await _tapVisible(t, find.text('Mock exam'));
    final exam = t.widget<QuizScreen>(find.byType(QuizScreen)).config;
    expect(exam.mode, QuizMode.exam);
    expect(exam.timeLimit, const Duration(minutes: 60));
    // The countdown is already ticking, so match the shape rather than 60:00.
    expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsOneWidget);
    await _quit(t);
  });

  testWidgets('a preset draws a fresh set of questions each run', (t) async {
    await _boot(t);

    await _tapVisible(t, find.text('Quick 20'));
    final first = t.widget<QuizScreen>(find.byType(QuizScreen)).items;
    await _quit(t);

    await _tapVisible(t, find.text('Quick 20'));
    final second = t.widget<QuizScreen>(find.byType(QuizScreen)).items;

    expect(
      [for (final i in first) i.question.id],
      isNot([for (final i in second) i.question.id]),
    );
  });

  testWidgets('a chapter row in Learn opens study material, not a quiz',
      (t) async {
    await _boot(t);

    await t.tap(find.text('Learn'));
    await t.pumpAndSettle();
    await t.tap(find.byType(ListTile).first);
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    // Learn is for reading; quizzes belong to the Practice tab.
    expect(find.byType(StudyScreen), findsOneWidget);
    expect(find.byType(QuizSetupScreen), findsNothing);
    expect(find.textContaining('Commands ('), findsOneWidget);
    expect(find.textContaining('Cards ('), findsOneWidget);
  });

  testWidgets('study material hands off to a scoped quiz', (t) async {
    await _boot(t);

    await t.tap(find.text('Learn'));
    await t.pumpAndSettle();
    await t.tap(find.byType(ListTile).first);
    await t.pumpAndSettle();

    await t.tap(find.widgetWithText(FilledButton, 'Quiz me on this'));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    expect(find.byType(QuizSetupScreen), findsOneWidget);
  });

  testWidgets('custom quiz runs end to end and records the result', (t) async {
    await _boot(t);

    await _tapVisible(t, find.text('Build a custom quiz'));
    expect(find.byType(QuizSetupScreen), findsOneWidget);

    // Open and dismiss the chapter sheet: it builds against the repository and
    // is pushed as its own route too.
    await t.tap(find.textContaining('All chapters'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();

    // Drag the length slider to its minimum so the session is one question.
    await t.scrollUntilVisible(
      find.byType(Slider),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.drag(find.byType(Slider), const Offset(-600, 0));
    await t.pumpAndSettle();
    expect(find.textContaining('1 of '), findsOneWidget);

    await _tapVisible(t, find.widgetWithText(FilledButton, 'Start quiz'));
    expect(t.takeException(), isNull);
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.text('Question 1 of 1'), findsOneWidget);

    // Skip straight to the end: finishing writes to the progress store, which
    // is the other thing that needs AppScope from a pushed route.
    await t.tap(find.widgetWithText(OutlinedButton, 'Finish'));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('0 of 1 correct'), findsOneWidget);

    // Back home, the run shows up in lifetime stats.
    await t.tap(find.byTooltip('Home'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('0%'), findsOneWidget);
  });
}
