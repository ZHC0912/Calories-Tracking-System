import '../models/social.dart';
import 'api_client.dart';

/// Friends endpoints (api/friends.py). Search/list expose only [PublicUser]
/// (safe fields). There is no "list incoming requests" endpoint — but sending a
/// request to someone who already requested you auto-accepts it server-side, so
/// `sendRequest` returns the resulting status ("pending" or "accepted").
class FriendsApi {
  final ApiClient client;
  const FriendsApi(this.client);

  Future<List<PublicUser>> search(String handle) async {
    return _list('/friends/search', query: {'handle': handle});
  }

  Future<List<PublicUser>> list() => _list('/friends');

  /// Returns the resulting status: 'pending' or 'accepted' (auto-accept).
  Future<String> sendRequest(int addresseeId) async {
    try {
      final res = await client.dio
          .post('/friends/request', data: {'addressee_id': addresseeId});
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return (res.data as Map<String, dynamic>)['status'] as String? ??
            'pending';
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<void> accept(int requesterId) async {
    try {
      final res = await client.dio
          .post('/friends/accept', data: {'requester_id': requesterId});
      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw ApiClient.fromStatus(status, res.data);
      }
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<List<PublicUser>> _list(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await client.dio.get(path, queryParameters: query);
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return (res.data as List)
            .map((e) => PublicUser.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }
}
