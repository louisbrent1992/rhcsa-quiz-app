import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme.dart';

/// Lifetime progress: coverage of the bank, per-chapter mastery, and the
/// history of finished sessions.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final progress = scope.notifier!;
    final theme = Theme.of(context);
    final history = progress.history;

    // Per-chapter mastery = correct attempts / total attempts on that
    // chapter's questions, across every session.
    final chapterCorrect = <int, int>{};
    final chapterSeen = <int, int>{};
    for (final q in repo.questions) {
      final stat = progress.statFor(q.id);
      if (stat == null || stat.seen == 0) continue;
      chapterCorrect[q.chapter] = (chapterCorrect[q.chapter] ?? 0) + stat.correct;
      chapterSeen[q.chapter] = (chapterSeen[q.chapter] ?? 0) + stat.seen;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          if (progress.totalAttempts > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Reset progress',
              onPressed: () => _confirmReset(context),
            ),
        ],
      ),
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
                                : progress.answeredCount / repo.questions.length,
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
                    ),
                const SizedBox(height: 24),
                Text('Recent sessions', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final session in history.take(20))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: (session.passed
                              ? ResultColors.correct(context)
                              : ResultColors.wrong(context))
                          .withValues(alpha: 0.15),
                      child: Text(
                        '${(session.score * 100).round()}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: session.passed
                              ? ResultColors.correct(context)
                              : ResultColors.wrong(context),
                        ),
                      ),
                    ),
                    title: Text(session.label.isEmpty ? 'Quiz' : session.label),
                    subtitle: Text(
                      '${session.correct}/${session.total} · '
                      '${_formatDate(session.at)}',
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final store = AppScope.progressOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text(
          'This clears every score, session and weak-area record. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await store.reset();
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

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.title,
    required this.correct,
    required this.seen,
  });

  final String title;
  final int correct;
  final int seen;

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
              const SizedBox(width: 8),
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
