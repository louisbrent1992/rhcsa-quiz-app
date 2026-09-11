import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../theme.dart';
import '../widgets/answer_option.dart';
import '../widgets/command_field.dart';
import '../widgets/explanation_panel.dart';
import 'results_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.items,
    required this.config,
    required this.label,
  });

  final List<QuizItem> items;
  final QuizConfig config;
  final String label;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;

  /// In practice mode the current question is "checked" before advancing, and
  /// its answer + explanation are revealed. Exam mode never sets this.
  bool _revealed = false;

  final _stopwatch = Stopwatch()..start();
  Timer? _ticker;

  bool get _isExam => widget.config.mode == QuizMode.exam;
  QuizItem get _item => widget.items[_index];

  Duration? get _remaining {
    final limit = widget.config.timeLimit;
    if (limit == null) return null;
    final left = limit - _stopwatch.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    if (widget.config.timeLimit != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_remaining == Duration.zero) {
          _finish();
        } else {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.items.length;
    final remaining = _remaining;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmQuit,
          ),
          title: Text('Question ${_index + 1} of $total'),
          actions: [
            if (remaining != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    _formatDuration(remaining),
                    style: kMono.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: remaining.inMinutes < 5
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: (_index + 1) / total,
              minHeight: 3,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: ValueKey(_item.question.id),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _MetaRow(question: _item.question),
                    const SizedBox(height: 14),
                    Text(
                      _item.question.prompt,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    ..._buildAnswerArea(),
                    if (_revealed) ...[
                      const SizedBox(height: 20),
                      ExplanationPanel(item: _item),
                    ],
                  ],
                ),
              ),
              _BottomBar(
                isExam: _isExam,
                revealed: _revealed,
                answered: _item.answered,
                isLast: _index == total - 1,
                onCheck: () => setState(() => _revealed = true),
                onNext: _next,
                onSkip: _next,
                onPrevious: _index > 0 && _isExam ? _previous : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnswerArea() {
    final question = _item.question;

    if (question.type == QuestionType.command) {
      return [
        CommandField(
          key: ValueKey('cmd-${question.id}'),
          initial: _item.response as String? ?? '',
          enabled: !_revealed,
          onChanged: (v) => setState(() => _item.response = v),
          onSubmitted: (_) {
            if (!_isExam && _item.answered && !_revealed) {
              setState(() => _revealed = true);
            }
          },
        ),
      ];
    }

    final displayed = _item.displayedOptions;
    final answerIndices = _item.displayedAnswer;
    return [
      if (question.type == QuestionType.multi)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Select all that apply.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      for (var i = 0; i < displayed.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnswerOption(
            text: displayed[i],
            index: i,
            selected: _item.isSelected(i),
            multi: question.type == QuestionType.multi,
            revealed: _revealed,
            isCorrectOption: answerIndices.contains(i),
            onTap: _revealed
                ? null
                : () => setState(() => _item.toggleOption(i)),
          ),
        ),
    ];
  }

  void _previous() => setState(() {
        _index -= 1;
        _revealed = false;
      });

  void _next() {
    if (_index == widget.items.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index += 1;
      _revealed = false;
    });
  }

  void _finish() {
    _ticker?.cancel();
    _stopwatch.stop();
    final result = QuizResult(
      finishedAt: DateTime.now(),
      items: widget.items,
      elapsed: _stopwatch.elapsed,
      config: widget.config,
    );
    AppScope.progressOf(context).record(result, label: widget.label);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(result: result, label: widget.label),
      ),
    );
  }

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this quiz?'),
        content: const Text('Your progress in this session will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End quiz'),
          ),
        ],
      ),
    );
    if ((quit ?? false) && mounted) Navigator.of(context).pop();
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _tag(context, 'Ch ${question.chapter}', theme.colorScheme.primary),
        _tag(context, question.typeLabel, theme.colorScheme.onSurfaceVariant),
        _tag(
          context,
          question.difficultyLabel,
          theme.colorScheme.onSurfaceVariant,
        ),
        for (final o in question.objectives)
          _tag(context, 'Obj $o', theme.colorScheme.onSurfaceVariant),
      ],
    );
  }

  Widget _tag(BuildContext context, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.isExam,
    required this.revealed,
    required this.answered,
    required this.isLast,
    required this.onCheck,
    required this.onNext,
    required this.onSkip,
    required this.onPrevious,
  });

  final bool isExam;
  final bool revealed;
  final bool answered;
  final bool isLast;
  final VoidCallback onCheck;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCheck = !isExam && !revealed;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (onPrevious != null) ...[
            OutlinedButton(
              onPressed: onPrevious,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 52),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 10),
          ],
          // An unanswered question must always have a way forward, in either
          // mode — otherwise the only escape is abandoning the session.
          if (showCheck && !answered)
            Expanded(
              child: OutlinedButton(
                onPressed: onSkip,
                child: Text(isLast ? 'Finish' : 'Skip'),
              ),
            )
          else
            Expanded(
              child: showCheck
                  ? FilledButton(
                      onPressed: onCheck,
                      child: const Text('Check answer'),
                    )
                  : FilledButton(
                      onPressed: (isExam && !answered) ? onSkip : onNext,
                      child: Text(
                        isLast
                            ? 'Finish'
                            : (isExam && !answered ? 'Skip' : 'Next'),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
