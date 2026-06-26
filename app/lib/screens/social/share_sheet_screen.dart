import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/social.dart';
import '../../state/social_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_banner.dart';

/// The explicit share sheet. NOTHING is sent until the user taps Share.
/// `GET /share/preview` pre-ticks the PARTS from the user's saved friend
/// defaults; target communities start unselected so sharing is always a
/// deliberate choice. Body-derived parts default OFF and are clearly labeled.
class ShareSheetScreen extends ConsumerStatefulWidget {
  /// ISO date (YYYY-MM-DD) to share; null = the backend's today.
  final String? date;
  const ShareSheetScreen({super.key, this.date});

  @override
  ConsumerState<ShareSheetScreen> createState() => _ShareSheetScreenState();
}

class _ShareSheetScreenState extends ConsumerState<ShareSheetScreen> {
  bool _loading = true;
  bool _sharing = false;
  String? _error;

  SharePreview? _preview;
  ShareParts _parts = const ShareParts();
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preview = await ref.read(feedApiProvider).sharePreview(widget.date);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _parts = preview.suggestedParts();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _share() async {
    final preview = _preview;
    if (preview == null || _selected.isEmpty) return;
    setState(() {
      _sharing = true;
      _error = null;
    });
    try {
      final posts = await ref.read(feedApiProvider).share(
            date: preview.date,
            parts: _parts,
            communityIds: _selected.toList(),
          );
      // Refresh the feeds we just posted into.
      for (final id in _selected) {
        ref.invalidate(feedProvider(id));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Shared to ${posts.length} '
                'communit${posts.length == 1 ? 'y' : 'ies'}')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share your day')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final preview = _preview;
    if (preview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBanner(_error ?? 'Could not load the share sheet.'),
        ),
      );
    }

    if (!preview.hasReport) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_food_outlined, size: 44, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('Nothing logged on ${preview.date} to share',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    final canShare = !_sharing && _selected.isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Sharing ${preview.date}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 16),

                _sectionTitle('What to include'),
                _PartTile(
                  title: 'Net calories',
                  subtitle: 'Intake, burned, and net',
                  value: _parts.includeNetCalories,
                  onChanged: (v) => setState(
                      () => _parts = _parts.copyWith(includeNetCalories: v)),
                ),
                _PartTile(
                  title: 'Macros',
                  subtitle: 'Protein / fat / carbs',
                  value: _parts.includeMacros,
                  onChanged: (v) =>
                      setState(() => _parts = _parts.copyWith(includeMacros: v)),
                ),
                _PartTile(
                  title: 'Food photos',
                  subtitle: 'Your meal images for the day',
                  value: _parts.includeFoodImages,
                  onChanged: (v) => setState(
                      () => _parts = _parts.copyWith(includeFoodImages: v)),
                ),
                _PartTile(
                  title: 'Calorie target & remaining',
                  subtitle: 'More revealing (body-derived) — off by default',
                  value: _parts.includeTarget,
                  highlight: true,
                  onChanged: (v) =>
                      setState(() => _parts = _parts.copyWith(includeTarget: v)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Consistency signals (whether you logged, item counts) are '
                  'always included. Your weight/height/age are never shared.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),

                const SizedBox(height: 20),
                _sectionTitle('Share to'),
                if (preview.myCommunities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Join or create a community first (Community tab).',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  ...preview.myCommunities.map((c) => CheckboxListTile(
                        value: _selected.contains(c.id),
                        onChanged: (on) => setState(() {
                          if (on == true) {
                            _selected.add(c.id);
                          } else {
                            _selected.remove(c.id);
                          }
                        }),
                        title: Text(c.name),
                        subtitle: Text('${c.memberCount} / 10 members'),
                      )),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(_error!),
                ],
              ],
            ),
          ),
          _ShareBar(
            count: _selected.length,
            canShare: canShare,
            sharing: _sharing,
            onShare: _share,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      );
}

class _PartTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool highlight;

  const _PartTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: highlight ? Colors.orange.shade800 : null,
          )),
      subtitle: Text(subtitle),
    );
  }
}

class _ShareBar extends StatelessWidget {
  final int count;
  final bool canShare;
  final bool sharing;
  final VoidCallback onShare;

  const _ShareBar({
    required this.count,
    required this.canShare,
    required this.sharing,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: canShare ? onShare : null,
        icon: sharing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.send),
        label: Text(
          sharing
              ? 'Sharing…'
              : count == 0
                  ? 'Select a community to share'
                  : 'Share to $count',
        ),
      ),
    );
  }
}
