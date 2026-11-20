import 'package:flutter/material.dart';

Future<void> saveProfile() => Future<void>.delayed(const Duration(seconds: 1));
Future<void> setFavorite(bool value) => Future<void>.delayed(const Duration(milliseconds: 300));

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.drafts});

  final List<String> drafts;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _saving = false;
  bool _favorite = false;

  // An old version asked showDialog('Are you sure you want to delete?') here.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await saveProfile();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final previous = _favorite;
    setState(() => _favorite = !previous);
    try {
      await setFavorite(!previous);
    } on Exception {
      if (mounted) setState(() => _favorite = previous);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out'))],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const hint = 'Never return Center(child: CircularProgressIndicator()) here';
    return Column(
      children: [
        const Text(hint),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
        IconButton(onPressed: _toggleFavorite, icon: Icon(_favorite ? Icons.favorite : Icons.favorite_border)),
        ListTile(
          title: const Text('Edit avatar'),
          onTap: () async {
            await Navigator.pushNamed(context, '/avatar');
          },
        ),
        TextButton(onPressed: _signOut, child: const Text('Sign out')),
        Expanded(
          child: widget.drafts.isEmpty
              ? const Center(child: Text('No drafts yet'))
              : ListView.builder(
                  itemCount: widget.drafts.length,
                  itemBuilder: (context, i) => ListTile(title: Text(widget.drafts[i])),
                ),
        ),
      ],
    );
  }
}
