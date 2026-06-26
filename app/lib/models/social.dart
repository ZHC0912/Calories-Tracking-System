/// Dart mirrors of the backend social schemas (schemas/social.py).
///
/// Safety shapes honored here: a user is only ever a [PublicUser] (id + handle +
/// display name — never body stats); shares carry only boolean part-toggles
/// ([ShareParts]); reactions are limited to [allowedReactions].
library;

/// The fixed reaction set (models/social.py ALLOWED_REACTIONS). The UI offers
/// exactly these — never a free-text input.
const List<String> allowedReactions = ['👍', '💪', '🔥', '👏'];

class PublicUser {
  final int id;
  final String handle;
  final String displayName;

  const PublicUser({
    required this.id,
    required this.handle,
    required this.displayName,
  });

  factory PublicUser.fromJson(Map<String, dynamic> j) => PublicUser(
        id: j['id'] as int,
        handle: j['handle'] as String,
        displayName: (j['display_name'] as String?) ?? '',
      );
}

class CommunityRead {
  final int id;
  final String name;
  final int ownerId;
  final int memberCount;

  const CommunityRead({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberCount,
  });

  factory CommunityRead.fromJson(Map<String, dynamic> j) => CommunityRead(
        id: j['id'] as int,
        name: j['name'] as String,
        ownerId: j['owner_id'] as int,
        memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
      );
}

class CommunityMemberRead {
  final PublicUser user;
  final String role;
  final String joinedAt;

  const CommunityMemberRead({
    required this.user,
    required this.role,
    required this.joinedAt,
  });

  factory CommunityMemberRead.fromJson(Map<String, dynamic> j) =>
      CommunityMemberRead(
        user: PublicUser.fromJson(j['user'] as Map<String, dynamic>),
        role: (j['role'] as String?) ?? 'member',
        joinedAt: (j['joined_at'] as String?) ?? '',
      );
}

class InviteRead {
  final int id;
  final int communityId;
  final String communityName;
  final PublicUser inviter;
  final String status;
  final String createdAt;

  const InviteRead({
    required this.id,
    required this.communityId,
    required this.communityName,
    required this.inviter,
    required this.status,
    required this.createdAt,
  });

  factory InviteRead.fromJson(Map<String, dynamic> j) => InviteRead(
        id: j['id'] as int,
        communityId: j['community_id'] as int,
        communityName: (j['community_name'] as String?) ?? '',
        inviter: PublicUser.fromJson(j['inviter'] as Map<String, dynamic>),
        status: (j['status'] as String?) ?? 'pending',
        createdAt: (j['created_at'] as String?) ?? '',
      );
}

/// Which parts of a daily report to share. Body-derived [includeTarget] defaults
/// OFF — only sent when the user explicitly opts in.
class ShareParts {
  final bool includeNetCalories;
  final bool includeMacros;
  final bool includeFoodImages;
  final bool includeTarget;

  const ShareParts({
    this.includeNetCalories = true,
    this.includeMacros = false,
    this.includeFoodImages = false,
    this.includeTarget = false,
  });

  factory ShareParts.fromJson(Map<String, dynamic> j) => ShareParts(
        includeNetCalories: (j['include_net_calories'] as bool?) ?? true,
        includeMacros: (j['include_macros'] as bool?) ?? false,
        includeFoodImages: (j['include_food_images'] as bool?) ?? false,
        includeTarget: (j['include_target'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'include_net_calories': includeNetCalories,
        'include_macros': includeMacros,
        'include_food_images': includeFoodImages,
        'include_target': includeTarget,
      };

  ShareParts copyWith({
    bool? includeNetCalories,
    bool? includeMacros,
    bool? includeFoodImages,
    bool? includeTarget,
  }) =>
      ShareParts(
        includeNetCalories: includeNetCalories ?? this.includeNetCalories,
        includeMacros: includeMacros ?? this.includeMacros,
        includeFoodImages: includeFoodImages ?? this.includeFoodImages,
        includeTarget: includeTarget ?? this.includeTarget,
      );

  /// Element-wise OR — used to pre-tick the share sheet from friends' defaults.
  ShareParts union(ShareParts other) => ShareParts(
        includeNetCalories: includeNetCalories || other.includeNetCalories,
        includeMacros: includeMacros || other.includeMacros,
        includeFoodImages: includeFoodImages || other.includeFoodImages,
        includeTarget: includeTarget || other.includeTarget,
      );
}

class ShareDefaultRead {
  final PublicUser friend;
  final bool enabled;
  final ShareParts parts;

  const ShareDefaultRead({
    required this.friend,
    required this.enabled,
    required this.parts,
  });

  factory ShareDefaultRead.fromJson(Map<String, dynamic> j) => ShareDefaultRead(
        friend: PublicUser.fromJson(j['friend'] as Map<String, dynamic>),
        enabled: (j['enabled'] as bool?) ?? false,
        parts: ShareParts.fromJson(j),
      );
}

class PreselectedFriend {
  final PublicUser friend;
  final ShareParts parts;

  const PreselectedFriend({required this.friend, required this.parts});

  factory PreselectedFriend.fromJson(Map<String, dynamic> j) => PreselectedFriend(
        friend: PublicUser.fromJson(j['friend'] as Map<String, dynamic>),
        parts: ShareParts.fromJson(j['parts'] as Map<String, dynamic>),
      );
}

class SharePreview {
  final String date;
  final bool hasReport;
  final List<PreselectedFriend> preselectedFriends;
  final List<PublicUser> addableFriends;
  final List<CommunityRead> myCommunities;

  const SharePreview({
    required this.date,
    required this.hasReport,
    required this.preselectedFriends,
    required this.addableFriends,
    required this.myCommunities,
  });

  factory SharePreview.fromJson(Map<String, dynamic> j) => SharePreview(
        date: j['date'] as String,
        hasReport: (j['has_report'] as bool?) ?? false,
        preselectedFriends: ((j['preselected_friends'] as List?) ?? const [])
            .map((e) => PreselectedFriend.fromJson(e as Map<String, dynamic>))
            .toList(),
        addableFriends: ((j['addable_friends'] as List?) ?? const [])
            .map((e) => PublicUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        myCommunities: ((j['my_communities'] as List?) ?? const [])
            .map((e) => CommunityRead.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Suggested initial part-toggles: the OR of every pre-ticked friend's
  /// defaults, or the safe baseline (net on, everything else off) if none.
  ShareParts suggestedParts() {
    if (preselectedFriends.isEmpty) return const ShareParts();
    return preselectedFriends
        .map((p) => p.parts)
        .reduce((a, b) => a.union(b));
  }
}

class ReactionCounts {
  final Map<String, int> counts;
  final String? myReaction;

  const ReactionCounts({required this.counts, this.myReaction});

  factory ReactionCounts.fromJson(Map<String, dynamic> j) {
    final raw = (j['counts'] as Map?) ?? const {};
    return ReactionCounts(
      counts: raw.map((k, v) => MapEntry(k as String, (v as num).toInt())),
      myReaction: j['my_reaction'] as String?,
    );
  }
}

class FeedPostRead {
  final int id;
  final int communityId;
  final PublicUser author;
  final String reportDate;
  final String createdAt;
  final Map<String, dynamic> payload;
  final ReactionCounts reactions;

  const FeedPostRead({
    required this.id,
    required this.communityId,
    required this.author,
    required this.reportDate,
    required this.createdAt,
    required this.payload,
    required this.reactions,
  });

  factory FeedPostRead.fromJson(Map<String, dynamic> j) => FeedPostRead(
        id: j['id'] as int,
        communityId: j['community_id'] as int,
        author: PublicUser.fromJson(j['author'] as Map<String, dynamic>),
        reportDate: j['report_date'] as String,
        createdAt: (j['created_at'] as String?) ?? '',
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        reactions:
            ReactionCounts.fromJson(j['reactions'] as Map<String, dynamic>),
      );

  Snapshot get snapshot => Snapshot(payload);
}

/// Typed, null-safe reader over a frozen share snapshot payload. Only the parts
/// the author chose are present (see services/sharing.build_snapshot); every
/// accessor degrades gracefully when its part wasn't shared.
class Snapshot {
  final Map<String, dynamic> data;
  const Snapshot(this.data);

  bool get logged => data['logged'] == true;
  int get mealsCount => (data['meals_count'] as num?)?.toInt() ?? 0;
  int get exercisesCount => (data['exercises_count'] as num?)?.toInt() ?? 0;

  bool get hasNet => data.containsKey('net_kcal');
  double? get intake => _d(data['total_intake_kcal']);
  double? get burned => _d(data['total_burned_kcal']);
  double? get net => _d(data['net_kcal']);

  bool get hasMacros => data.containsKey('total_protein');
  double? get protein => _d(data['total_protein']);
  double? get fat => _d(data['total_fat']);
  double? get carbs => _d(data['total_carbs']);

  bool get hasFoodImages =>
      (data['food_images'] as List?)?.isNotEmpty ?? false;
  List<({String dish, String? imagePath})> get foodImages =>
      ((data['food_images'] as List?) ?? const [])
          .map((e) => (
                dish: (e['dish'] as String?) ?? '',
                imagePath: e['image_path'] as String?,
              ))
          .toList();

  bool get hasTarget => data.containsKey('target_kcal');
  double? get target => _d(data['target_kcal']);
  double? get remaining => _d(data['remaining_kcal']);

  static double? _d(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
