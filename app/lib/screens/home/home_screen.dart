import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/daily_report.dart';
import '../../state/report_provider.dart';
import '../../theme/app_theme.dart';
import '../../util/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/honesty_tag.dart';
import '../../widgets/meal_thumbnail.dart';
import '../social/share_sheet_screen.dart';

/// Today's view: intake, burned, net, target/remaining (when the profile
/// provides them), macro totals, and the meals logged so far. Hosted inside the
/// bottom-nav shell, which provides the capture entry point.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(todayReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'Share your day',
            icon: const Icon(Icons.ios_share),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShareSheetScreen()),
            ),
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(todayReportProvider),
        ),
        data: (report) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(todayReportProvider),
          child: _ReportBody(report: report),
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final DailyReport report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _SummaryCard(report: report),
        const SizedBox(height: 24),
        Text(
          'Meals',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (report.meals.isEmpty)
          const _EmptyMeals()
        else
          ...report.meals.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MealCard(meal: m),
              )),
        const SizedBox(height: 16),
        Center(
          child: Text(
            report.note,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DailyReport report;
  const _SummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Eaten today',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${report.totalIntakeKcal.round()}',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('kcal', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
            if (report.totalBurnedKcal > 0)
              Text(
                'Exercise burned ${report.totalBurnedKcal.round()} kcal · '
                'net ${report.netKcal.round()} kcal',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            const SizedBox(height: 16),
            if (report.hasTarget)
              _TargetProgress(report: report)
            else
              const _NoTargetHint(),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _MacrosRow(report: report),
          ],
        ),
      ),
    );
  }
}

class _MacrosRow extends StatelessWidget {
  final DailyReport report;
  const _MacrosRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Macro(label: 'Protein', grams: report.totalProtein),
        _Macro(label: 'Fat', grams: report.totalFat),
        _Macro(label: 'Carbs', grams: report.totalCarbs),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final double grams;
  const _Macro({required this.label, required this.grams});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${grams.round()} g',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}

class _TargetProgress extends StatelessWidget {
  final DailyReport report;
  const _TargetProgress({required this.report});

  @override
  Widget build(BuildContext context) {
    final target = report.targetKcal!;
    final remaining = report.remainingKcal;
    final progress = target > 0 ? (report.netKcal / target).clamp(0.0, 1.0) : 0.0;
    final over = remaining != null && remaining < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: const Color(0xFFEFE7DD),
            valueColor: AlwaysStoppedAnimation(
              over ? Colors.red.shade400 : AppTheme.accent,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          over
              ? 'Over target by ${(-remaining).round()} kcal'
              : 'Target ${target.round()} kcal · '
                  '${(remaining ?? 0).round()} kcal remaining',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
      ],
    );
  }
}

class _NoTargetHint extends StatelessWidget {
  const _NoTargetHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_outlined,
              size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Set up your profile to see your daily target.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealEntry meal;
  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            MealThumbnail(imagePath: meal.imagePath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.dish,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        gramsText(meal.grams),
                        style:
                            TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      HonestyTag(
                        label: gramSourceLabel(meal.gramSource, meal.grams),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              kcalText(meal.kcal),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.no_meals_outlined, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No meals logged yet today',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Log a meal" to snap your first one.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorBanner(message),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
