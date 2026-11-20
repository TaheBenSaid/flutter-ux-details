import 'package:flutter/material.dart';

/// Deletes right away and offers Undo, instead of asking "Are you sure?".
///
/// Use it for anything the user can get back: a message, a saved item, a
/// draft. Keep the dialog for actions that really can't be undone, like
/// closing an account.
mixin UndoDelete<T extends StatefulWidget> on State<T> {
  /// [remove] and [restore] update local state. [commit] is the real delete
  /// and only runs once the SnackBar closes without Undo, so nothing hits the
  /// server while the user can still change their mind. If [commit] throws,
  /// the item comes back and [failedMessage] is shown.
  void deleteWithUndo({
    required String message,
    required String undoLabel,
    required String failedMessage,
    required VoidCallback remove,
    required VoidCallback restore,
    required Future<void> Function() commit,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    setState(remove);

    // Hiding the previous SnackBar closes it with reason `hide`, which commits
    // that delete now instead of queueing this one behind it.
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        // Since Flutter 3.38 a SnackBar with an action stays until tapped.
        // The delete has to commit on its own, so it must time out.
        persist: false,
        action: SnackBarAction(
          label: undoLabel,
          onPressed: () {
            if (mounted) setState(restore);
          },
        ),
      ),
    );

    controller.closed.then((reason) async {
      if (reason == SnackBarClosedReason.action) return;
      try {
        await commit();
      } on Exception {
        if (!mounted) return;
        setState(restore);
        messenger.showSnackBar(SnackBar(content: Text(failedMessage)));
      }
    });
  }
}
