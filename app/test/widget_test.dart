// Smoke tests for plugin-free pieces of App Phase 1.
//
// The full app touches platform plugins (secure storage, image_picker) and the
// network at startup, so widget-pumping the whole app isn't meaningful in a
// unit test. These cover the pure model/format/widget logic instead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calories_app/models/analyze_response.dart';
import 'package:calories_app/models/daily_report.dart';
import 'package:calories_app/models/profile.dart';
import 'package:calories_app/models/social.dart';
import 'package:calories_app/util/formatters.dart';
import 'package:calories_app/widgets/honesty_tag.dart';

void main() {
  test('AnalyzeResponse parses items and tolerates null nutrients', () {
    final res = AnalyzeResponse.fromJson({
      'items': [
        {
          'dish': 'nasi lemak',
          'grams': 250,
          'gram_source': 'user',
          'confidence': 0.9,
          'kcal': 500.0,
          'protein': null,
          'fat': null,
          'carbs': null,
        },
      ],
      'total_kcal': 500.0,
      'total_protein': null,
    });

    expect(res.items.length, 1);
    expect(res.items.first.dish, 'nasi lemak');
    expect(res.items.first.grams, 250.0);
    expect(res.items.first.protein, isNull);
    expect(res.totalKcal, 500.0);
  });

  test('DailyReport omits target when the profile is incomplete', () {
    final report = DailyReport.fromJson({
      'date': '2026-06-14',
      'timezone': 'UTC',
      'total_intake_kcal': 600.0,
      'total_burned_kcal': 0.0,
      'net_kcal': 600.0,
      'target_kcal': null,
      'remaining_kcal': null,
      'total_protein': 0.0,
      'total_fat': 0.0,
      'total_carbs': 0.0,
      'meals': [],
      'exercises': [],
      'note': 'Estimates only — not medical advice.',
    });

    expect(report.hasTarget, isFalse);
    expect(report.meals, isEmpty);
  });

  test('formatters render null nutrients as an em dash', () {
    expect(kcalText(null), '—');
    expect(kcalText(499.6), '500 kcal');
    expect(gramSourceLabel('user', 250), 'from 250 g');
    expect(gramSourceLabel('estimate', 300), 'estimated');
  });

  test('ProfileSummary.isComplete reflects required stats', () {
    final incomplete = ProfileSummary.fromJson({
      'email': 'a@b.com',
      'timezone': 'Asia/Kuala_Lumpur',
      'allow_training_use': false,
      'activity_guidance': 'g',
      'note': 'n',
    });
    expect(incomplete.isComplete, isFalse);
    expect(incomplete.hasTarget, isFalse);

    final complete = ProfileSummary.fromJson({
      'email': 'a@b.com',
      'weight_kg': 80,
      'height_cm': 180,
      'age': 30,
      'sex': 'male',
      'activity_level': 'moderate',
      'goal': 'maintain',
      'timezone': 'UTC',
      'allow_training_use': true,
      'bmi': 24.7,
      'target_kcal': 2759.0,
      'activity_guidance': 'g',
      'note': 'n',
    });
    expect(complete.isComplete, isTrue);
    expect(complete.targetKcal, 2759.0);
    expect(complete.allowTrainingUse, isTrue);
  });

  test('ProfileUpdate.toJson omits null fields and uses backend keys', () {
    final json = const ProfileUpdate(weightKg: 82, allowTrainingUse: true)
        .toJson();
    expect(json, {'weight_kg': 82.0, 'allow_training_use': true});
    expect(json.containsKey('height_cm'), isFalse);
  });

  test('ShareParts.toJson uses backend keys; target defaults off', () {
    expect(const ShareParts().toJson(), {
      'include_net_calories': true,
      'include_macros': false,
      'include_food_images': false,
      'include_target': false,
    });
    expect(const ShareParts().includeTarget, isFalse);
  });

  test('SharePreview.suggestedParts ORs friend defaults (target still off)', () {
    final preview = SharePreview.fromJson({
      'date': '2026-06-14',
      'has_report': true,
      'preselected_friends': [
        {
          'friend': {'id': 1, 'handle': 'a@b.com', 'display_name': 'a'},
          'parts': {
            'include_net_calories': true,
            'include_macros': true,
            'include_food_images': false,
            'include_target': false,
          },
        },
        {
          'friend': {'id': 2, 'handle': 'c@d.com', 'display_name': 'c'},
          'parts': {
            'include_net_calories': false,
            'include_macros': false,
            'include_food_images': true,
            'include_target': false,
          },
        },
      ],
      'addable_friends': [],
      'my_communities': [],
    });
    final parts = preview.suggestedParts();
    expect(parts.includeNetCalories, isTrue);
    expect(parts.includeMacros, isTrue);
    expect(parts.includeFoodImages, isTrue);
    expect(parts.includeTarget, isFalse); // body-derived stays off
  });

  test('Snapshot reads only the parts that were shared', () {
    // A snapshot with net but no macros/target.
    final post = FeedPostRead.fromJson({
      'id': 1,
      'community_id': 3,
      'author': {'id': 9, 'handle': 'o@e.com', 'display_name': 'o'},
      'report_date': '2026-06-14',
      'created_at': '2026-06-14T08:00:00',
      'payload': {
        'date': '2026-06-14',
        'logged': true,
        'meals_count': 2,
        'exercises_count': 0,
        'net_kcal': 460.0,
        'total_intake_kcal': 600.0,
        'total_burned_kcal': 140.0,
      },
      'reactions': {
        'counts': {'🔥': 2},
        'my_reaction': '🔥',
      },
    });
    final s = post.snapshot;
    expect(s.logged, isTrue);
    expect(s.mealsCount, 2);
    expect(s.hasNet, isTrue);
    expect(s.net, 460.0);
    expect(s.hasMacros, isFalse);
    expect(s.hasTarget, isFalse);
    expect(post.reactions.counts['🔥'], 2);
    expect(post.reactions.myReaction, '🔥');
  });

  testWidgets('HonestyTag shows its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HonestyTag(label: 'estimated')),
      ),
    );
    expect(find.text('estimated'), findsOneWidget);
  });
}
