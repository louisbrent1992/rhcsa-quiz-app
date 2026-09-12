import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../services/progress_store.dart';
import '../theme.dart';
import '../widgets/answer_option.dart';
import '../widgets/command_field.dart';
import '../widgets/explanation_panel.dart';
import 'results_screen.dart';

/// Elapsed-time source for the countdown and the session timing.
///
/// Production uses a real [Stopwatch]. Widget tests inject their own, because
/// Flutter's fake-async clock advances timers but leaves `Stopwatch` reading
/// the wall clock — which makes the auto-submit-on-expiry path unreachable in
/// a test unless the source can be swapped.
abstract class QuizClock {
  Duration get elapsed;
  void stop();
}

class _StopwatchClock implements QuizClock {
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  void stop() => _stopwatch.stop();
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.items,
    required this.config,
    required this.label,
    this.clock,
  });

  final List<QuizItem> items;
  final QuizConfig config;
  final String label;

  /// Overrides the elapsed-time source; tests only.
  final QuizClock? clock;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;

  /// In practice mode the current question is "checked" before advancing, and
  /// its answer + explanation are revealed. Exam mode never sets this.
  bool _revealed = false;

  /// Question ids already written to the progress store. Answers are committed
  /// as they are locked in rather than in one batch at the end, so a kill or a
  /// force-quit part-way through keeps everything answered so far. The set
  /// stops the end-of-session sweep from counting a question twice.
  final _committed = <String>{};

  /// Guards against [_finish] running twice — the countdown timer and the
  /// Finish button can both reach it.
  bool _finishing = false;

  /// Highest question index actually displayed. When an exam's countdown
  /// expires at question 5 of 40, the 35 questions never put on screen must
  /// not be recorded as answers the user got wrong — they would flood the
  /// weak-areas list with material never seen. The session score still counts
  /// them against you, which is what the real exam does.
  int _furthest = 0;

  late final QuizClock _clock = widget.clock ?? _StopwatchClock();
  Timer? _ticker;

  bool get _isExam => widget.config.mode == QuizMode.exam;
  QuizItem get _item => widget.items[_index];

  Duration? get _remaining {
    final limit = widget.config.timeLimit;
    if (limit == null) return null;
    final left = limit - _clock.elapsed;
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
    _clock.stop();
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
                onCheck: _reveal,
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
            if (!_isExam && _item.answered && !_revealed) _reveal();
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

  /// Writes one answer to the progress store, once. In practice mode this runs
  /// the moment a question is checked or skipped; in exam mode, where answers
  /// stay editable until submission, it is deferred to [_finish] / [_quit].
  Future<void> _commit(ProgressStore store, QuizItem item) {
    if (!_committed.add(item.question.id)) return Future.value();
    return store.recordAnswer(item.question, item.correct);
  }

  /// Locks in the current question as soon as practice mode reveals it, so the
  /// answer survives the app being killed on the very next question.
  void _reveal() {
    setState(() => _revealed = true);
    _commit(AppScope.progressOf(context), _item);
  }

  void _previous() => setState(() {
        _index -= 1;
        _revealed = false;
      });

  void _next() {
    // A skipped practice question still counts, so commit before moving on
    // rather than only on reveal.
    if (!_isExam) _commit(AppScope.progressOf(context), _item);

    if (_index == widget.items.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index += 1;
      _revealed = false;
      if (_index > _furthest) _furthest = _index;
    });
  }

  void _finish() {
    if (_finishing) return;
    _finishing = true;
    _ticker?.cancel();
    _clock.stop();

    final store = AppScope.progressOf(context);
    final result = QuizResult(
      finishedAt: DateTime.now(),
      items: widget.items,
      elapsed: _clock.elapsed,
      config: widget.config,
    );

    // Sweep up anything not already committed: every exam answer, and any
    // practice question reached but never checked. Questions past the furthest
    // one displayed are left alone unless they somehow carry a response.
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (i <= _furthest || item.answered) _commit(store, item);
    }
    store.recordSession(result, label: widget.label);

    // Deliberately not awaited. The store applies the change in memory before
    // it returns, so the results screen and the progress tab are already
    // correct; the write drains behind us and is flushed on app pause. Waiting
    // on the disk here would leave the user stuck on the last question if the
    // platform channel were slow to answer.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(result: result, label: widget.label),
      ),
    );
  }

  /// How many questions this session will leave behind in the progress store:
  /// everything already committed, plus anything answered but not yet locked
  /// in. Counting `answered` alone would understate it, because a skipped
  /// practice question has no response yet still counts as a miss.
  int get _keepCount =>
      _committed.length +
      widget.items
          .where((i) => i.answered && !_committed.contains(i.question.id))
          .length;

  Future<void> _confirmQuit() async {
    if (_finishing) return;
    final keep = _keepCount;
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this quiz?'),
        content: Text(
          keep == 0
              ? 'You have not reached any questions yet, so nothing will be '
                  'recorded.'
              : 'The $keep question${keep == 1 ? '' : 's'} you have already '
                  'worked through ${keep == 1 ? 'is' : 'are'} kept in your '
                  'progress. The rest of the session is dropped.',
        ),
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
    if (!(quit ?? false) || !mounted) return;
    _quit();
  }

  /// Keeps what was actually answered instead of discarding the session.
  void _quit() {
    _finishing = true;
    _ticker?.cancel();
    _clock.stop();

    final store = AppScope.progressOf(context);
    // Anything answered but not yet locked in — every exam response, and a
    // practice question answered without being checked.
    final reached = widget.items
        .where((i) => i.answered || _committed.contains(i.question.id))
        .toList();
    for (final item in reached) {
      _commit(store, item);
    }
    // Scored over what was reached, not the full draw — an abandoned session
    // is not a sitting, so it is filed as partial and kept out of the trend.
    if (reached.isNotEmpty) {
      store.recordSession(
        QuizResult(
          finishedAt: DateTime.now(),
          items: reached,
          elapsed: _clock.elapsed,
          config: widget.config,
        ),
        label: widget.label,
        partial: true,
      );
    }

    Navigator.of(context).pop();
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
