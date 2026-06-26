import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/profile_api.dart';
import '../models/profile.dart';
import 'auth_provider.dart';

final profileApiProvider = Provider<ProfileApi>(
  (ref) => ProfileApi(ref.read(apiClientProvider)),
);

/// The current user's profile + backend-computed summary. Invalidate after a
/// PUT /profile so the screens and the daily target refresh.
final profileProvider = FutureProvider.autoDispose<ProfileSummary>((ref) {
  return ref.read(profileApiProvider).get();
});
