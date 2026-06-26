import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/report_api.dart';
import '../models/daily_report.dart';
import 'auth_provider.dart';

final reportApiProvider = Provider<ReportApi>(
  (ref) => ReportApi(ref.read(apiClientProvider)),
);

/// Today's report for the home view. Invalidate it after logging a meal to
/// pull the freshly recomputed totals; auto-disposed so it refetches when the
/// home screen is shown again.
final todayReportProvider = FutureProvider.autoDispose<DailyReport>((ref) {
  return ref.read(reportApiProvider).today();
});

/// A past day's report (read-only history), keyed by ISO date YYYY-MM-DD.
final reportForDateProvider =
    FutureProvider.autoDispose.family<DailyReport, String>((ref, isoDate) {
  return ref.read(reportApiProvider).forDate(isoDate);
});
