import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Terminal-styled input for command-entry questions.
///
/// Autocorrect and capitalisation are off — a mobile keyboard "helpfully"
/// capitalising `lvextend` would fail every answer.
class CommandField extends StatefulWidget {
  const CommandField({
    super.key,
    required this.initial,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String initial;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<CommandField> createState() => _CommandFieldState();
}

class _CommandFieldState extends State<CommandField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF14161A)
            : const Color(0xFF1E2126),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '#',
              style: kMono.copyWith(
                color: const Color(0xFF5CD68A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              autofocus: false,
              maxLines: null,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
              style: kMono.copyWith(color: Colors.white, fontSize: 15),
              cursorColor: const Color(0xFF5CD68A),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'type the command',
                hintStyle: kMono.copyWith(
                  color: Colors.white38,
                  fontSize: 15,
                ),
              ),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
