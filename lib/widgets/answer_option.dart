import 'package:flutter/material.dart';

import '../theme.dart';

/// One tappable answer choice. After the answer is revealed it colours itself
/// green when it was a correct option and red only when the user picked it
/// wrongly, so a missed correct answer still reads as "this was right".
class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.text,
    required this.index,
    required this.selected,
    required this.multi,
    required this.revealed,
    required this.isCorrectOption,
    required this.onTap,
  });

  final String text;
  final int index;
  final bool selected;
  final bool multi;
  final bool revealed;
  final bool isCorrectOption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correctColor = ResultColors.correct(context);
    final wrongColor = ResultColors.wrong(context);

    Color border = theme.colorScheme.outlineVariant;
    Color? fill;
    Widget? trailing;

    if (revealed) {
      if (isCorrectOption) {
        border = correctColor;
        fill = correctColor.withValues(alpha: 0.10);
        trailing = Icon(Icons.check_circle, color: correctColor, size: 20);
      } else if (selected) {
        border = wrongColor;
        fill = wrongColor.withValues(alpha: 0.10);
        trailing = Icon(Icons.cancel, color: wrongColor, size: 20);
      }
    } else if (selected) {
      border = theme.colorScheme.primary;
      fill = theme.colorScheme.primary.withValues(alpha: 0.08);
    }

    // Option text is frequently a command or a path; monospace keeps
    // characters like -, _ and / unambiguous.
    final looksTechnical = RegExp(r'[/\-]|^\w+\s+-').hasMatch(text);

    return Material(
      color: fill ?? Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: selected || revealed ? 1.6 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _marker(context, border),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: (looksTechnical
                          ? kMono.copyWith(fontSize: 14)
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(height: 1.35),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
      ),
    );
  }

  Widget _marker(BuildContext context, Color border) {
    final theme = Theme.of(context);
    if (multi) {
      return Icon(
        selected ? Icons.check_box : Icons.check_box_outline_blank,
        size: 22,
        color: selected ? border : theme.colorScheme.outline,
      );
    }
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? border : theme.colorScheme.outline,
          width: 1.6,
        ),
      ),
      child: Text(
        String.fromCharCode(65 + index),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: selected ? border : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
