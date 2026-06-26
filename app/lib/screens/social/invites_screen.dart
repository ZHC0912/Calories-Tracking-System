import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/social.dart';
import '../../state/social_provider.dart';
import '../../widgets/error_banner.dart';

/// Incoming community invites. Accepting enforces the 10-member cap on the
/// backend; a "full" community surfaces its error here rather than failing
/// silently.
class InvitesScreen extends ConsumerWidget {
  const InvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(invitesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invites')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(invitesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [ErrorBanner(err.toString())],
          ),
          data: (invites) => invites.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Icon(Icons.mark_email_read_outlined,
                        size: 44, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Center(
                      child: Text('No pending invites',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children:
                      invites.map((i) => _InviteTile(invite: i)).toList(),
                ),
        ),
      ),
    );
  }
}

class _InviteTile extends ConsumerStatefulWidget {
  final InviteRead invite;
  const _InviteTile({required this.invite});

  @override
  ConsumerState<_InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends ConsumerState<_InviteTile> {
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(communityApiProvider).acceptInvite(widget.invite.id);
      ref.invalidate(invitesProvider);
      ref.invalidate(myCommunitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${widget.invite.communityName}')),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.groups, size: 32),
              title: Text(invite.communityName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Invited by ${invite.inviter.displayName}'),
              trailing: FilledButton(
                onPressed: _busy ? null : _accept,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Accept'),
              ),
            ),
            if (_error != null) ErrorBanner(_error!),
          ],
        ),
      ),
    );
  }
}
