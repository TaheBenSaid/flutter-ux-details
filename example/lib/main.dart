import 'dart:math';

import 'package:flutter/material.dart';

import 'snippets/async_button.dart';
import 'snippets/empty_state.dart';
import 'snippets/optimistic_toggle.dart';
import 'snippets/skeleton.dart';
import 'snippets/undo_delete.dart';
import 'fake_api.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UX details',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
      home: const PlacesPage(),
    );
  }
}

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> with UndoDelete {
  final _api = FakeApi();
  final _favorites = <int>{};
  List<Place>? _places;
  int _syncRequests = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _places = null);
    final places = await _api.fetchPlaces();
    if (!mounted) return;
    setState(() => _places = places);
  }

  void _remove(Place place) {
    final index = _places!.indexOf(place);
    deleteWithUndo(
      message: 'Removed ${place.name}',
      undoLabel: 'Undo',
      failedMessage: "Couldn't remove ${place.name}. It's back in your list.",
      remove: () => _places?.remove(place),
      restore: () {
        final places = _places;
        if (places == null || places.contains(place)) return;
        places.insert(min(index, places.length), place);
      },
      commit: _api.send,
    );
  }

  Future<void> _favorite(Place place, bool value) async {
    await _api.send();
    if (!mounted) return;
    setState(() => value ? _favorites.add(place.id) : _favorites.remove(place.id));
  }

  Future<void> _sync() async {
    setState(() => _syncRequests++);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.send(delay: const Duration(seconds: 2));
      messenger.showSnackBar(const SnackBar(content: Text('Everything is synced')));
    } on FakeApiException {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't sync. Check your connection and try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final places = _places;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved places'),
        actions: [
          IconButton(tooltip: 'Reload', onPressed: places == null ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Fail requests'),
            subtitle: const Text('Every fake request throws'),
            value: _api.fail,
            onChanged: (value) => setState(() => _api.fail = value),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (places) {
              null => const SkeletonList(),
              [] => EmptyState(
                icon: Icons.bookmark_border,
                title: 'No saved places',
                message: 'Places you save show up here, so you can find them again later.',
                actionLabel: 'Load sample places',
                onAction: _load,
              ),
              _ => ListView.builder(
                itemCount: places.length,
                itemBuilder: (context, i) => _PlaceTile(
                  place: places[i],
                  favorite: _favorites.contains(places[i].id),
                  onFavorite: (value) => _favorite(places[i], value),
                  onRemove: () => _remove(places[i]),
                ),
              ),
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: Text('Sync requests sent: $_syncRequests')),
            AsyncButton(onPressed: _sync, child: const Text('Sync now')),
          ],
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.favorite, required this.onFavorite, required this.onRemove});

  final Place place;
  final bool favorite;
  final Future<void> Function(bool value) onFavorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(place.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        color: colors.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
      ),
      child: ListTile(
        leading: CircleAvatar(child: Text(place.name[0])),
        title: Text(place.name),
        subtitle: Text(place.city),
        trailing: OptimisticToggle(
          value: favorite,
          onChanged: onFavorite,
          tooltip: 'Favorite',
          failedMessage: "Couldn't save your favorite. Try again.",
        ),
      ),
    );
  }
}
