import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz.dart';

/// Running tally for one question across every session it has appeared in.
class QuestionStat {
  int seen;
  int correct;

  /// True when the most recent answer was wrong; drives "weak areas only".
  bool lastWrong;

  QuestionStat({this.seen = 0, this.correct = 0, this.lastWrong = false});

  factory QuestionStat.fromJson(Map<String, dynamic> j) => QuestionStat(
        seen: j['seen'] as int? ?? 0,
        correct: j['correct'] as int? ?? 0,
        lastWrong: j['lastWrong'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() =>
      {'seen': seen, 'correct': correct, 'lastWrong': lastWrong};
}

/// A finished session, kept for the history list and the trend line.
class SessionRecord {
  final DateTime at;
  final int correct;
  final int total;
  final int elapsedSeconds;
  final String label;

  const SessionRecord({
    required this.at,
    required this.correct,
    required this.total,
    required this.elapsedSeconds,
    required this.label,
  });

  double get score => total == 0 ? 0 : correct / total;
  bool get passed => score >= 0.70;

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        at: DateTime.parse(j['at'] as String),
        correct: j['correct'] as int,
        total: j['total'] as int,
        elapsedSeconds: j['elapsed'] as int? ?? 0,
        label: j['label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'correct': correct,
        'total': total,
        'elapsed': elapsedSeconds,
        'label': label,
      };
}

/// Persists study progress to shared_preferences.
///
/// This is a [ChangeNotifier] so the stats screen and the home screen's
/// "weak areas" affordance update as soon as a session is recorded.
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs, this._stats, this._history);

  static const _statsKey = 'question_stats_v1';
  static const _historyKey = 'session_history_v1';
  static const _historyLimit = 100;

  final SharedPreferences _prefs;
  final Map<String, QuestionStat> _stats;
  final List<SessionRecord> _history;

  static Future<ProgressStore> load() async {
    final prefs = await SharedPreferences.getInstance();

    final stats = <String, QuestionStat>{};
    final rawStats = prefs.getString(_statsKey);
    if (rawStats != null) {
      final decoded = json.decode(rawStats) as Map<String, dynamic>;
      decoded.forEach((k, v) {
        stats[k] = QuestionStat.fromJson(v as Map<String, dynamic>);
      });
    }

    final history = <SessionRecord>[];
    final rawHistory = prefs.getString(_historyKey);
    if (rawHistory != null) {
      history.addAll(
        (json.decode(rawHistory) as List).map(
          (e) => SessionRecord.fromJson(e as Map<String, dynamic>),
        ),
      );
    }

    return ProgressStore._(prefs, stats, history);
  }

  Map<String, QuestionStat> get stats => Map.unmodifiable(_stats);

  /// Newest session first.
  List<SessionRecord> get history => List.unmodifiable(_history.reversed);

  /// Ids of questions whose most recent answer was wrong.
  Set<String> get missedIds =>
      {for (final e in _stats.entries) if (e.value.lastWrong) e.key};

  int get answeredCount => _stats.length;

  int get totalAttempts =>
      _stats.values.fold(0, (sum, s) => sum + s.seen);

  double get lifetimeAccuracy {
    final seen = totalAttempts;
    if (seen == 0) return 0;
    final correct = _stats.values.fold(0, (sum, s) => sum + s.correct);
    return correct / seen;
  }

  QuestionStat? statFor(String id) => _stats[id];

  Future<void> record(QuizResult result, {required String label}) async {
    for (final item in result.items) {
      final stat = _stats.putIfAbsent(item.question.id, QuestionStat.new);
      stat.seen += 1;
      if (item.correct) {
        stat.correct += 1;
        stat.lastWrong = false;
      } else {
        stat.lastWrong = true;
      }
    }

    _history.add(
      SessionRecord(
        at: result.finishedAt,
        correct: result.correctCount,
        total: result.total,
        elapsedSeconds: result.elapsed.inSeconds,
        label: label,
      ),
    );
    if (_history.length > _historyLimit) {
      _history.removeRange(0, _history.length - _historyLimit);
    }

    await _persist();
    notifyListeners();
  }

  Future<void> reset() async {
    _stats.clear();
    _history.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _statsKey,
      json.encode({for (final e in _stats.entries) e.key: e.value.toJson()}),
    );
    await _prefs.setString(
      _historyKey,
      json.encode([for (final s in _history) s.toJson()]),
    );
  }
}
