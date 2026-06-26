import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/social.dart';
import '../../state/social_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/meal_thumbnail.dart';

/// Chronological community feed of shared daily snapshots. Each card shows ONLY
/// the parts the author chose to share. The only interaction is a fixed-emoji
/// reaction — there is no comment field anywhere.
class FeedScreen extends ConsumerWidget {
  final CommunityRead community;
  const FeedScreen({super.key, required this.community});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedProvider(community.id));

    return Scaffold(
      appBar: AppBar(title: Text(community.name)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feedProvider(community.id)),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ErrorBanner(err.toString()),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(feedProvider(community.id)),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
          data: (posts) => posts.isEmpty
              ? _empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: posts.map((p) => _FeedCard(post: p)).toList(),
                ),
        ),
      ),
    );
  }

  Widget _empty() => ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.dynamic_feed_outlined,
              size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Center(
            child: Text('Nothing shared yet',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Share your day from the Today tab.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ),
        ],
      );
}

class _FeedCard extends StatelessWidget {
  final FeedPostRead post;
  const _FeedCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final s = post.snapshot;
    String dateLabel;
    try {
      dateLabel = DateFormat('EEE, d MMM').format(DateTime.parse(post.reportDate));
    } catch (_) {
      dateLabel = post.reportDate;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.accent,
                  child: Text(
                    post.author.displayName.isEmpty
                        ? '?'
                        : post.author.displayName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(dateLabel,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ConsistencyLine(snapshot: s),
            if (s.hasNet) ...[
              const SizedBox(height: 10),
              _StatsRow(snapshot: s),
            ],
            if (s.hasMacros) ...[
              const SizedBox(height: 10),
              _MacrosLine(snapshot: s),
            ],
            if (s.hasTarget && s.target != null) ...[
              const SizedBox(height: 8),
              Text(
                'Target ${s.target!.round()} kcal'
                '${s.remaining != null ? ' · ${s.remaining!.round()} remaining' : ''}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
            if (s.hasFoodImages) ...[
              const SizedBox(height: 12),
              _FoodImagesRow(snapshot: s),
            ],
            const Divider(height: 24),
            _ReactionBar(postId: post.id, initial: post.reactions),
          ],
        ),
      ),
    );
  }
}

class _ConsistencyLine extends StatelessWidget {
  final Snapshot snapshot;
  const _ConsistencyLine({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    parts.add(snapshot.logged ? 'Logged today' : 'Nothing logged');
    if (snapshot.mealsCount > 0) parts.add('${snapshot.mealsCount} meals');
    if (snapshot.exercisesCount > 0) {
      parts.add('${snapshot.exercisesCount} workouts');
    }
    return Row(
      children: [
        Icon(
          snapshot.logged ? Icons.check_circle : Icons.remove_circle_outline,
          size: 18,
          color: snapshot.logged ? AppTheme.accent : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(parts.join(' · '),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Snapshot snapshot;
  const _StatsRow({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: [
        _stat('Intake', snapshot.intake),
        _stat('Burned', snapshot.burned),
        _stat('Net', snapshot.net),
      ],
    );
  }

  Widget _stat(String label, double? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value == null ? '—' : '${value.round()}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text('$label kcal',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }
}

class _MacrosLine extends StatelessWidget {
  final Snapshot snapshot;
  const _MacrosLine({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    String g(double? v) => v == null ? '—' : '${v.round()}g';
    return Text(
      'Protein ${g(snapshot.protein)} · Fat ${g(snapshot.fat)} · '
      'Carbs ${g(snapshot.carbs)}',
      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
    );
  }
}

class _FoodImagesRow extends StatelessWidget {
  final Snapshot snapshot;
  const _FoodImagesRow({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final images = snapshot.foodImages;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) =>
            MealThumbnail(imagePath: images[i].imagePath, size: 72),
      ),
    );
  }
}

/// The only interaction: a single reaction from the fixed emoji set, changeable,
/// removable. No free text.
class _ReactionBar extends ConsumerStatefulWidget {
  final int postId;
  final ReactionCounts initial;
  const _ReactionBar({required this.postId, required this.initial});

  @override
  ConsumerState<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends ConsumerState<_ReactionBar> {
  late ReactionCounts _state = widget.initial;
  bool _busy = false;

  Future<void> _tap(String emoji) async {
    if (_busy) return;
    setState(() => _busy = true);
    final api = ref.read(feedApiProvider);
    try {
      final result = _state.myReaction == emoji
          ? await api.unreact(widget.postId) // toggle off
          : await api.react(widget.postId, emoji);
      if (mounted) setState(() => _state = result);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: allowedReactions.map((emoji) {
        final count = _state.counts[emoji] ?? 0;
        final mine = _state.myReaction == emoji;
        return GestureDetector(
          onTap: () => _tap(emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: mine
                  ? AppTheme.accent.withValues(alpha: 0.15)
                  : const Color(0xFFF3EEE8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mine ? AppTheme.accent : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text('$count',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
