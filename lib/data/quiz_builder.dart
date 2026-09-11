import 'dart:math';

import '../models/question.dart';
import '../models/quiz.dart';

class QuizBuilder {
  QuizBuilder(this.all, {Random? random}) : _rng = random ?? Random();

  final List<Question> all;
  final Random _rng;

  /// Every question matching [config]'s filters, before the count limit is
  /// applied. The UI uses this to show "N questions available".
  List<Question> pool(QuizConfig config, {Set<String> missed = const {}}) {
    return all.where((q) {
      if (!config.types.contains(q.type)) return false;
      if (!config.difficulties.contains(q.difficulty)) return false;
      if (config.weakAreasOnly && !missed.contains(q.id)) return false;
      if (!config.hasSelection) return true;
      return switch (config.filterMode) {
        FilterMode.chapters => config.chapters.contains(q.chapter),
        FilterMode.topics => config.topics.contains(q.topic),
        FilterMode.objectives =>
          q.objectives.any(config.objectives.contains),
      };
    }).toList();
  }

  /// Draws the session's questions, spreading them as evenly as the pool allows
  /// across the selected chapters so a 20-question quiz over 5 chapters is not
  /// dominated by whichever chapter happens to have the most questions.
  List<QuizItem> build(QuizConfig config, {Set<String> missed = const {}}) {
    final candidates = pool(config, missed: missed);
    if (candidates.isEmpty) return [];

    final byChapter = <int, List<Question>>{};
    for (final q in candidates) {
      byChapter.putIfAbsent(q.chapter, () => []).add(q);
    }
    for (final list in byChapter.values) {
      list.shuffle(_rng);
    }

    final target = min(config.questionCount, candidates.length);
    final chapters = byChapter.keys.toList()..shuffle(_rng);
    final picked = <Question>[];
    // Round-robin across chapters until the target is met or every list is dry.
    while (picked.length < target) {
      var tookAny = false;
      for (final ch in chapters) {
        if (picked.length >= target) break;
        final list = byChapter[ch]!;
        if (list.isEmpty) continue;
        picked.add(list.removeLast());
        tookAny = true;
      }
      if (!tookAny) break;
    }

    picked.shuffle(_rng);
    return [
      for (final q in picked)
        QuizItem(
          question: q,
          displayOrder: _order(q.options.length, config.shuffleOptions),
        ),
    ];
  }

  List<int> _order(int length, bool shuffle) {
    final order = List<int>.generate(length, (i) => i);
    if (shuffle) order.shuffle(_rng);
    return order;
  }
}
