import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/social.dart';
import '../../state/social_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_banner.dart';
import 'feed_screen.dart';

/// Members-only community view: the member list, an invite-a-friend action
/// (friend-gated, cap 10), and a shortcut to the feed.
class CommunityDetailScreen extends ConsumerWidget {
  final CommunityRead community;
  const CommunityDetailScreen({super.key, required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(communityMembersProvider(community.id));
    final full = community.memberCount >= 10;

    return Scaffold(
      appBar: AppBar(
        title: Text(community.name),
        actions: [
          IconButton(
            tooltip: 'Feed',
            icon: const Icon(Icons.dynamic_feed_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FeedScreen(community: community),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(communityMembersProvider(community.id)),
        child: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [ErrorBanner(err.toString())],
          ),
          data: (members) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              FilledButton.icon(
                onPressed: full
                    ? null
                    : () => _openInviteSheet(context, ref, members),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(full ? 'Community full (10/10)' : 'Invite a friend'),
              ),
              const SizedBox(height: 8),
              Text(
                'Only accepted friends can be invited. Max 10 members.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              Text('Members (${members.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ...members.map((m) => _MemberTile(member: m)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInviteSheet(
    BuildContext context,
    WidgetRef ref,
    List<CommunityMemberRead> members,
  ) async {
    final memberIds = members.map((m) => m.user.id).toSet();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteFriendSheet(
        communityId: community.id,
        memberIds: memberIds,
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final CommunityMemberRead member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final isOwner = member.role == 'owner';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOwner ? AppTheme.accent : null,
          child: Text(
            member.user.displayName.isEmpty
                ? '?'
                : member.user.displayName[0].toUpperCase(),
            style: TextStyle(color: isOwner ? Colors.white : null),
          ),
        ),
        title: Text(member.user.displayName),
        subtitle: Text(member.user.handle),
        trailing: isOwner
            ? const Chip(
                label: Text('owner'),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }
}

/// A sheet listing friends who aren't already members, to invite one.
class _InviteFriendSheet extends ConsumerStatefulWidget {
  final int communityId;
  final Set<int> memberIds;
  const _InviteFriendSheet({required this.communityId, required this.memberIds});

  @override
  ConsumerState<_InviteFriendSheet> createState() => _InviteFriendSheetState();
}

class _InviteFriendSheetState extends ConsumerState<_InviteFriendSheet> {
  int? _inviting;

  Future<void> _invite(PublicUser friend) async {
    setState(() => _inviting = friend.id);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(communityApiProvider)
          .invite(widget.communityId, friend.id);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Invited ${friend.displayName}')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _inviting = null);
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: friendsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => ErrorBanner(err.toString()),
          data: (friends) {
            final invitable =
                friends.where((f) => !widget.memberIds.contains(f.id)).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Invite a friend',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 12),
                if (invitable.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      friends.isEmpty
                          ? 'Add friends first, then invite them here.'
                          : 'All your friends are already members.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: invitable
                          .map((f) => ListTile(
                                leading: CircleAvatar(
                                  child: Text(f.displayName.isEmpty
                                      ? '?'
                                      : f.displayName[0].toUpperCase()),
                                ),
                                title: Text(f.displayName),
                                subtitle: Text(f.handle),
                                trailing: _inviting == f.id
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.send),
                                onTap: _inviting == null
                                    ? () => _invite(f)
                                    : null,
                              ))
                          .toList(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
