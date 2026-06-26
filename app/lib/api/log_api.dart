import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/auth.dart';
import '../models/daily_report.dart';
import 'api_client.dart';

/// `POST /log/food` (api/log.py) — multipart with:
///   - `items`: a JSON string matching `LogFoodRequest` = `{"items": [...]}`
///   - `image`: an optional meal photo file
///
/// Returns the persisted entries (`list[FoodEntryRead]`) with server-recomputed
/// calories. Requires a bearer token (attached by the shared client).
class LogApi {
  final ApiClient client;
  const LogApi(this.client);

  Future<List<MealEntry>> logFood({
    required List<LogFoodItem> items,
    File? image,
  }) async {
    try {
      // The backend's LogFoodRequest is {"items": [{dish, grams?, bucket?}]}.
      final itemsJson = jsonEncode({
        'items': items.map((e) => e.toJson()).toList(),
      });

      final form = FormData.fromMap({
        'items': itemsJson,
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: 'meal.jpg',
          ),
      });

      final res = await client.dio.post('/log/food', data: form);
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return (res.data as List)
            .map((e) => MealEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  /// `POST /log/exercise` (api/log.py). Either pass `minutes` (backend computes
  /// kcal from METs using the user's weight) OR pass `kcal` directly. The
  /// backend requires at least one; this is validated again client-side.
  Future<ExerciseEntry> logExercise({
    required String activity,
    double? minutes,
    double? kcal,
  }) async {
    try {
      final body = {
        'activity': activity,
        if (minutes != null) 'minutes': minutes,
        if (kcal != null) 'kcal': kcal,
      };
      final res = await client.dio.post('/log/exercise', data: body);
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return ExerciseEntry.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }
}
