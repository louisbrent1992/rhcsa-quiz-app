import 'package:flutter_test/flutter_test.dart';
import 'package:rhcsa_quiz/data/repository.dart';
import 'package:rhcsa_quiz/main.dart';
import 'package:rhcsa_quiz/services/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boots the real app root over the real asset bundle.
///
/// Assets are read inside `tester.runAsync` and handed to the app as a
/// pre-resolved boot future: `rootBundle` reads are real I/O, and real I/O
/// never completes inside the fake-async zone a widget test runs in. Loading
/// them from inside the widget tree instead makes the boot FutureBuilder spin
/// on its progress indicator until pumpAndSettle times out — which is what
/// used to limit this file to a single test.
///
/// Layout at phone sizes is verified against the desktop build:
///
///   flutter build linux --debug
///   RHCSA_WINDOW_SIZE=320x568 ./build/linux/x64/debug/bundle/rhcsa_quiz
///
/// then dump the render tree over the VM service and grep for overflow. That
/// was run at 320x568 and reported zero overflow markers.
Future<Repository> _boot(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final data = await tester.runAsync(() async {
    return (await Repository.load(), await ProgressStore.load());
  });
  await tester.pumpWidget(RhcsaQuizApp(boot: Future.value(data!)));
  await tester.pumpAndSettle();
  return data.$1;
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
