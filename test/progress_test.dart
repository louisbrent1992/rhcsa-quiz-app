import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhcsa_quiz/app_scope.dart';
import 'package:rhcsa_quiz/data/repository.dart';
import 'package:rhcsa_quiz/main.dart';
import 'package:rhcsa_quiz/models/question.dart';
import 'package:rhcsa_quiz/data/quiz_builder.dart';
import 'package:rhcsa_quiz/models/quiz.dart';
import 'package:rhcsa_quiz/screens/quiz_screen.dart';
import 'package:rhcsa_quiz/screens/results_screen.dart';
import 'package:rhcsa_quiz/services/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Question _q(String id, {int chapter = 1, String topic = 't'}) => Question(
      id: id,
      chapter: chapter,
      topic: topic,
      objectives: const [1],
      type: QuestionType.mcq,
      difficulty: 1,
      prompt: 'p-$id',
      options: const ['a', 'b'],
      answer: const [0],
      accept: const [],
      canonical: null,
      explanation: 'why',
    );

Future<void> _boot(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final data = await t.runAsync(
    () async => (await Repository.load(), await ProgressStore.load()),
  );
  await t.pumpWidget(RhcsaQuizApp(boot: Future.value(data!)));
  await t.pumpAndSettle();
}

void main() {
  group('ProgressStore', () {
    test('an answer is written as soon as it is committed', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();

      await store.recordAnswer(_q('q1'), false);
      await store.flush();

      // A brand new store over the same backing prefs is what the app sees on
      // the next launch. Nothing about the session had to finish for this.
      final relaunched = await ProgressStore.load();
      expect(relaunched.missedIds, {'q1'});
      expect(relaunched.totalAttempts, 1);
      expect(relaunched.history, isEmpty, reason: 'no session was completed');
    });

    test('answering a flagged question correctly clears it', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();

      await store.recordAnswer(_q('q1'), false);
      expect(store.missedIds, {'q1'});
      expect(store.statFor('q1')!.misses, 1);

      await store.recordAnswer(_q('q1'), true);
      expect(store.missedIds, isEmpty);
      expect(store.statFor('q1')!.streak, 1);
      expect(store.statFor('q1')!.misses, 1, reason: 'lifetime misses persist');
    });

    test('streak resets on a miss but the seen count keeps climbing', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();

      await store.recordAnswer(_q('q1'), true);
      await store.recordAnswer(_q('q1'), true);
      expect(store.statFor('q1')!.streak, 2);

      await store.recordAnswer(_q('q1'), false);
      final stat = store.statFor('q1')!;
      expect(stat.streak, 0);
      expect(stat.seen, 3);
      expect(stat.correct, 2);
    });

    test('clearWeakAreas empties the drill but keeps accuracy', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();

      await store.recordAnswer(_q('q1'), false);
      await store.recordAnswer(_q('q2'), true);
      expect(store.missedIds, {'q1'});

      await store.clearWeakAreas();
      expect(store.missedIds, isEmpty);
      expect(store.totalAttempts, 2);
      expect(store.lifetimeAccuracy, 0.5);

      await store.flush();
      final relaunched = await ProgressStore.load();
      expect(relaunched.missedIds, isEmpty);
      expect(relaunched.lifetimeAccuracy, 0.5);
    });

    test('reset clears everything', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await ProgressStore.load();
      await store.recordAnswer(_q('q1'), false);
      await store.recordSession(
        QuizResult(
          finishedAt: DateTime.now(),
          items: [QuizItem(question: _q('q1'), displayOrder: const [0, 1])],
          elapsed: Duration.zero,
          config: const QuizConfig(),
        ),
        label: 'x',
      );

      await store.reset();
      await store.flush();

      final relaunched = await ProgressStore.load();
      expect(relaunched.totalAttempts, 0);
      expect(relaunched.history, isEmpty);
      expect(relaunched.missedIds, isEmpty);
    });

    test('records written before streak/misses existed still load', () async {
      // The v1 shape, as already stored on a device running the old build.
      SharedPreferences.setMockInitialValues({
        'question_stats_v1':
            '{"q1":{"seen":4,"correct":1,"lastWrong":true}}',
        'session_history_v1':
            '[{"at":"2026-01-02T03:04:05.000","correct":1,"total":4,'
                '"elapsed":60,"label":"old"}]',
      });
      final store = await ProgressStore.load();

      expect(store.missedIds, {'q1'});
      expect(store.totalAttempts, 4);
      expect(store.statFor('q1')!.misses, 3, reason: 'derived from seen-correct');
      expect(store.history.single.label, 'old');
      expect(store.history.single.partial, isFalse);
    });
  });

  group('quiz screen durability', () {
    testWidgets('a practice answer is recorded before the quiz ends', (t) async {
      await _boot(t);
      final store = AppScope.progressOf(
        t.element(find.text('Quick 20')),
      );

      await t.tap(find.text('Quick 20'));
      await t.pumpAndSettle();
      expect(store.totalAttempts, 0);

      // Check one answer. The session is nowhere near finished.
      await t.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      await t.pumpAndSettle();

      expect(
        store.totalAttempts,
        1,
        reason: 'the answer must not wait for the session to end',
      );
    });

    testWidgets('an expired exam does not record questions never shown',
        (t) async {
      SharedPreferences.setMockInitialValues({});
      final data = await t.runAsync(
        () async => (await Repository.load(), await ProgressStore.load()),
      );
      final (repo, store) = data!;

      // Driven directly rather than through the home screen, so the clock can
      // be advanced: the countdown reads a Stopwatch, which fake-async does
      // not move. AppScope sits above MaterialApp exactly as in the real app,
      // so the push to the results screen resolves.
      const config = QuizConfig(
        mode: QuizMode.exam,
        questionCount: 40,
        timeLimit: Duration(minutes: 60),
      );
      final items = QuizBuilder(repo.questions).build(config);
      expect(items, hasLength(40));
      final clock = _TestClock();

      await t.pumpWidget(
        AppScope(
          repository: repo,
          progress: store,
          child: MaterialApp(
            home: QuizScreen(
              items: items,
              config: config,
              label: 'Mock exam',
              clock: clock,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Question 1 of 40'), findsOneWidget);

      // Sit on question 1 and let the clock run past the limit.
      clock.elapsed = const Duration(minutes: 61);
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();

      expect(find.byType(ResultsScreen), findsOneWidget);
      // The sitting is still scored over all 40 — unattempted is wrong, as in
      // the real exam — but only the question actually shown is recorded
      // against the user, so the other 39 stay out of the weak-areas list.
      expect(
        store.totalAttempts,
        1,
        reason: '39 questions were never displayed',
      );
      expect(store.missedIds, {items.first.question.id});
      expect(store.history.single.total, 40);
    });

    testWidgets('abandoning a quiz keeps what was already answered',
        (t) async {
      await _boot(t);
      final store = AppScope.progressOf(t.element(find.text('Quick 20')));

      await t.tap(find.text('Quick 20'));
      await t.pumpAndSettle();

      // Answer three questions, then walk out.
      for (var i = 0; i < 3; i++) {
        await t.tap(find.widgetWithText(OutlinedButton, 'Skip'));
        await t.pumpAndSettle();
      }
      await t.tap(find.byIcon(Icons.close));
      await t.pumpAndSettle();
      expect(find.textContaining('already worked through'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, 'End quiz'));
      await t.pumpAndSettle();

      expect(store.totalAttempts, 3);
      expect(store.missedIds, hasLength(3));
    });
  });
}

/// An elapsed-time source the test drives by hand.
class _TestClock implements QuizClock {
  @override
  Duration elapsed = Duration.zero;

  @override
  void stop() {}
}
