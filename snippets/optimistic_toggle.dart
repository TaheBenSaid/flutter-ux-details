import 'package:flutter/material.dart';

/// A favorite button that flips the moment it's tapped, then saves.
///
/// If [onChanged] throws, the heart goes back to what it was and
/// [failedMessage] is shown. Only the latest tap can roll back, so a slow
/// failure from an earlier tap never overwrites a newer choice.
class OptimisticToggle extends StatefulWidget {
  const OptimisticToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.failedMessage,
    this.tooltip,
  });

  final bool value;
  final Future<void> Function(bool value) onChanged;
  final String failedMessage;
  final String? tooltip;

  @override
  State<OptimisticToggle> createState() => _OptimisticToggleState();
}

class _OptimisticToggleState extends State<OptimisticToggle> {
  late bool _value = widget.value;
  int _tap = 0;

  @override
  void didUpdateWidget(OptimisticToggle old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _value = widget.value;
  }

  Future<void> _toggle() async {
    final previous = _value;
    final tap = ++_tap;
    setState(() => _value = !previous);
    try {
      await widget.onChanged(!previous);
    } on Exception {
      if (!mounted || tap != _tap) return;
      setState(() => _value = previous);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.failedMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      isSelected: _value,
      onPressed: _toggle,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
        child: _value
            ? const Icon(Icons.favorite, key: ValueKey(true), color: Colors.red)
            : const Icon(Icons.favorite_border, key: ValueKey(false)),
      ),
    );
  }
}
