import '../models/profile.dart';
import 'api_client.dart';

/// `GET /profile` and `PUT /profile` (api/profile.py). Both return the full
/// `ProfileSummary` (stored stats + backend-computed BMI/target/disclaimers).
class ProfileApi {
  final ApiClient client;
  const ProfileApi(this.client);

  Future<ProfileSummary> get() async {
    try {
      final res = await client.dio.get('/profile');
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return ProfileSummary.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<ProfileSummary> update(ProfileUpdate update) async {
    try {
      final res = await client.dio.put('/profile', data: update.toJson());
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return ProfileSummary.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }
}
