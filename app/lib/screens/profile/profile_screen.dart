import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../models/profile.dart';
import '../../state/auth_provider.dart';
import '../../state/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../util/profile_options.dart';
import '../../widgets/error_banner.dart';
import '../settings/settings_screen.dart';
import 'profile_edit_screen.dart';

/// Profile tab: backend-computed summary (BMI + caveat, daily target, guidance,
/// disclaimer), the stored stats, the training-consent toggle, and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          final unauthorized = err is ApiException && err.isUnauthorized;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ErrorBanner(err.toString()),
                  const SizedBox(height: 16),
                  // A dead token can't be retried — send the user to log in.
                  if (unauthorized)
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).logout(),
                      icon: const Icon(Icons.login),
                      label: const Text('Log in again'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(profileProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                ],
              ),
            ),
          );
        },
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(profileProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 16),
              _StatsCard(summary: summary),
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
            Text(summary.displayName,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18)),
            Text(summary.email,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),
            if (summary.targetKcal != null) ...[
              Row(
                children: [
                  Text('Daily calorie target',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  if (summary.targetIsCustom) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Custom',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.accent)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${summary.targetKcal!.round()} kcal',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: context.accent,
                ),
              ),
              if (!summary.targetIsCustom &&
                  summary.bmrKcal != null &&
                  summary.tdeeKcal != null)
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
