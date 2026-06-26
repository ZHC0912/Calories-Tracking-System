import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/profile.dart';
import '../../state/auth_provider.dart';
import '../../state/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../util/profile_options.dart';
import '../../widgets/error_banner.dart';
import 'profile_edit_screen.dart';

/// Profile tab: backend-computed summary (BMI + caveat, daily target, guidance,
/// disclaimer), the stored stats, the training-consent toggle, and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorBanner(err.toString()),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(profileProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(profileProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 16),
              _StatsCard(summary: summary),
              const SizedBox(height: 16),
              _TrainingConsentTile(summary: summary),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ProfileSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary.email,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (summary.targetKcal != null) ...[
              Text('Daily calorie target',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                '${summary.targetKcal!.round()} kcal',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accent,
                ),
              ),
              if (summary.bmrKcal != null && summary.tdeeKcal != null)
                Text(
                  'BMR ${summary.bmrKcal!.round()} · '
                  'TDEE ${summary.tdeeKcal!.round()} kcal',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
            ] else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEE8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Complete your stats below to see your daily target.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            if (summary.bmi != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('BMI ',
                      style: TextStyle(color: Colors.grey.shade600)),
                  Text(
                    summary.bmi!.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (summary.bmiNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    summary.bmiNote!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              summary.activityGuidance,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              summary.note,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final ProfileSummary summary;
  const _StatsCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Your details',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileEditScreen(current: summary),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _row('Weight', summary.weightKg == null
                ? '—'
                : '${summary.weightKg!.round()} kg'),
            _row('Height', summary.heightCm == null
                ? '—'
                : '${summary.heightCm!.round()} cm'),
            _row('Age', summary.age?.toString() ?? '—'),
            _row('Sex', labelFor(sexes, summary.sex)),
            _row('Activity', labelFor(activityLevels, summary.activityLevel)),
            _row('Goal', labelFor(goals, summary.goal)),
            _row('Timezone', summary.timezone),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
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
