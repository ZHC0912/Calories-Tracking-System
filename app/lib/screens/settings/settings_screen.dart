import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/profile.dart';
import '../../state/profile_provider.dart';
import '../../state/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_edit_screen.dart';

/// App settings, reached from the Profile tab's gear icon: edit body stats /
/// timezone / calorie target (via the profile editor), the accent theme color,
/// and the "help improve recognition" privacy toggle.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const _SectionLabel('Profile'),
          Card(
            child: profileAsync.when(
              loading: () => const ListTile(
                leading: Icon(Icons.straighten),
                title: Text('Body stats, goal & timezone'),
                subtitle: Text('Loading…'),
              ),
              error: (err, _) => ListTile(
                leading: const Icon(Icons.straighten),
                title: const Text('Body stats, goal & timezone'),
                subtitle: Text(err.toString()),
              ),
              data: (summary) => ListTile(
                leading: const Icon(Icons.straighten),
                title: const Text('Body stats, goal & timezone'),
                subtitle: const Text(
                  'Weight, height, age, activity, goal, timezone & calorie target',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileEditScreen(current: summary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Appearance'),
          const Card(child: _ThemeColorPicker()),
          const SizedBox(height: 20),
          const _SectionLabel('Privacy'),
          profileAsync.maybeWhen(
            data: (summary) => _TrainingConsentTile(summary: summary),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

/// A row of curated accent swatches; tapping one applies + persists it.
class _ThemeColorPicker extends ConsumerWidget {
  const _ThemeColorPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentColorProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Theme color',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Choose the app accent color.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final color in AppTheme.accentOptions)
                _Swatch(
                  color: color,
                  selected: color.toARGB32() == accent.toARGB32(),
                  onTap: () =>
                      ref.read(accentColorProvider.notifier).setAccent(color),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.ink : Colors.black.withValues(alpha: 0.1),
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}

/// Consent toggle for using meal images to improve the model. Writes via
/// PUT /profile immediately; plain-language explanation included.
class _TrainingConsentTile extends ConsumerStatefulWidget {
  final ProfileSummary summary;
  const _TrainingConsentTile({required this.summary});

  @override
  ConsumerState<_TrainingConsentTile> createState() =>
      _TrainingConsentTileState();
}

class _TrainingConsentTileState extends ConsumerState<_TrainingConsentTile> {
  late bool _value = widget.summary.allowTrainingUse;
  bool _saving = false;

  Future<void> _toggle(bool next) async {
    setState(() {
      _value = next;
      _saving = true;
    });
    try {
      await ref
          .read(profileApiProvider)
          .update(ProfileUpdate(allowTrainingUse: next));
      ref.invalidate(profileProvider);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _value = !next); // revert on failure
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _value,
              onChanged: _saving ? null : _toggle,
              title: const Text('Help improve recognition',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Allow my meal photos to train the model'),
            ),
            Text(
              'If on, your meal photos (with location/EXIF data removed) may be '
              'kept to improve dish recognition. Off by default; you can change '
              'this anytime. Existing logs are unaffected.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
