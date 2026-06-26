import '../models/daily_report.dart';
import 'api_client.dart';

/// `GET /report/today` (api/report.py) — the daily intake-vs-target report for
/// the user's current local day. Requires a bearer token.
class ReportApi {
  final ApiClient client;
  const ReportApi(this.client);

  Future<DailyReport> today() => _get('/report/today');

  /// `GET /report/{YYYY-MM-DD}` — a past day's report (read-only history).
  Future<DailyReport> forDate(String isoDate) => _get('/report/$isoDate');

  Future<DailyReport> _get(String path) async {
    try {
      final res = await client.dio.get(path);
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return DailyReport.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }
}
