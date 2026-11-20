import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _notes = ['Groceries', 'Gym plan', 'Book ideas'];

  Future<void> _confirmDelete(String note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) setState(() => _notes.remove(note));
  }

  @override
  Widget build(BuildContext context) {
    if (_notes.isEmpty) return const Center(child: Text('No notes'));
    return ListView.builder(
      itemCount: _notes.length,
      itemBuilder: (context, i) => ListTile(
        title: Text(_notes[i]),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmDelete(_notes[i])),
      ),
    );
  }
}
