import '../models/social.dart';
import 'api_client.dart';

/// Community endpoints (api/community.py): create, list mine, list invites,
/// list members (members-only), invite a friend, accept an invite.
class CommunityApi {
  final ApiClient client;
  const CommunityApi(this.client);

  Future<CommunityRead> create(String name) async {
    try {
      final res = await client.dio.post('/community', data: {'name': name});
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return CommunityRead.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<List<CommunityRead>> mine() async {
    try {
      final res = await client.dio.get('/community');
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return (res.data as List)
            .map((e) => CommunityRead.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<List<InviteRead>> invites() async {
    try {
      final res = await client.dio.get('/community/invites');
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return (res.data as List)
            .map((e) => InviteRead.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<List<CommunityMemberRead>> members(int communityId) async {
    try {
      final res = await client.dio.get('/community/$communityId');
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return (res.data as List)
            .map((e) => CommunityMemberRead.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<void> invite(int communityId, int inviteeId) async {
    try {
      final res = await client.dio.post(
        '/community/$communityId/invite',
        data: {'invitee_id': inviteeId},
      );
      final status = res.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw ApiClient.fromStatus(status, res.data);
      }
    } catch (e) {
      throw client.toApiException(e);
    }
  }

  Future<CommunityRead> acceptInvite(int inviteId) async {
    try {
      final res =
          await client.dio.post('/community/invite/$inviteId/accept');
      final status = res.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return CommunityRead.fromJson(res.data as Map<String, dynamic>);
      }
      throw ApiClient.fromStatus(status, res.data);
    } catch (e) {
      throw client.toApiException(e);
    }
  }
}
