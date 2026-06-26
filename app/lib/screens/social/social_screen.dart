import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/social_provider.dart';
import 'communities_tab.dart';
import 'friends_tab.dart';
import 'invites_screen.dart';

/// The social tab. Two surfaces — Communities and Friends — plus an invites
/// shortcut. This is an encouragement tool, not a chat app: there is no
/// free-text anywhere, reactions are a fixed emoji set, and sharing is always an
/// explicit tap (see the share sheet).
class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(invitesProvider);
    final inviteCount = invitesAsync.maybeWhen(
      data: (i) => i.length,
      orElse: () => 0,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community'),
          actions: [
            _InvitesButton(
              count: inviteCount,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InvitesScreen()),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Communities'),
              Tab(text: 'Friends'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [CommunitiesTab(), FriendsTab()],
        ),
      ),
    );
  }
}

class _InvitesButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _InvitesButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Invites',
          icon: const Icon(Icons.mail_outline),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}
