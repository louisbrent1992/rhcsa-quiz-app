import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/quiz.dart';
import '../theme.dart';
import '../widgets/explanation_panel.dart';
import 'quiz_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.result, required this.label});

  final QuizResult result;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = AppScope.repositoryOf(context);
    final pct = (result.score * 100).round();
    final color = result.passed
        ? ResultColors.correct(context)
        : ResultColors.wrong(context);
    final wrong = result.items.where((i) => !i.correct).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    '$pct%',
                    style: theme.textTheme.displayMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.correctCount} of ${result.total} correct',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      result.passed
                          ? 'Above the 70% RHCSA pass mark'
                          : 'Below the 70% RHCSA pass mark',
                      style: theme.textTheme.labelMedium?.copyWith(color: color),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$label · ${_formatElapsed(result.elapsed)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (result.byChapter.length > 1) ...[
            Text('By chapter', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final entry in (result.byChapter.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key))))
              _Breakdown(
                title: '${entry.key}. ${repo.syllabus.chapter(entry.key).title}',
                correct: entry.value.$1,
                total: entry.value.$2,
              ),
            const SizedBox(height: 20),
          ],
          if (result.byObjective.isNotEmpty) ...[
            Text('By exam objective', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final entry in (result.byObjective.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key))))
              _Breakdown(
                title:
                    '${entry.key}. ${repo.syllabus.objective(entry.key).text}',
                correct: entry.value.$1,
                total: entry.value.$2,
              ),
            const SizedBox(height: 20),
          ],
          Text(
            wrong.isEmpty ? 'Review all questions' : 'Review',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            wrong.isEmpty
                ? 'Clean sweep — expand any question to re-read the explanation.'
                : '${wrong.length} to go over.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < result.items.length; i++)
            _ReviewTile(item: result.items[i], number: i + 1),
          const SizedBox(height: 24),
          if (wrong.isNotEmpty) ...[
            FilledButton.icon(
              onPressed: () => _retry(context, wrong),
              icon: const Icon(Icons.refresh),
              label: Text('Retry the ${wrong.length} missed'),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  void _retry(BuildContext context, List<QuizItem> wrong) {
    final items = [
      for (final i in wrong)
        QuizItem(question: i.question, displayOrder: i.displayOrder),
    ]..shuffle();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          items: items,
          config: result.config.copyWith(
            mode: QuizMode.practice,
            clearTimeLimit: true,
          ),
          label: '$label · retry',
        ),
      ),
    );
  }

  static String _formatElapsed(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.correct,
    required this.total,
  });

  final String title;
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : correct / total;
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
              Expanded(
                child: Text(title, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(width: 8),
              Text(
                '$correct/$total',
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

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.item, required this.number});

  final QuizItem item;
  final int number;

  @override
  Widget build(BuildContext context) {
    final color = item.correct
        ? ResultColors.correct(context)
        : ResultColors.wrong(context);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        leading: Icon(
          item.correct ? Icons.check_circle : Icons.cancel,
          color: color,
        ),
        title: Text(
          '$number. ${item.question.prompt}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        children: [
          if (item.question.options.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < item.displayedOptions.length; i++)
                    _optionRow(context, i),
                ],
              ),
            ),
          ExplanationPanel(item: item),
        ],
      ),
    );
  }

  Widget _optionRow(BuildContext context, int i) {
    final isAnswer = item.displayedAnswer.contains(i);
    final picked = item.isSelected(i);
    final color = isAnswer
        ? ResultColors.correct(context)
        : (picked ? ResultColors.wrong(context) : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAnswer
                ? Icons.check
                : (picked ? Icons.close : Icons.remove),
            size: 16,
            color: color ?? Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.displayedOptions[i],
              style: kMono.copyWith(
                fontSize: 13,
                color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
