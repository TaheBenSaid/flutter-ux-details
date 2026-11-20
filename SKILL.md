---
name: flutter-ux-details
description: Find and fix the small UX gaps that make a Flutter app feel cheap. Use when the user asks to polish an app, mentions an "Are you sure?" dialog, undo on delete, double taps, double submit or double payment, a loading spinner, skeleton or shimmer loaders, optimistic updates, like or favorite buttons, empty lists, empty states or blank screens.
---

# Flutter UX details

The scanner is `scripts/ux_audit.dart` in this skill's folder. It has no dependencies, so it runs anywhere Dart runs. The copy-paste files are in `snippets/`, one per detail. They only use `package:flutter/material.dart` and need Flutter 3.38 or newer.

## Steps

1. From the Flutter project root, scan:

   ```bash
   dart <skill-folder>/scripts/ux_audit.dart lib
   ```

   Show the user the summary line and the findings. If the list is long, group them by file and by detail.

2. Read every finding in context before changing it. The checks are heuristics. Drop the ones that don't apply and tell the user why, for example:

   - a confirm dialog for something that can't be undone (deleting an account, cancelling a paid plan, leaving a group),
   - a centered spinner on a splash screen, a video player or a full-screen image,
   - a list that can never be empty, like a fixed set of tabs or options.

3. Copy only the snippets you need into the project. Put them where the project keeps shared widgets, for example `lib/core/widgets/`. Follow the project's conventions: if it has design tokens, a sizing package or localized strings, swap the snippet's raw sizes, colors and text for those. Don't add packages.

4. Apply the matching snippet for each finding that stays:

   - **Confirm dialog** (`undo_delete.dart`): add `with UndoDelete` to the `State`. Replace the dialog with `deleteWithUndo`. `remove` takes the item out of local state, `restore` puts it back at the same index, and `commit` is the real delete call. If the app uses Bloc or another state holder, `remove` and `restore` dispatch events, and `commit` calls the use case or repository. Keep the server call in `commit` so nothing is deleted until the SnackBar closes.
   - **Double tap** (`async_button.dart`): swap the button for `AsyncButton` when it's a plain filled button. For other buttons or tappable widgets, add a busy flag instead: return early if it's set, set it before the first await, clear it in `finally`, and pass `null` to `onPressed` while it's set. If the app uses Bloc, use the loading state the bloc already has.
   - **Centered spinner** (`skeleton.dart`): replace it with `SkeletonList`, or build a skeleton from `Shimmer` and `SkeletonBox` that matches the real layout (same paddings, avatar size, line count). The goal is that nothing jumps when data arrives.
   - **Empty list** (`empty_state.dart`): add an `isEmpty` branch before the list and return `EmptyState` with a title, one line that says what goes here, and one action that makes sense (create the first item, clear the filters, reload). Ask the user for the copy if the right action isn't obvious.

5. While you're in those files, look for places that would suit `optimistic_toggle.dart`: like, favorite, follow, bookmark or mute buttons that wait for the server before changing. Suggest it, and apply it if the user agrees. The request has to throw on failure for the rollback to work.

6. Run `flutter analyze` and fix anything you introduced. Run the scanner again and show the user what's left, with a reason for each finding you chose to keep.

## Rules

- Only use undo for actions that can really be reversed. Payments, account deletion and anything sent to other people keep their confirm step.
- Never call the delete API before the undo window closes.
- Every async action that writes data must ignore a second tap while it runs.
- Roll back optimistic changes on failure and tell the user. Never leave the UI showing something the server rejected.
- Dispose every controller and timer you add, and check `mounted` after every await before touching `context` or calling `setState`.
- Use `EdgeInsetsDirectional` and `AlignmentDirectional` so layouts work in RTL.

## Not covered by the scanner

Mention these if the user wants a full pass:

- Error states with a retry button, and offline banners.
- Pull to refresh on lists.
- Haptic feedback on important actions.
- Keyboard handling: the right `TextInputAction`, moving focus to the next field, submitting on done.
- Images without a placeholder or with no fixed size, which make the layout jump when they load.
