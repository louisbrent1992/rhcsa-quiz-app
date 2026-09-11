import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/quiz_builder.dart';
import '../data/repository.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import 'quiz_screen.dart';

/// Configures a session: what to be quizzed on, how much, and how strictly.
class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({
    super.key,
    required this.initial,
    required this.title,
  });

  final QuizConfig initial;
  final String title;

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  late QuizConfig _config = widget.initial;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final missed = scope.notifier!.missedIds;
    final builder = QuizBuilder(repo.questions);
    final available = builder.pool(_config, missed: missed).length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (!_config.weakAreasOnly) ...[
            _SectionLabel('Quiz me on'),
            SegmentedButton<FilterMode>(
              segments: const [
                ButtonSegment(
                  value: FilterMode.chapters,
                  label: Text('Chapters'),
                ),
                ButtonSegment(value: FilterMode.topics, label: Text('Topics')),
                ButtonSegment(
                  value: FilterMode.objectives,
                  label: Text('Objectives'),
                ),
              ],
              selected: {_config.filterMode},
              onSelectionChanged: (s) =>
                  setState(() => _config = _config.copyWith(filterMode: s.first)),
            ),
            const SizedBox(height: 8),
            _SelectionSummary(
              config: _config,
              onEdit: _editSelection,
              onClear: () => setState(() {
                _config = _config.copyWith(
                  chapters: {},
                  topics: {},
                  objectives: {},
                );
              }),
            ),
          ] else
            Card(
              child: ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Weak areas'),
                subtitle: Text(
                  'Drawing only from the ${missed.length} question'
                  '${missed.length == 1 ? '' : 's'} you last answered wrong',
                ),
              ),
            ),
          const SizedBox(height: 20),
          _SectionLabel('Question formats'),
          Wrap(
            spacing: 8,
            children: [
              for (final type in QuestionType.values)
                FilterChip(
                  label: Text(_shortType(type)),
                  selected: _config.types.contains(type),
                  onSelected: (on) => setState(() {
                    final next = Set<QuestionType>.from(_config.types);
                    on ? next.add(type) : next.remove(type);
                    if (next.isEmpty) return;
                    _config = _config.copyWith(types: next);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel('Difficulty'),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const {
                1: 'Recall',
                2: 'Applied',
                3: 'Exam-hard',
              }.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: _config.difficulties.contains(entry.key),
                  onSelected: (on) => setState(() {
                    final next = Set<int>.from(_config.difficulties);
                    on ? next.add(entry.key) : next.remove(entry.key);
                    if (next.isEmpty) return;
                    _config = _config.copyWith(difficulties: next);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel('Mode'),
          SegmentedButton<QuizMode>(
            segments: const [
              ButtonSegment(
                value: QuizMode.practice,
                icon: Icon(Icons.school_outlined),
                label: Text('Practice'),
              ),
              ButtonSegment(
                value: QuizMode.exam,
                icon: Icon(Icons.timer_outlined),
                label: Text('Exam'),
              ),
            ],
            selected: {_config.mode},
            onSelectionChanged: (s) => setState(() {
              final mode = s.first;
              _config = _config.copyWith(
                mode: mode,
                timeLimit: mode == QuizMode.exam
                    ? (_config.timeLimit ?? const Duration(minutes: 30))
                    : null,
                clearTimeLimit: mode == QuizMode.practice,
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _config.mode == QuizMode.practice
                ? 'Shows the answer and explanation after each question.'
                : 'Holds all feedback until the end and runs a countdown.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (_config.mode == QuizMode.exam) ...[
            const SizedBox(height: 12),
            _Stepper(
              label: 'Time limit',
              value: '${_config.timeLimit!.inMinutes} min',
              onDecrement: _config.timeLimit!.inMinutes > 5
                  ? () => setState(() => _config = _config.copyWith(
                        timeLimit: Duration(
                          minutes: _config.timeLimit!.inMinutes - 5,
                        ),
                      ))
                  : null,
              onIncrement: _config.timeLimit!.inMinutes < 180
                  ? () => setState(() => _config = _config.copyWith(
                        timeLimit: Duration(
                          minutes: _config.timeLimit!.inMinutes + 5,
                        ),
                      ))
                  : null,
            ),
          ],
          const SizedBox(height: 20),
          _SectionLabel('Length'),
          if (available == 0)
            Text(
              'No questions match these filters yet.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else ...[
            Slider(
              value: _config.questionCount.clamp(1, available).toDouble(),
              min: 1,
              max: available.toDouble(),
              divisions: available > 1 ? available - 1 : null,
              label: '${_config.questionCount.clamp(1, available)}',
              onChanged: (v) => setState(
                () => _config = _config.copyWith(questionCount: v.round()),
              ),
            ),
            Text(
              '${_config.questionCount.clamp(1, available)} of $available '
              'available question${available == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _config.shuffleOptions,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(shuffleOptions: v)),
            title: const Text('Shuffle answer options'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: available == 0 ? null : () => _start(builder, missed),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start quiz'),
          ),
        ],
      ),
    );
  }

  String _shortType(QuestionType t) => switch (t) {
        QuestionType.mcq => 'Multiple choice',
        QuestionType.multi => 'Select all',
        QuestionType.command => 'Command',
      };

  void _start(QuizBuilder builder, Set<String> missed) {
    final items = builder.build(_config, missed: missed);
    if (items.isEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          items: items,
          config: _config,
          label: widget.title,
        ),
      ),
    );
  }

  Future<void> _editSelection() async {
    final repo = AppScope.repositoryOf(context);
    final result = await showModalBottomSheet<QuizConfig>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SelectionSheet(config: _config, repository: repo),
    );
    if (result != null) setState(() => _config = result);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label)),
          IconButton.outlined(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 84,
            child: Text(value, textAlign: TextAlign.center),
          ),
          IconButton.outlined(
            onPressed: onIncrement,
            icon: const Icon(Icons.add),
          ),
        ],
      );
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.config,
    required this.onEdit,
    required this.onClear,
  });

  final QuizConfig config;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final count = switch (config.filterMode) {
      FilterMode.chapters => config.chapters.length,
      FilterMode.topics => config.topics.length,
      FilterMode.objectives => config.objectives.length,
    };
    final noun = switch (config.filterMode) {
      FilterMode.chapters => 'chapter',
      FilterMode.topics => 'topic',
      FilterMode.objectives => 'objective',
    };

    return Card(
      child: ListTile(
        onTap: onEdit,
        title: Text(
          count == 0
              ? 'All ${noun}s'
              : '$count $noun${count == 1 ? '' : 's'} selected',
        ),
        subtitle: Text(count == 0 ? 'Tap to narrow it down' : 'Tap to change'),
        trailing: count == 0
            ? const Icon(Icons.chevron_right)
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear),
                tooltip: 'Clear selection',
              ),
      ),
    );
  }
}

/// Multi-select sheet over whichever axis the user picked. Rows with no
/// authored questions are shown but disabled, so coverage gaps are visible
/// rather than silently missing.
class _SelectionSheet extends StatefulWidget {
  const _SelectionSheet({required this.config, required this.repository});

  final QuizConfig config;
  final Repository repository;

  @override
  State<_SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<_SelectionSheet> {
  late QuizConfig _config = widget.config;

  @override
  Widget build(BuildContext context) {
    final rows = _rows(widget.repository);
    final selected = _selectedKeys();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select ${switch (_config.filterMode) {
                      FilterMode.chapters => 'chapters',
                      FilterMode.topics => 'topics',
                      FilterMode.objectives => 'objectives',
                    }}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _apply(rows
                        .where((r) => r.count > 0)
                        .map((r) => r.key)
                        .toSet()),
                  ),
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () => setState(() => _apply({})),
                  child: const Text('None'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                return CheckboxListTile(
                  value: selected.contains(row.key),
                  enabled: row.count > 0,
                  title: Text(row.title),
                  subtitle: row.subtitle == null ? null : Text(row.subtitle!),
                  secondary: _CountBadge(row.count),
                  onChanged: row.count == 0
                      ? null
                      : (on) => setState(() {
                            final next = Set<Object>.from(_selectedKeys());
                            (on ?? false) ? next.add(row.key) : next.remove(row.key);
                            _apply(next);
                          }),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_config),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Set<Object> _selectedKeys() => switch (_config.filterMode) {
        FilterMode.chapters => _config.chapters.cast<Object>().toSet(),
        FilterMode.topics => _config.topics.cast<Object>().toSet(),
        FilterMode.objectives => _config.objectives.cast<Object>().toSet(),
      };

  void _apply(Set<Object> keys) {
    _config = switch (_config.filterMode) {
      FilterMode.chapters => _config.copyWith(chapters: keys.cast<int>().toSet()),
      FilterMode.topics => _config.copyWith(topics: keys.cast<String>().toSet()),
      FilterMode.objectives =>
        _config.copyWith(objectives: keys.cast<int>().toSet()),
    };
  }

  List<_Row> _rows(Repository repo) {
    switch (_config.filterMode) {
      case FilterMode.chapters:
        final counts = repo.countByChapter;
        return [
          for (final c in repo.syllabus.chapters)
            _Row(c.num, '${c.num}. ${c.title}', null, counts[c.num] ?? 0),
        ];
      case FilterMode.topics:
        final counts = repo.countByTopic;
        return [
          for (final c in repo.syllabus.chapters)
            for (final t in c.topics)
              _Row(t, t, 'Chapter ${c.num}', counts[t] ?? 0),
        ];
      case FilterMode.objectives:
        final counts = repo.countByObjective;
        return [
          for (final o in repo.syllabus.objectives)
            _Row(
              o.id,
              '${o.id}. ${o.text}',
              o.section,
              counts[o.id] ?? 0,
            ),
        ];
    }
  }
}

class _Row {
  const _Row(this.key, this.title, this.subtitle, this.count);

  final Object key;
  final String title;
  final String? subtitle;
  final int count;
}

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
        empty ? '—' : '$count',
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
