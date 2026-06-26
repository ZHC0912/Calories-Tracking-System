import '../models/social.dart';
import 'api_client.dart';

/// Sharing, feed, reactions, and share defaults (api/feed.py). `POST /share` is
/// the only write path to a feed and is only ever called on an explicit tap.
class FeedApi {
  final ApiClient client;
  const FeedApi(this.client);

  Future<SharePreview> sharePreview(String? date) async {
    try {
      final res = await client.dio.get(
        '/share/preview',
        queryParameters: date == null ? null : {'date': date},
      );
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return SharePreview.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<List<FeedPostRead>> share({
    required String date,
    required ShareParts parts,
    required List<int> communityIds,
  }) async {
    try {
      final res = await client.dio.post('/share', data: {
        'date': date,
        'parts': parts.toJson(),
        'community_ids': communityIds,
      });
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return (res.data as List)
            .map((e) => FeedPostRead.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<List<FeedPostRead>> feed(int communityId) async {
    try {
      final res = await client.dio.get('/feed/$communityId');
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return (res.data as List)
            .map((e) => FeedPostRead.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<ReactionCounts> react(int postId, String emoji) =>
      _reaction('post', postId, emoji);

  Future<ReactionCounts> unreact(int postId) => _reaction('delete', postId, null);

  Future<ReactionCounts> _reaction(String verb, int postId, String? emoji) async {
    try {
      final path = '/feed/$postId/react';
      final res = verb == 'delete'
          ? await client.dio.delete(path)
          : await client.dio.post(path, data: {'emoji': emoji});
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return ReactionCounts.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<ShareDefaultRead> getShareDefault(int friendId) async {
    try {
      final res = await client.dio.get('/share/defaults/$friendId');
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return ShareDefaultRead.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  /// PUT /share/defaults/{friendId}. Send only the fields you want to change
  /// (backend uses exclude_unset).
  Future<ShareDefaultRead> setShareDefault(
    int friendId,
    Map<String, dynamic> changes,
  ) async {
    try {
      final res =
          await client.dio.put('/share/defaults/$friendId', data: changes);
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return ShareDefaultRead.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }
}
