import 'package:flutter/material.dart';

/// A FilledButton that runs an async action once per tap.
///
/// While [onPressed] runs, the label is swapped for a spinner and the button
/// is disabled, so a second tap can't send the order or the payment twice.
/// It enables again when the action finishes, whether it worked or threw.
/// Handle errors inside [onPressed] and show them to the user there.
class AsyncButton extends StatefulWidget {
  const AsyncButton({super.key, required this.onPressed, required this.child});

  final Future<void> Function()? onPressed;
  final Widget child;

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: widget.onPressed == null || _busy ? null : _run,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          // The label keeps its space so the button doesn't change width.
          Visibility(
            visible: !_busy,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            maintainSemantics: true,
            child: widget.child,
          ),
          if (_busy) const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
