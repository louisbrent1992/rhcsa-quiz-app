import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/study_builder.dart';
import '../models/notes.dart';
import '../models/quiz.dart';
import '../theme.dart';
import 'quiz_setup_screen.dart';

/// Learn mode: read the material for a chapter, topic or objective, revise the
/// commands, flip through flashcards, then quiz yourself on the same scope.
///
/// Three tabs rather than one long scroll, because the three are used at
/// different moments — reading through once, drilling commands before a
/// sitting, and self-testing without being graded.
class StudyScreen extends StatelessWidget {
  const StudyScreen({
    super.key,
    required this.scope,
    required this.quizConfig,
  });

  final StudyScope scope;

  /// The quiz this material prepares you for, started from the bottom bar.
  final QuizConfig quizConfig;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.repositoryOf(context);
    final builder = StudyBuilder(repo.questions);
    final commands = builder.commands(scope);
    final concepts = builder.concepts(scope);
    final notes = _notesFor(context);
    final commandCount =
        commands.values.fold(0, (sum, list) => sum + list.length);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(scope.title),
          bottom: TabBar(
            tabs: [
              Tab(text: notes == null ? 'Notes' : 'Notes (${notes.sections.length})'),
              Tab(text: 'Commands ($commandCount)'),
              Tab(text: 'Cards (${concepts.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NotesTab(notes: notes, scope: scope),
            _CommandsTab(groups: commands),
            _CardsTab(cards: concepts),
          ],
        ),
        bottomNavigationBar: _QuizBar(scope: scope, config: quizConfig),
      ),
    );
  }

  /// Notes exist per chapter. A topic or objective scope borrows its chapter's
  /// notes, since that is the unit the book is written in.
  ChapterNotes? _notesFor(BuildContext context) {
    final repo = AppScope.repositoryOf(context);
    final scope = this.scope;
    if (scope is ChapterScope) return repo.notesFor(scope.chapter);

    final chapters = {
      for (final q in repo.questions)
        if (scope.matches(q)) q.chapter,
    };
    return chapters.length == 1 ? repo.notesFor(chapters.first) : null;
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.notes, required this.scope});

  final ChapterNotes? notes;
  final StudyScope scope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = this.notes;

    if (notes == null) {
      return _Empty(
        icon: Icons.menu_book_outlined,
        title: 'No notes for this scope',
        body: scope is ChapterScope
            ? 'Generate them from your copy of the book with\n'
                'python3 tool/extract_notes.py\n\n'
                'The Commands and Cards tabs work without them.'
            : 'Notes are written per chapter. Open this material from the '
                'Chapters tab to read them, or use the Commands and Cards '
                'tabs here.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final section in notes.sections) ...[
          Padding(
            padding: EdgeInsets.only(
              top: section.level == 1 ? 20 : 14,
              bottom: 8,
            ),
            child: Text(
              section.heading,
              style: (section.level == 1
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.titleSmall)
                  ?.copyWith(
                color: section.level == 1
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          for (final block in section.blocks) _block(context, block),
        ],
        const SizedBox(height: 24),
        Text(
          'Notes are from your own copy of the book, extracted locally. '
          'Terminal transcripts in the book are images and do not carry '
          'over — the Commands tab covers those.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _block(BuildContext context, NoteBlock block) {
    final theme = Theme.of(context);
    switch (block.type) {
      case NoteBlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        );
      case NoteBlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 10),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  block.text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        );
      case NoteBlockType.caption:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.image_outlined,
                size: 15,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${block.text} — figure not included',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

/// The command reference, grouped by program so every form of `usermod` is
/// readable in one place — the exact use case for drilling before a quiz.
class _CommandsTab extends StatelessWidget {
  const _CommandsTab({required this.groups});

  final Map<String, List<CommandCard>> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (groups.isEmpty) {
      return const _Empty(
        icon: Icons.terminal,
        title: 'No commands here',
        body: 'This scope has no command-entry questions to build a '
            'reference from. Try the Cards tab.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 6),
            child: Row(
              children: [
                Text(
                  entry.key,
                  style: kMono.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.length} form'
                  '${entry.value.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final card in entry.value) _CommandTile(card: card),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.card});

  final CommandCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2126),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                card.command,
                style: kMono.copyWith(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              card.task,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                card.explanation,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flashcards. Tap to flip; nothing is graded and nothing is recorded, which
/// is the point — this is the low-stakes pass before the quiz.
class _CardsTab extends StatefulWidget {
  const _CardsTab({required this.cards});

  final List<ConceptCard> cards;

  @override
  State<_CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<_CardsTab> {
  int _index = 0;
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.cards.isEmpty) {
      return const _Empty(
        icon: Icons.style_outlined,
        title: 'No cards here',
        body: 'This scope has only command-entry questions. The Commands '
            'tab has the material.',
      );
    }

    final card = widget.cards[_index];
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_index + 1) / widget.cards.length,
          minHeight: 3,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _flipped = !_flipped),
            child: ListView(
              key: ValueKey(card.questionId),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              children: [
                Row(
                  children: [
                    Text(
                      '${_index + 1} of ${widget.cards.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      card.topic,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  card.prompt,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 24),
                if (!_flipped)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to reveal',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ResultColors.correct(context)
                          .withValues(alpha: 0.08),
                      border: Border.all(
                        color: ResultColors.correct(context)
                            .withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final answer in card.answers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 16,
                                  color: ResultColors.correct(context),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    answer,
                                    style: kMono.copyWith(
                                      fontSize: 13,
                                      color: ResultColors.correct(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          card.explanation,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _index == 0
                    ? null
                    : () => setState(() {
                          _index -= 1;
                          _flipped = false;
                        }),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() {
                    if (_flipped) {
                      _flipped = false;
                      _index = (_index + 1) % widget.cards.length;
                    } else {
                      _flipped = true;
                    }
                  }),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_flipped ? 'Next card' : 'Reveal'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Learn ends where practice begins: the same scope, now graded.
class _QuizBar extends StatelessWidget {
  const _QuizBar({required this.scope, required this.config});

  final StudyScope scope;
  final QuizConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuizSetupScreen(
                initial: config,
                title: scope.title,
              ),
            ),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Quiz me on this'),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
