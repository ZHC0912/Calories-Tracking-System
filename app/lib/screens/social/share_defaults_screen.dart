import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/social.dart';
import '../../state/social_provider.dart';
import '../../widgets/error_banner.dart';

/// Per-friend share defaults: what gets PRE-TICKED on the share sheet for this
/// friend. Defaults never send anything on their own — they only pre-select.
/// Body-derived "target" stays a deliberate, clearly-labeled opt-in.
class ShareDefaultsScreen extends ConsumerStatefulWidget {
  final PublicUser friend;
  const ShareDefaultsScreen({super.key, required this.friend});

  @override
  ConsumerState<ShareDefaultsScreen> createState() =>
      _ShareDefaultsScreenState();
}

class _ShareDefaultsScreenState extends ConsumerState<ShareDefaultsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _enabled = false;
  ShareParts _parts = const ShareParts();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d =
          await ref.read(feedApiProvider).getShareDefault(widget.friend.id);
      if (!mounted) return;
      setState(() {
        _enabled = d.enabled;
        _parts = d.parts;
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(feedApiProvider).setShareDefault(widget.friend.id, {
        'enabled': _enabled,
        'include_net_calories': _parts.includeNetCalories,
        'include_macros': _parts.includeMacros,
        'include_food_images': _parts.includeFoodImages,
        'include_target': _parts.includeTarget,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Defaults saved')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Share defaults · ${widget.friend.displayName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'When you open the share sheet, these pre-tick what to '
                    'share with ${widget.friend.displayName}. Nothing is sent '
                    'until you tap Share.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: const Text('Pre-tick this friend by default'),
                  ),
                  const Divider(),
                  SwitchListTile(
                    value: _parts.includeNetCalories,
                    onChanged: (v) => setState(
                        () => _parts = _parts.copyWith(includeNetCalories: v)),
                    title: const Text('Net calories'),
                    subtitle: const Text('Intake, burned, and net'),
                  ),
                  SwitchListTile(
                    value: _parts.includeMacros,
                    onChanged: (v) => setState(
                        () => _parts = _parts.copyWith(includeMacros: v)),
                    title: const Text('Macros'),
                    subtitle: const Text('Protein / fat / carbs'),
                  ),
                  SwitchListTile(
                    value: _parts.includeFoodImages,
                    onChanged: (v) => setState(
                        () => _parts = _parts.copyWith(includeFoodImages: v)),
                    title: const Text('Food photos'),
                  ),
                  SwitchListTile(
                    value: _parts.includeTarget,
                    onChanged: (v) => setState(
                        () => _parts = _parts.copyWith(includeTarget: v)),
                    title: const Text('Calorie target & remaining'),
                    subtitle: const Text(
                        'More revealing (body-derived) — off by default'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(_error!),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save defaults'),
                  ),
                ],
              ),
            ),
    );
  }
}
