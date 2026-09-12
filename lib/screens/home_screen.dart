import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/quiz_builder.dart';
import '../models/quiz.dart';
import 'quiz_screen.dart';
import 'quiz_setup_screen.dart';
import 'stats_screen.dart';
import 'syllabus_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _PracticeTab(),
          SyllabusScreen(),
          StatsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}

class _PracticeTab extends StatelessWidget {
  const _PracticeTab();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final repo = scope.repository;
    final progress = scope.notifier!;
    final missed = progress.missedIds.length;
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('RHCSA Quiz', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            repo.syllabus.edition,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _StatStrip(
            questionCount: repo.questions.length,
            chapterCount: repo.syllabus.chapters.length,
            accuracy: progress.lifetimeAccuracy,
            attempts: progress.totalAttempts,
          ),
          const SizedBox(height: 24),
          Text('Quick start', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _QuickCard(
            icon: Icons.bolt,
            title: 'Quick 20',
            subtitle: 'Straight into 20 mixed questions',
            onTap: () => _startNow(
              context,
              const QuizConfig(questionCount: 20),
              'Quick 20',
            ),
          ),
          const SizedBox(height: 10),
          _QuickCard(
            icon: Icons.refresh,
            title: 'Weak areas',
            subtitle: missed == 0
                ? 'Nothing missed yet — answer some questions first'
                : '$missed question${missed == 1 ? '' : 's'} you last got wrong',
            enabled: missed > 0,
            onTap: () => _start(
              context,
              QuizConfig(
                questionCount: missed.clamp(1, 40),
                weakAreasOnly: true,
              ),
              'Weak areas',
            ),
          ),
          const SizedBox(height: 10),
          _QuickCard(
            icon: Icons.timer_outlined,
            title: 'Mock exam',
            subtitle: '40 questions · 60 minutes · feedback at the end',
            onTap: () => _startNow(
              context,
              const QuizConfig(
                questionCount: 40,
                mode: QuizMode.exam,
                timeLimit: Duration(minutes: 60),
              ),
              'Mock exam',
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const QuizSetupScreen(
                  initial: QuizConfig(),
                  title: 'Custom quiz',
                ),
              ),
            ),
            icon: const Icon(Icons.tune),
            label: const Text('Build a custom quiz'),
          ),
        ],
      ),
    );
  }

  /// Opens the setup screen so the session can be narrowed before it starts.
  void _start(BuildContext context, QuizConfig config, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizSetupScreen(initial: config, title: title),
      ),
    );
  }

  /// Draws the questions here and goes straight to the quiz. Used by presets
  /// whose whole point is that there is nothing to configure.
  void _startNow(BuildContext context, QuizConfig config, String title) {
    final scope = AppScope.of(context);
    final items = QuizBuilder(scope.repository.questions)
        .build(config, missed: scope.notifier!.missedIds);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No questions available.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(items: items, config: config, label: title),
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.questionCount,
    required this.chapterCount,
    required this.accuracy,
    required this.attempts,
  });

  final int questionCount;
  final int chapterCount;
  final double accuracy;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _cell(context, '$questionCount', 'questions'),
            _divider(context),
            _cell(context, '$chapterCount', 'chapters'),
            _divider(context),
            _cell(
              context,
              attempts == 0 ? '—' : '${(accuracy * 100).round()}%',
              'accuracy',
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => SizedBox(
        height: 32,
        child: VerticalDivider(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Icon(icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
