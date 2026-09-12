import 'dart:convert';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import '../models/notes.dart';
import '../models/question.dart';
import '../models/syllabus.dart';

/// Loads the syllabus, the per-chapter question bank, and any study notes out
/// of assets.
///
/// Question files are named `assets/questions/ch01.json` .. `ch22.json`; a
/// missing file simply means that chapter has no questions authored yet, so
/// the app degrades to whatever is present rather than failing to start.
/// `assets/notes/chNN.json` follows the same rule and is absent by default —
/// those files are generated locally by `tool/extract_notes.py`.
///
/// Optional assets are discovered through the asset manifest rather than by
/// calling `loadString` and catching the failure. A missing asset throws
/// asynchronously from inside the bundle, and that error escapes the zone a
/// widget test's `runAsync` installs even when the call site catches it: the
/// test framework then reports it after the test has completed and wedges the
/// runner. Asking the manifest first means the failing path is never taken.
class Repository {
  Repository._(this.syllabus, this.questions, this.notes);

  final Syllabus syllabus;
  final List<Question> questions;

  /// Study notes by chapter number. Empty when none have been generated.
  final Map<int, ChapterNotes> notes;

  static Future<Repository> load() async {
    final syllabus = Syllabus.fromJson(
      json.decode(await rootBundle.loadString('assets/syllabus.json'))
          as Map<String, dynamic>,
    );

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled = manifest.listAssets().toSet();

    final questions = <Question>[];
    final notes = <int, ChapterNotes>{};
    for (final chapter in syllabus.chapters) {
      final stem = 'ch${chapter.num.toString().padLeft(2, '0')}.json';

      final questionAsset = 'assets/questions/$stem';
      if (bundled.contains(questionAsset)) {
        questions.addAll(
          (json.decode(await rootBundle.loadString(questionAsset)) as List)
              .map((e) => Question.fromJson(e as Map<String, dynamic>)),
        );
      }

      final notesAsset = 'assets/notes/$stem';
      if (bundled.contains(notesAsset)) {
        notes[chapter.num] = ChapterNotes.fromJson(
          json.decode(await rootBundle.loadString(notesAsset))
              as Map<String, dynamic>,
        );
      }
    }
    return Repository._(syllabus, questions, notes);
  }

  /// True when study notes have been generated for at least one chapter.
  bool get hasNotes => notes.isNotEmpty;

  ChapterNotes? notesFor(int chapter) => notes[chapter];

  /// Number of authored questions per chapter, used to show coverage in the UI.
  Map<int, int> get countByChapter {
    final map = <int, int>{};
    for (final q in questions) {
      map[q.chapter] = (map[q.chapter] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get countByTopic {
    final map = <String, int>{};
    for (final q in questions) {
      map[q.topic] = (map[q.topic] ?? 0) + 1;
    }
    return map;
  }

  Map<int, int> get countByObjective {
    final map = <int, int>{};
    for (final q in questions) {
      for (final o in q.objectives) {
        map[o] = (map[o] ?? 0) + 1;
      }
    }
    return map;
  }
}
