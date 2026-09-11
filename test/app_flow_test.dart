import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhcsa_quiz/app_scope.dart';
import 'package:rhcsa_quiz/data/repository.dart';
import 'package:rhcsa_quiz/screens/home_screen.dart';
import 'package:rhcsa_quiz/services/progress_store.dart';
import 'package:rhcsa_quiz/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the real widget tree over the real asset bundle.
///
/// NOTE: only ONE widget test can live in this file. On this machine the first
/// `testWidgets` in a file passes in milliseconds and every subsequent one
/// hangs until the 10-minute timeout, whatever it does — a flutter_tester
/// problem, not an app one. So bank content is asserted far more cheaply in
/// bank_test.dart (plain Dart, no widget tree), and layout at phone sizes is
/// verified against the desktop build instead:
///
///   flutter build linux --debug
///   RHCSA_WINDOW_SIZE=320x568 ./build/linux/x64/debug/bundle/rhcsa_quiz
///
/// then dump the render tree over the VM service and grep for overflow. That
/// was run at 320x568 and reported zero overflow markers.
Future<Repository> _boot(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final repository = await Repository.load();
  final progress = await ProgressStore.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.light),
      home: AppScope(
        repository: repository,
        progress: progress,
        child: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('home screen renders the bank loaded from assets', (t) async {
    final repository = await _boot(t);

    expect(repository.syllabus.chapters, hasLength(22));
    expect(repository.syllabus.objectives, hasLength(62));
    expect(repository.questions.length, greaterThan(400));

    expect(find.text('RHCSA Quiz'), findsOneWidget);
    expect(find.text('Quick 20'), findsOneWidget);
    expect(find.text('Mock exam'), findsOneWidget);
    expect(find.text('Build a custom quiz'), findsOneWidget);

    // The stat strip reports the real bank size, not a placeholder.
    expect(find.text('${repository.questions.length}'), findsOneWidget);

    // Weak areas stays disabled until something has actually been missed.
    expect(find.textContaining('Nothing missed yet'), findsOneWidget);
  });
}
