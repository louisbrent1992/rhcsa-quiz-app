import 'dart:convert';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';
import '../models/syllabus.dart';

/// Loads the syllabus and the per-chapter question bank out of assets.
///
/// Question files are named `assets/questions/ch01.json` .. `ch22.json`; a
/// missing file simply means that chapter has no questions authored yet, so
/// the app degrades to whatever is present rather than failing to start.
class Repository {
  Repository._(this.syllabus, this.questions);

  final Syllabus syllabus;
  final List<Question> questions;

  static Future<Repository> load() async {
    final syllabus = Syllabus.fromJson(
      json.decode(await rootBundle.loadString('assets/syllabus.json'))
          as Map<String, dynamic>,
    );

    final questions = <Question>[];
    for (final chapter in syllabus.chapters) {
      final name =
          'assets/questions/ch${chapter.num.toString().padLeft(2, '0')}.json';
      final String raw;
      try {
        raw = await rootBundle.loadString(name);
      } on FlutterError {
        continue;
      }
      final decoded = json.decode(raw) as List;
      questions.addAll(
        decoded.map((e) => Question.fromJson(e as Map<String, dynamic>)),
      );
    }
    return Repository._(syllabus, questions);
  }

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
