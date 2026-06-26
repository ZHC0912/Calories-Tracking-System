import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/social.dart';
import '../../state/social_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_banner.dart';
import 'share_defaults_screen.dart';

/// Friends list + search-to-add. There is no incoming-request list endpoint;
/// the backend auto-accepts when you request someone who already requested you,
/// so "Add" both sends and (when mutual) accepts.
class FriendsTab extends ConsumerStatefulWidget {
  const FriendsTab({super.key});

  @override
  ConsumerState<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<FriendsTab> {
  final _search = TextEditingController();
  List<PublicUser> _results = [];
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final handle = _search.text.trim();
    if (handle.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await ref.read(friendsApiProvider).search(handle);
      if (mounted) setState(() => _results = results);
    } on ApiException catch (e) {
      if (mounted) setState(() => _searchError = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(PublicUser user) async {
    try {
      final status = await ref.read(friendsApiProvider).sendRequest(user.id);
      ref.invalidate(friendsProvider);
      if (!mounted) return;
      final msg = status == 'accepted'
          ? "You're now friends with ${user.displayName}"
          : 'Friend request sent to ${user.displayName}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(friendsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Find people by email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _runSearch,
                    ),
            ),
            onSubmitted: (_) => _runSearch(),
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(_searchError!),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Search results'),
            ..._results.map((u) => _SearchResultTile(user: u, onAdd: () => _add(u))),
          ],
          const SizedBox(height: 16),
          _sectionTitle('Your friends'),
          friendsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => ErrorBanner(err.toString()),
            data: (friends) => friends.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No friends yet — search above to add some.',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ),
                  )
                : Column(
                    children: friends.map((f) => _FriendTile(friend: f)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      );
}

class _SearchResultTile extends StatelessWidget {
  final PublicUser user;
  final VoidCallback onAdd;
  const _SearchResultTile({required this.user, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(_initial(user.displayName))),
        title: Text(user.displayName),
        subtitle: Text(user.handle),
        trailing: TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_alt, size: 18),
          label: const Text('Add'),
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final PublicUser friend;
  const _FriendTile({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accent,
          child: Text(_initial(friend.displayName),
              style: const TextStyle(color: Colors.white)),
        ),
        title: Text(friend.displayName),
        subtitle: Text(friend.handle),
        trailing: const Icon(Icons.tune),
        // Tapping a friend edits what auto-pre-ticks when sharing with them.
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShareDefaultsScreen(friend: friend),
          ),
        ),
      ),
    );
  }
}

String _initial(String name) =>
    name.isEmpty ? '?' : name[0].toUpperCase();
