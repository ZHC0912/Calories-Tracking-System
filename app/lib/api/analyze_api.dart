import 'dart:io';

import 'package:dio/dio.dart';

import '../models/analyze_response.dart';
import 'api_client.dart';

/// `POST /analyze` (api/analyze.py) — multipart: `image` (file, required) plus
/// optional `caption`. This endpoint is stateless and needs no auth; we still
/// send the token harmlessly via the shared client.
class AnalyzeApi {
  final ApiClient client;
  const AnalyzeApi(this.client);

  Future<AnalyzeResponse> analyze({
    required File image,
    String? caption,
  }) async {
    try {
      final form = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          image.path,
          filename: 'meal.jpg',
        ),
        if (caption != null && caption.trim().isNotEmpty)
          'caption': caption.trim(),
      });

      final res = await client.dio.post('/analyze', data: form);
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return AnalyzeResponse.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }
}
