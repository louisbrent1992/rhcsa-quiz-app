import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/quiz_builder.dart';
import '../models/quiz.dart';
import '../services/progress_store.dart';
import '../theme.dart';
import 'quiz_screen.dart';

/// Lifetime progress: coverage of the bank, where the weak areas actually
/// are, per-chapter mastery, session history, and the controls to reset any
/// of it.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final progress = scope.notifier!;
    final theme = Theme.of(context);
    final history = progress.history;
    final missed = progress.missedIds;

    // Per-chapter mastery = correct attempts / total attempts on that
    // chapter's questions, across every session. The weak tally is how many
    // of that chapter's questions are currently flagged.
    final chapterCorrect = <int, int>{};
    final chapterSeen = <int, int>{};
    final chapterWeak = <int, int>{};
    final topicWeak = <String, int>{};
    for (final q in repo.questions) {
      if (missed.contains(q.id)) {
        chapterWeak[q.chapter] = (chapterWeak[q.chapter] ?? 0) + 1;
        topicWeak[q.topic] = (topicWeak[q.topic] ?? 0) + 1;
      }
      final stat = progress.statFor(q.id);
      if (stat == null || stat.seen == 0) continue;
      chapterCorrect[q.chapter] =
          (chapterCorrect[q.chapter] ?? 0) + stat.correct;
      chapterSeen[q.chapter] = (chapterSeen[q.chapter] ?? 0) + stat.seen;
    }

    // Worst topics first — this is the list that answers "what should I
    // study next", which a single weak-areas count never could.
    final weakTopics = topicWeak.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: progress.totalAttempts == 0
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(progress.lifetimeAccuracy * 100).round()}% lifetime accuracy',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${progress.answeredCount} of ${repo.questions.length} '
                          'questions seen · ${progress.totalAttempts} attempts · '
                          '${history.length} session${history.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: repo.questions.isEmpty
                                ? 0
                                : progress.answeredCount /
                                    repo.questions.length,
                            minHeight: 8,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bank coverage',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _WeakAreas(missedCount: missed.length, topics: weakTopics),
                const SizedBox(height: 24),
                Text('Chapter mastery', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Chapters you have not touched are not listed.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final chapter in repo.syllabus.chapters)
                  if ((chapterSeen[chapter.num] ?? 0) > 0)
                    _MasteryRow(
                      title: '${chapter.num}. ${chapter.title}',
                      correct: chapterCorrect[chapter.num]!,
                      seen: chapterSeen[chapter.num]!,
                      weak: chapterWeak[chapter.num] ?? 0,
                    ),
                const SizedBox(height: 24),
                Text('Recent sessions', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final session in history.take(20))
                  _SessionTile(session: session),
                const SizedBox(height: 28),
                const _ResetSection(),
              ],
            ),
    );
  }
}

/// The weak-areas panel. A bare count on the home screen could never show
/// whether a drill had moved anything, so the breakdown lives here: which
/// topics are flagged, how many questions in each, and a drill per topic.
class _WeakAreas extends StatelessWidget {
  const _WeakAreas({required this.missedCount, required this.topics});

  final int missedCount;
  final List<MapEntry<String, int>> topics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (missedCount == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: ResultColors.correct(context),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No weak areas', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Every question you have answered, you got right most '
                      'recently.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Weak areas', style: theme.textTheme.titleMedium),
            ),
            Text(
              '$missedCount question${missedCount == 1 ? '' : 's'}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: ResultColors.wrong(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Questions whose last answer was wrong, worst topic first. '
          'Answer one correctly and it leaves this list.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in topics.take(8))
          _WeakTopicRow(topic: entry.key, count: entry.value),
        if (topics.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ ${topics.length - 8} more topic'
              '${topics.length - 8 == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _WeakTopicRow extends StatelessWidget {
  const _WeakTopicRow({required this.topic, required this.count});

  final String topic;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: ResultColors.wrong(context).withValues(alpha: 0.15),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ResultColors.wrong(context),
          ),
        ),
      ),
      title: Text(topic, style: theme.textTheme.bodyMedium),
      trailing: const Icon(Icons.play_circle_outline),
      onTap: () => _drill(context),
    );
  }

  /// Drills just this topic's flagged questions, straight in — no setup
  /// screen, because the scope is already exactly what the row says.
  void _drill(BuildContext context) {
    final scope = AppScope.of(context);
    final config = QuizConfig(
      filterMode: FilterMode.topics,
      topics: {topic},
      weakAreasOnly: true,
      questionCount: count,
    );
    final items = QuizBuilder(scope.repository.questions)
        .build(config, missed: scope.notifier!.missedIds);
    if (items.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(items: items, config: config, label: topic),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final color = session.passed
        ? ResultColors.correct(context)
        : ResultColors.wrong(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          '${(session.score * 100).round()}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
      title: Text(session.label.isEmpty ? 'Quiz' : session.label),
      subtitle: Text(
        '${session.correct}/${session.total} · ${_formatDate(session.at)}'
        '${session.partial ? ' · ended early' : ''}',
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'today $time';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} $time';
  }
}

/// Two resets, because they answer different questions: "my weak-areas list is
/// stale" and "my accuracy no longer reflects how I am doing now".
class _ResetSection extends StatelessWidget {
  const _ResetSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = AppScope.progressOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reset', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Clear weak areas'),
                subtitle: const Text(
                  'Empties the weak-areas list. Accuracy, mastery and session '
                  'history are kept.',
                ),
                onTap: progress.missedIds.isEmpty
                    ? null
                    : () => _confirm(
                          context,
                          title: 'Clear weak areas?',
                          body: 'The '
                              '${progress.missedIds.length} question'
                              '${progress.missedIds.length == 1 ? '' : 's'} '
                              'currently flagged will be unflagged. Your '
                              'accuracy and history are not touched.',
                          action: 'Clear',
                          run: progress.clearWeakAreas,
                          done: 'Weak areas cleared',
                        ),
                enabled: progress.missedIds.isNotEmpty,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Reset all progress',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text(
                  'Starts accuracy from scratch, so the percentage reflects '
                  'how you are answering now.',
                ),
                onTap: () => _confirm(
                  context,
                  title: 'Reset all progress?',
                  body: 'This clears every score, session and weak-area '
                      'record. It cannot be undone.',
                  action: 'Reset',
                  run: progress.reset,
                  done: 'Progress reset',
                  destructive: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required Future<void> Function() run,
    required String done,
    bool destructive = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    // Not awaited: the store clears in memory and notifies before the write
    // starts, so the screen is already up to date. See QuizScreen._finish.
    run();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.title,
    required this.correct,
    required this.seen,
    required this.weak,
  });

  final String title;
  final int correct;
  final int seen;

  /// How many of this chapter's questions are currently flagged weak.
  final int weak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = seen == 0 ? 0.0 : correct / seen;
    final color = ratio >= 0.7
        ? ResultColors.correct(context)
        : ResultColors.wrong(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
              if (weak > 0) ...[
                Text(
                  '$weak weak',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ResultColors.wrong(context),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${(ratio * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text('No sessions yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Finish a quiz and your accuracy, chapter mastery and weak '
              'areas will show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
