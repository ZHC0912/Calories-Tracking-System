import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/analyze_api.dart';
import '../api/log_api.dart';
import '../models/analyze_response.dart';
import 'auth_provider.dart';

final analyzeApiProvider = Provider<AnalyzeApi>(
  (ref) => AnalyzeApi(ref.read(apiClientProvider)),
);

final logApiProvider = Provider<LogApi>(
  (ref) => LogApi(ref.read(apiClientProvider)),
);

/// The meal currently being confirmed: the captured photo, the optional caption
/// the user typed, and what `/analyze` returned. The confirm screen reads this
/// and edits a local working copy before logging.
class AnalyzeDraft {
  final File image;
  final String? caption;
  final AnalyzeResponse response;

  const AnalyzeDraft({
    required this.image,
    required this.caption,
    required this.response,
  });
}

/// Holds the in-progress draft between the capture and confirm screens. Cleared
/// after a successful log (or when the user backs out).
class AnalyzeDraftController extends Notifier<AnalyzeDraft?> {
  @override
  AnalyzeDraft? build() => null;

  void set(AnalyzeDraft draft) => state = draft;
  void clear() => state = null;
}

final analyzeDraftProvider =
    NotifierProvider<AnalyzeDraftController, AnalyzeDraft?>(
  AnalyzeDraftController.new,
);
