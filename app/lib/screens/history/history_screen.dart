import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/daily_report.dart';
import '../../state/report_provider.dart';
import '../../theme/app_theme.dart';
import '../../util/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/meal_thumbnail.dart';

/// Read-only history: pick a past day and view that day's report
/// (`GET /report/{date}`). Browsing forward past today is disabled.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _selected = _dateOnly(DateTime.now());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String get _iso => DateFormat('yyyy-MM-dd').format(_selected);

  bool get _isToday => _selected == _dateOnly(DateTime.now());

  void _shift(int days) {
    final next = _dateOnly(_selected.add(Duration(days: days)));
    if (next.isAfter(_dateOnly(DateTime.now()))) return; // no future
    setState(() => _selected = next);
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
    );
    if (picked != null) setState(() => _selected = _dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportForDateProvider(_iso));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: Column(
          children: [
            _DateBar(
              label: DateFormat('EEE, d MMM yyyy').format(_selected),
              onPrev: () => _shift(-1),
              onNext: _isToday ? null : () => _shift(1),
              onPick: _pick,
            ),
            Expanded(
              child: reportAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ErrorBanner(err.toString()),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () =>
                              ref.invalidate(reportForDateProvider(_iso)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (report) => _DayReport(report: report),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  const _DateBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _DayReport extends StatelessWidget {
  final DailyReport report;
  const _DayReport({required this.report});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _Stat(label: 'Intake', value: '${report.totalIntakeKcal.round()}'),
                    _Stat(label: 'Burned', value: '${report.totalBurnedKcal.round()}'),
                    _Stat(label: 'Net', value: '${report.netKcal.round()}'),
                    if (report.targetKcal != null)
                      _Stat(label: 'Target', value: '${report.targetKcal!.round()}'),
                    if (report.remainingKcal != null)
                      _Stat(
                        label: 'Remaining',
                        value: '${report.remainingKcal!.round()}',
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  report.note,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Meals',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (report.meals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No meals logged this day',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
          )
        else
          ...report.meals.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        MealThumbnail(imagePath: m.imagePath, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.dish,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(gramsText(m.grams),
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        Text(
                          kcalText(m.kcal),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }
}
