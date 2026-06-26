import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/community_api.dart';
import '../api/feed_api.dart';
import '../api/friends_api.dart';
import '../models/social.dart';
import 'auth_provider.dart';

// --- api providers -----------------------------------------------------------

final friendsApiProvider =
    Provider<FriendsApi>((ref) => FriendsApi(ref.read(apiClientProvider)));

final communityApiProvider =
    Provider<CommunityApi>((ref) => CommunityApi(ref.read(apiClientProvider)));

final feedApiProvider =
    Provider<FeedApi>((ref) => FeedApi(ref.read(apiClientProvider)));

// --- data providers (invalidate after the matching mutation) -----------------

final friendsProvider = FutureProvider.autoDispose<List<PublicUser>>(
  (ref) => ref.read(friendsApiProvider).list(),
);

final myCommunitiesProvider = FutureProvider.autoDispose<List<CommunityRead>>(
  (ref) => ref.read(communityApiProvider).mine(),
);

final invitesProvider = FutureProvider.autoDispose<List<InviteRead>>(
  (ref) => ref.read(communityApiProvider).invites(),
);

final communityMembersProvider =
    FutureProvider.autoDispose.family<List<CommunityMemberRead>, int>(
  (ref, communityId) =>
      ref.read(communityApiProvider).members(communityId),
);

final feedProvider =
    FutureProvider.autoDispose.family<List<FeedPostRead>, int>(
  (ref, communityId) => ref.read(feedApiProvider).feed(communityId),
);
