// Renders real app screens to PNG files for the Play Store listing.
//
// Not part of the normal test suite — run it explicitly:
//   flutter test tool/screenshots/capture_test.dart
//
// Output lands in store/screenshots/ at 1080x1920 (9:16), which is what Play
// wants for phone screenshots. Uses the widget tester rather than a device so
// it works with no emulator attached; the trade-off is that fonts have to be
// loaded by hand, since the test renderer's default font draws every glyph as
// a box.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rhcsa_quiz/app_scope.dart';
import 'package:rhcsa_quiz/data/quiz_builder.dart';
import 'package:rhcsa_quiz/data/repository.dart';
import 'package:rhcsa_quiz/models/question.dart';
import 'package:rhcsa_quiz/models/quiz.dart';
import 'package:rhcsa_quiz/screens/home_screen.dart';
import 'package:rhcsa_quiz/screens/quiz_screen.dart';
import 'package:rhcsa_quiz/screens/results_screen.dart';
import 'package:rhcsa_quiz/screens/stats_screen.dart';
import 'package:rhcsa_quiz/screens/syllabus_screen.dart';
import 'package:rhcsa_quiz/services/progress_store.dart';
import 'package:rhcsa_quiz/theme.dart';

const _outDir = 'store/screenshots';
const _width = 1080.0;
const _height = 1920.0;
const _dpr = 3.0;

Future<void> _loadFont(String family, Map<String, String> files) async {
  for (final entry in files.entries) {
    final loader = FontLoader(family);
    loader.addFont(
      File(entry.value).readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
    await loader.load();
  }
}

/// DejaVu stands in for Roboto. The glyph metrics differ slightly from a real
/// device, but the layout, colours and content are the app's own.
Future<void> _loadFonts() async {
  const dv = '/usr/share/fonts/truetype/dejavu';
  await _loadFont('Roboto', {'r': '$dv/DejaVuSans.ttf'});
  await _loadFont('monospace', {'r': '$dv/DejaVuSansMono.ttf'});
}

ThemeData _theme() {
  final base = buildTheme(Brightness.light);
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
  );
}

Widget _wrap(Widget child, Repository repo, ProgressStore progress) {
  return RepaintBoundary(
    key: const ValueKey('shot'),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: AppScope(repository: repo, progress: progress, child: child),
    ),
  );
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shot')),
  );
  late Uint8List bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
  });
  final file = File('$_outDir/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  // ignore: avoid_print
  print('wrote ${file.path}');
}

void main() {
  late Repository repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    repo = await Repository.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProgressStore> emptyProgress() => ProgressStore.load();

  /// A store with enough history that the progress screen has something to show.
  Future<ProgressStore> seededProgress() async {
    final rng = Random(7);
    final store = await ProgressStore.load();
    final builder = QuizBuilder(repo.questions, random: Random(1));
    for (var session = 0; session < 6; session++) {
      final items = builder.build(const QuizConfig(questionCount: 20));
      for (final item in items) {
        final right = rng.nextDouble() < 0.74;
        item.response = right
            ? (item.question.type == QuestionType.command
                ? (item.question.canonical ?? '')
                : {...item.question.answer})
            : (item.question.type == QuestionType.command ? 'ls' : <int>{});
      }
      await store.record(
        QuizResult(
          finishedAt: DateTime(2026, 9, 3 + session, 19, 30),
          items: items,
          elapsed: Duration(minutes: 14 + session),
          config: const QuizConfig(),
        ),
        label: 'Practice · all chapters',
      );
    }
    return store;
  }

  Future<void> boot(WidgetTester tester, Widget screen,
      ProgressStore progress) async {
    tester.view.physicalSize = const Size(_width, _height);
    tester.view.devicePixelRatio = _dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(screen, repo, progress));
    await tester.pumpAndSettle();
  }

  testWidgets('01 home', (tester) async {
    await boot(tester, const HomeScreen(), await seededProgress());
    await _save(tester, '01-home');
  });

  testWidgets('02 quiz question', (tester) async {
    final items = QuizBuilder(
      repo.questions.where((q) => q.type == QuestionType.mcq).toList(),
      random: Random(3),
    ).build(const QuizConfig(questionCount: 20));
    await boot(
      tester,
      QuizScreen(
        items: items,
        config: const QuizConfig(),
        label: 'Practice · all chapters',
      ),
      await emptyProgress(),
    );
    await _save(tester, '02-question');

    // Answer it, then reveal the explanation.
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    final check = find.text('Check');
    if (check.evaluate().isNotEmpty) {
      await tester.tap(check);
      await tester.pumpAndSettle();
      await _save(tester, '03-explanation');
    }
  });

  testWidgets('04 results', (tester) async {
    final builder = QuizBuilder(repo.questions, random: Random(5));
    final items = builder.build(const QuizConfig(questionCount: 20));
    final rng = Random(11);
    for (final item in items) {
      final right = rng.nextDouble() < 0.8;
      item.response = right
          ? (item.question.type == QuestionType.command
              ? (item.question.canonical ?? '')
              : {...item.question.answer})
          : (item.question.type == QuestionType.command ? 'ls' : <int>{});
    }
    await boot(
      tester,
      ResultsScreen(
        result: QuizResult(
          finishedAt: DateTime(2026, 9, 10, 20, 4),
          items: items,
          elapsed: const Duration(minutes: 17, seconds: 32),
          config: const QuizConfig(),
        ),
        label: 'Practice · all chapters',
      ),
      await emptyProgress(),
    );
    await _save(tester, '04-results');
  });

  testWidgets('05 progress', (tester) async {
    await boot(tester, const StatsScreen(), await seededProgress());
    await _save(tester, '05-progress');
  });

  testWidgets('06 syllabus', (tester) async {
    await boot(tester, const SyllabusScreen(), await emptyProgress());
    await _save(tester, '06-syllabus');
  });
}
