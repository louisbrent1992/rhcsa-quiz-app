import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import '../models/quiz.dart';

/// Running tally for one question across every session it has appeared in.
class QuestionStat {
  int seen;
  int correct;

  /// True when the most recent answer was wrong; drives "weak areas only".
  bool lastWrong;

  /// Consecutive correct answers. Resets to 0 on a miss, so it reads as
  /// "how settled is this question" rather than a lifetime total.
  int streak;

  /// Lifetime wrong answers, kept so a question missed five times can be told
  /// apart from one missed once.
  int misses;

  /// When this question was last answered, for the "last drilled" line.
  DateTime? lastAt;

  QuestionStat({
    this.seen = 0,
    this.correct = 0,
    this.lastWrong = false,
    this.streak = 0,
    this.misses = 0,
    this.lastAt,
  });

  /// Reads records written before streak/misses/lastAt existed, so upgrading
  /// the app does not throw away an existing study history.
  factory QuestionStat.fromJson(Map<String, dynamic> j) => QuestionStat(
        seen: j['seen'] as int? ?? 0,
        correct: j['correct'] as int? ?? 0,
        lastWrong: j['lastWrong'] as bool? ?? false,
        streak: j['streak'] as int? ?? 0,
        misses: j['misses'] as int? ?? ((j['seen'] as int? ?? 0) -
            (j['correct'] as int? ?? 0)),
        lastAt: j['lastAt'] == null
            ? null
            : DateTime.tryParse(j['lastAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'seen': seen,
        'correct': correct,
        'lastWrong': lastWrong,
        'streak': streak,
        'misses': misses,
        if (lastAt != null) 'lastAt': lastAt!.toIso8601String(),
      };

  double get accuracy => seen == 0 ? 0 : correct / seen;
}

/// A finished session, kept for the history list and the trend line.
class SessionRecord {
  final DateTime at;
  final int correct;
  final int total;
  final int elapsedSeconds;
  final String label;

  /// True when the session was abandoned part-way. Partial sessions still
  /// count toward per-question stats, but they are not scored as a sitting.
  final bool partial;

  const SessionRecord({
    required this.at,
    required this.correct,
    required this.total,
    required this.elapsedSeconds,
    required this.label,
    this.partial = false,
  });

  double get score => total == 0 ? 0 : correct / total;
  bool get passed => score >= 0.70;

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
        at: DateTime.parse(j['at'] as String),
        correct: j['correct'] as int,
        total: j['total'] as int,
        elapsedSeconds: j['elapsed'] as int? ?? 0,
        label: j['label'] as String? ?? '',
        partial: j['partial'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'correct': correct,
        'total': total,
        'elapsed': elapsedSeconds,
        'label': label,
        if (partial) 'partial': true,
      };
}

/// Persists study progress to shared_preferences.
///
/// Writes happen as each answer is committed rather than only when a session
/// ends, so an app that is backgrounded, killed or force-quit part-way through
/// a quiz keeps everything answered up to that point. Writes are serialised
/// through [_queue] so two overlapping commits cannot interleave and lose one
/// another's changes.
///
/// This is a [ChangeNotifier] so the stats screen and the home screen's
/// "weak areas" affordance update as soon as an answer is recorded.
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs, this._stats, this._history);

  static const _statsKey = 'question_stats_v1';
  static const _historyKey = 'session_history_v1';
  static const _historyLimit = 100;

  final SharedPreferences _prefs;
  final Map<String, QuestionStat> _stats;
  final List<SessionRecord> _history;

  /// Tail of the in-flight write chain. Every mutation appends to it, so the
  /// on-disk blob always reflects the mutations in the order they happened.
  Future<void> _queue = Future.value();

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

  int get totalAttempts => _stats.values.fold(0, (sum, s) => sum + s.seen);

  double get lifetimeAccuracy {
    final seen = totalAttempts;
    if (seen == 0) return 0;
    final correct = _stats.values.fold(0, (sum, s) => sum + s.correct);
    return correct / seen;
  }

  QuestionStat? statFor(String id) => _stats[id];

  /// Commits a single answer and writes it out straight away.
  ///
  /// Called as each question is locked in — on "Check answer" in practice
  /// mode, and for every answered question when an exam is submitted or
  /// abandoned — so nothing depends on the session reaching its end.
  Future<void> recordAnswer(Question question, bool correct) {
    final stat = _stats.putIfAbsent(question.id, QuestionStat.new);
    stat.seen += 1;
    stat.lastAt = DateTime.now();
    if (correct) {
      stat.correct += 1;
      stat.lastWrong = false;
      stat.streak += 1;
    } else {
      stat.lastWrong = true;
      stat.streak = 0;
      stat.misses += 1;
    }
    notifyListeners();
    return _enqueue();
  }

  /// Adds the session summary to the history. Per-question stats are already
  /// in by this point via [recordAnswer], so this only appends the sitting.
  Future<void> recordSession(
    QuizResult result, {
    required String label,
    bool partial = false,
  }) {
    _history.add(
      SessionRecord(
        at: result.finishedAt,
        correct: result.correctCount,
        total: result.total,
        elapsedSeconds: result.elapsed.inSeconds,
        label: label,
        partial: partial,
      ),
    );
    if (_history.length > _historyLimit) {
      _history.removeRange(0, _history.length - _historyLimit);
    }
    notifyListeners();
    return _enqueue();
  }

  /// Clears the "last answered wrong" flags without touching accuracy, session
  /// history or per-question counts. Empties the weak-areas drill so it can be
  /// rebuilt from how you are answering now.
  Future<void> clearWeakAreas() {
    for (final stat in _stats.values) {
      stat.lastWrong = false;
    }
    notifyListeners();
    return _enqueue();
  }

  /// Wipes accuracy, per-chapter mastery, weak areas and session history.
  Future<void> reset() {
    _stats.clear();
    _history.clear();
    notifyListeners();
    return _enqueue();
  }

  /// Waits for every queued write to reach shared_preferences. Called when the
  /// app is backgrounded so a subsequent kill cannot drop the last answer.
  Future<void> flush() => _queue;

  Future<void> _enqueue() {
    _queue = _queue.then((_) => _persist());
    return _queue;
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
