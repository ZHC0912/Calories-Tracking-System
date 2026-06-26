import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/social.dart';
import '../../state/social_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_banner.dart';
import 'community_detail_screen.dart';

/// Communities I belong to, with a create action. Communities are invite-only,
/// friend-gated, and capped at 10 members (enforced by the backend).
class CommunitiesTab extends ConsumerWidget {
  const CommunitiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCommunitiesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myCommunitiesProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorList(
          message: err.toString(),
          onRetry: () => ref.invalidate(myCommunitiesProvider),
        ),
        data: (communities) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            FilledButton.icon(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.group_add),
              label: const Text('Create a community'),
            ),
            const SizedBox(height: 16),
            if (communities.isEmpty)
              _empty()
            else
              ...communities.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CommunityCard(community: c),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.groups_outlined, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No communities yet',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(
              'Create one, then invite friends (max 10 members).',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateCommunityDialog(controller: controller, ref: ref),
    );
    controller.dispose();
    if (created == true) ref.invalidate(myCommunitiesProvider);
  }
}

class _CreateCommunityDialog extends StatefulWidget {
  final TextEditingController controller;
  final WidgetRef ref;
  const _CreateCommunityDialog({required this.controller, required this.ref});

  @override
  State<_CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<_CreateCommunityDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _create() async {
    final name = widget.controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ref.read(communityApiProvider).create(name);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New community'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            autofocus: true,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Weekend Runners',
            ),
            onSubmitted: (_) => _create(),
          ),
          if (_error != null) ErrorBanner(_error!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _CommunityCard extends StatelessWidget {
  final CommunityRead community;
  const _CommunityCard({required this.community});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: AppTheme.accent,
          child: Icon(Icons.groups, color: Colors.white),
        ),
        title: Text(community.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${community.memberCount} / 10 members'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CommunityDetailScreen(community: community),
          ),
        ),
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorList({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ErrorBanner(message),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}
