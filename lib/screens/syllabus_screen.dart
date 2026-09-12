import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/study_builder.dart';
import '../models/quiz.dart';
import 'study_screen.dart';

/// Learn mode. Browse the book by chapter, by topic section, or by official
/// exam objective, and open the study material for whatever you tap.
///
/// Quizzes are not started from here — that is the Practice tab's job. Each
/// study screen ends with a "Quiz me on this" button, so the path from
/// reading to being tested stays one tap away without making this a second
/// quiz launcher.
class SyllabusScreen extends StatelessWidget {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Learn'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chapters'),
              Tab(text: 'Topics'),
              Tab(text: 'Objectives'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ChaptersTab(), _TopicsTab(), _ObjectivesTab()],
        ),
      ),
    );
  }
}

/// Opens the study material for [scope]. [config] is handed straight through
/// to the "Quiz me on this" button at the bottom of the study screen.
void _study(BuildContext context, StudyScope scope, QuizConfig config) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => StudyScreen(scope: scope, quizConfig: config),
    ),
  );
}

/// Small "12 Q" pill showing how many questions exist for a row.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = count == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: empty
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        empty ? '—' : '$count Q',
        style: theme.textTheme.labelSmall?.copyWith(
          color: empty
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChaptersTab extends StatelessWidget {
  const _ChaptersTab();

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.repositoryOf(context);
    final counts = repo.countByChapter;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: repo.syllabus.chapters.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final chapter = repo.syllabus.chapters[i];
        final count = counts[chapter.num] ?? 0;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              '${chapter.num}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          title: Text(chapter.title),
          subtitle: Text(
            '${chapter.topics.length} topics · '
            '${chapter.objectives.length} objectives',
          ),
          trailing: _CountBadge(count),
          onTap: () => _study(
            context,
            ChapterScope(chapter.num, chapter.title),
            QuizConfig(
              chapters: {chapter.num},
              questionCount: count.clamp(1, 20),
            ),
          ),
        );
      },
    );
  }
}

class _TopicsTab extends StatelessWidget {
  const _TopicsTab();

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.repositoryOf(context);
    final counts = repo.countByTopic;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: repo.syllabus.chapters.length,
      itemBuilder: (context, i) {
        final chapter = repo.syllabus.chapters[i];
        return ExpansionTile(
          title: Text(chapter.title),
          subtitle: Text(chapter.label),
          children: [
            for (final topic in chapter.topics)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                title: Text(topic),
                trailing: _CountBadge(counts[topic] ?? 0),
                onTap: () => _study(
                  context,
                  TopicScope(topic),
                  QuizConfig(
                    filterMode: FilterMode.topics,
                    topics: {topic},
                    questionCount: (counts[topic] ?? 0).clamp(1, 20),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ObjectivesTab extends StatelessWidget {
  const _ObjectivesTab();

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.repositoryOf(context);
    final counts = repo.countByObjective;
    final sections = repo.syllabus.objectivesBySection;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final entry in sections.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              entry.key.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          for (final objective in entry.value)
            ListTile(
              leading: SizedBox(
                width: 28,
                child: Text(
                  '${objective.id}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              title: Text(objective.text),
              subtitle: Text(
                'Chapter${objective.chapters.length > 1 ? 's' : ''} '
                '${objective.chapters.join(', ')}',
              ),
              trailing: _CountBadge(counts[objective.id] ?? 0),
              onTap: () => _study(
                context,
                ObjectiveScope(objective.id, objective.text),
                QuizConfig(
                  filterMode: FilterMode.objectives,
                  objectives: {objective.id},
                  questionCount: (counts[objective.id] ?? 0).clamp(1, 20),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
