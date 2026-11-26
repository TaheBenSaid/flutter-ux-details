# flutter-ux-details

_By [Tahe Ben Said](https://tahebensaid.dev), senior mobile engineer. More apps and tools at [tahebensaid.dev](https://tahebensaid.dev)._

Some apps feel expensive and some feel cheap, even when they do the same thing. A lot of that comes down to five small details:

1. **Undo instead of "Are you sure?"** Delete right away and show a SnackBar with Undo. The dialog only makes sense when the action can't be reversed.
2. **A button that knows it's busy.** Show a spinner inside the button and ignore taps until the request finishes. No double orders, no double payments.
3. **A skeleton, not a spinner.** Grey shapes that look like the content that is coming, instead of a spinner in the middle of an empty screen.
4. **Optimistic toggles.** The heart turns red the moment you tap it. If the request fails, it goes back and says so.
5. **An empty state that helps.** Say what goes on this screen, why it's empty, and give one button to fix it. Never a blank page.

This repo gives you three things:

- a Dart script that finds the opposite of these five in your code,
- one copy-paste file per detail in [`snippets`](snippets), plain Flutter with no packages,
- an agent skill, so your AI coding agent can run the audit and apply the right snippet for you.

There is also a small [`example`](example) app that uses all five on one screen.

## Run it

```bash
git clone https://github.com/TaheBenSaid/flutter-ux-details.git
dart flutter-ux-details/scripts/ux_audit.dart lib
```

This is the real output on the files in [`test_fixtures`](test_fixtures):

```
Flutter UX audit of test_fixtures: 5 findings in 4 files

  test_fixtures/blank_list.dart:10  ListView over orders.length with no empty check in this widget. An empty list is a blank screen. Say what goes here and offer one action (snippets/empty_state.dart)
  test_fixtures/confirm_delete.dart:14  Confirm dialog for a delete. If it can be undone, remove the item right away and show a SnackBar with Undo (snippets/undo_delete.dart)
  test_fixtures/double_submit.dart:24  Async onPressed with no busy flag. A second tap runs it again: a double submit or a double payment. Disable it while it runs (snippets/async_button.dart)
  test_fixtures/double_submit.dart:31  Async onPressed with no busy flag. A second tap runs it again: a double submit or a double payment. Disable it while it runs (snippets/async_button.dart)
  test_fixtures/spinner_screen.dart:18  Centered spinner. If this screen loads a list or cards, show a skeleton shaped like them instead (snippets/skeleton.dart)
```

`test_fixtures/clean_screen.dart` does the same jobs the right way and passes:

```
Flutter UX audit of test_fixtures/clean_screen.dart: no problems found.
```

No dependencies, nothing to add to your `pubspec.yaml`.

## What it checks

| Check | Flags | Passes |
| --- | --- | --- |
| Confirm dialogs | `showDialog` or `AlertDialog` whose text or names mention "sure", delete or remove | a dialog for "Sign out?" |
| Double taps | `onPressed`, `onTap` or `onLongPress` with an async body that awaits a request and never sets a busy flag | `_saving ? null : _save`, `if (_busy) return;`, a sibling `enabled: !state.busy`, anything inside an `AsyncButton` |
| Spinners | `Center(child: CircularProgressIndicator())` | a small spinner inside a button |
| Empty lists | `ListView.builder` or `.separated` with `itemCount: items.length` and no empty check in the same widget class | `items.isEmpty`, `case []`, `Status.empty`, an `EmptyState(...)` |

These are heuristics, so read each finding before you change anything. A few notes:

- A dialog before deleting an account or cancelling a paid plan is right. The audit can't tell that apart from deleting a note, so it says "if it can be undone".
- Method references like `onPressed: _submit` only count when the name sounds like a write (submit, save, send, pay, order, delete and so on). A favorite toggle that you tap twice on purpose isn't flagged.
- Awaiting a dialog, a route, a picker, a URL launch or the clipboard doesn't count as a request.
- A centered spinner is fine on a splash screen or a video player. It's flagged because on a list or a profile, a skeleton looks faster.
- `itemCount: Colors.values.length` and other enum lists are skipped, since they are never empty.

Comments are stripped before scanning, with line numbers kept, so commented-out code doesn't count. Generated files (`*.g.dart`, `*.freezed.dart` and friends) are skipped.

## The snippets

Copy the file you need from [`snippets`](snippets) into your project. They only import `package:flutter/material.dart`, use `EdgeInsetsDirectional` and `AlignmentDirectional` so they work in Arabic and other RTL layouts, dispose what they create, and check `mounted` after every await. They were checked with `flutter analyze` on Flutter 3.47 and need Flutter 3.38 or newer.

**`undo_delete.dart`** is a mixin for your `State`. Call `deleteWithUndo` with `remove`, `restore` and `commit`. The item disappears at once and a SnackBar offers Undo. The real delete (`commit`) only runs after the SnackBar closes without Undo, so the server never sees a delete the user took back. If `commit` throws, the item comes back with a message. Since Flutter 3.38 a SnackBar with an action stays on screen until someone taps it, so the snippet sets `persist: false`. Without it, nothing would ever get deleted.

```dart
class _InboxState extends State<Inbox> with UndoDelete {
  void _remove(Message m) {
    final index = _messages.indexOf(m);
    deleteWithUndo(
      message: 'Message deleted',
      undoLabel: 'Undo',
      failedMessage: "Couldn't delete the message",
      remove: () => _messages.remove(m),
      restore: () => _messages.insert(index, m),
      commit: () => api.deleteMessage(m.id),
    );
  }
}
```

**`async_button.dart`** is a `FilledButton` that takes an async `onPressed`. While it runs, the label is swapped for a spinner and the button is disabled. The label keeps its space, so the button doesn't change width. It enables again when the action finishes, whether it worked or threw. Catch errors inside `onPressed` and show them there.

```dart
AsyncButton(
  onPressed: () async {
    try {
      await api.placeOrder(cart);
    } on ApiException {
      showError();
    }
  },
  child: const Text('Place order'),
)
```

**`skeleton.dart`** has `Shimmer`, `SkeletonBox` and `SkeletonList`. `SkeletonList` draws rows shaped like a `ListTile` with an avatar, a title and a subtitle. Change it to match your real rows so nothing jumps when the data arrives. The shimmer holds still when the phone asks apps to reduce or remove animations, and sweeps the other way in RTL.

**`optimistic_toggle.dart`** is a heart button. It flips on tap and calls `onChanged`. If that throws, it flips back and shows `failedMessage`. Only the latest tap can roll back, so a slow failure from an earlier tap never undoes a newer one.

```dart
OptimisticToggle(
  value: post.liked,
  onChanged: (liked) => api.setLiked(post.id, liked),
  failedMessage: "Couldn't save your like",
)
```

**`empty_state.dart`** shows an icon, a title, one line of explanation and one button. It scrolls, so pull to refresh still works around it.

```dart
if (orders.isEmpty) {
  return EmptyState(
    icon: Icons.receipt_long_outlined,
    title: 'No orders yet',
    message: 'When you buy something, the receipt shows up here.',
    actionLabel: 'Browse the shop',
    onAction: openShop,
  );
}
```

The strings above are hardcoded to keep the examples short. Put them in your ARB files.

## The example app

[`example`](example) is a Flutter app for iOS and Android with one screen, a list of saved places:

- it opens on a skeleton while a fake request loads,
- swipe a row to delete it, with Undo,
- tap the heart to favorite a place,
- "Sync now" at the bottom counts how many requests were really sent, so you can tap it fast and see it stays at one per sync,
- delete every row to reach the empty state, which reloads the list.

Turn on "Fail requests" at the top and every fake request throws after a short delay. That shows the error paths: the heart flips back, the deleted row returns, and the sync button enables again with a message.

```bash
cd example
flutter run
```

The app has its own copy of the snippets in `example/lib/snippets`. Dart treats files under `lib` as package files, so they can't import `../snippets` by relative path.

## Use it as a skill

Clone it straight into your agent's skills folder, for example:

```bash
git clone https://github.com/TaheBenSaid/flutter-ux-details.git ~/.claude/skills/flutter-ux-details
```

Or into the skills folder inside one project. Then ask something like "make the delete flow feel nicer" or "stop users from paying twice". The skill runs the audit, picks the snippet for each finding, applies it, and runs `flutter analyze`.

## Use it in CI

The script exits with code 1 when it finds something and 2 when the path doesn't exist, so it can fail a pipeline. Copy `ux_audit.dart` into your repo, for example under `tools/`, and add a step:

```yaml
- run: dart tools/ux_audit.dart lib
```

Since these are heuristics, you may prefer to run it as a report and not block merges on it.

## More tools

This is part of a series of small Flutter tools, each tied to a problem I write about. The full list is in [flutter-skills](https://github.com/TaheBenSaid/flutter-skills).

## License

MIT
