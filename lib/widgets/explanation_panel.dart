import 'package:flutter/material.dart';

import '../models/question.dart';
import '../models/quiz.dart';
import '../theme.dart';

/// Verdict plus explanation, shown after checking in practice mode and in the
/// results review list.
class ExplanationPanel extends StatelessWidget {
  const ExplanationPanel({super.key, required this.item});

  final QuizItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = item.correct;
    final color =
        correct ? ResultColors.correct(context) : ResultColors.wrong(context);
    final question = item.question;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle : Icons.cancel,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                correct
                    ? 'Correct'
                    : (item.answered ? 'Not quite' : 'No answer given'),
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
          // Command answers have no options to colour, so the accepted form is
          // spelled out here instead.
          if (question.type == QuestionType.command) ...[
            const SizedBox(height: 12),
            if (item.answered && !correct) ...[
              _Label('You typed'),
              _CommandLine(item.response as String? ?? ''),
              const SizedBox(height: 10),
            ],
            _Label('Accepted answer'),
            _CommandLine(question.canonical ?? '—'),
          ],
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              question.explanation,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Chapter ${question.chapter} · ${question.topic}'
            '${question.objectives.isEmpty ? '' : ' · Objective ${question.objectives.join(', ')}'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _CommandLine extends StatelessWidget {
  const _CommandLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2126),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            text,
            style: kMono.copyWith(color: Colors.white, fontSize: 14),
          ),
        ),
      );
}
