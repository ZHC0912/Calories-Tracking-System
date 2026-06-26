/// Mirrors the backend `DailyReport` (schemas/report.py) and its nested
/// `FoodEntryRead` / `ExerciseEntryRead` (schemas/log.py).
///
/// `targetKcal` / `remainingKcal` are nullable: a freshly-registered user has
/// no profile yet, so the backend omits the target. The UI must render intake
/// and meals regardless and only show the target when present.
library;

class DailyReport {
  final String date; // ISO YYYY-MM-DD, in the user's timezone
  final String timezone;

  final double totalIntakeKcal;
  final double totalBurnedKcal;
  final double netKcal;
  final double? targetKcal; // null until the profile is complete
  final double? remainingKcal; // null if no target

  final double totalProtein;
  final double totalFat;
  final double totalCarbs;

  final List<MealEntry> meals;
  final List<ExerciseEntry> exercises;

  final String note;

  const DailyReport({
    required this.date,
    required this.timezone,
    required this.totalIntakeKcal,
    required this.totalBurnedKcal,
    required this.netKcal,
    required this.targetKcal,
    required this.remainingKcal,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    required this.meals,
    required this.exercises,
    required this.note,
  });

  bool get hasTarget => targetKcal != null;

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    return DailyReport(
      date: json['date'] as String,
      timezone: (json['timezone'] as String?) ?? 'UTC',
      totalIntakeKcal: _toDouble(json['total_intake_kcal']) ?? 0.0,
      totalBurnedKcal: _toDouble(json['total_burned_kcal']) ?? 0.0,
      netKcal: _toDouble(json['net_kcal']) ?? 0.0,
      targetKcal: _toDouble(json['target_kcal']),
      remainingKcal: _toDouble(json['remaining_kcal']),
      totalProtein: _toDouble(json['total_protein']) ?? 0.0,
      totalFat: _toDouble(json['total_fat']) ?? 0.0,
      totalCarbs: _toDouble(json['total_carbs']) ?? 0.0,
      meals: ((json['meals'] as List?) ?? const [])
          .map((e) => MealEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      exercises: ((json['exercises'] as List?) ?? const [])
          .map((e) => ExerciseEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      note: (json['note'] as String?) ?? '',
    );
  }
}

/// Mirrors `FoodEntryRead` (schemas/log.py). Returned by `POST /log/food` and
/// listed inside a `DailyReport`.
class MealEntry {
  final int id;
  final String dish;
  final double grams;
  final String gramSource;
  final double? kcal;
  final double? protein;
  final double? fat;
  final double? carbs;

  /// Server-side storage path (e.g. "meals/abc.jpg"). NOT a fetchable URL —
  /// the backend exposes no image-serving endpoint yet, so this is metadata
  /// only in App Phase 1.
  final String? imagePath;
  final String eatenAt; // ISO datetime

  const MealEntry({
    required this.id,
    required this.dish,
    required this.grams,
    required this.gramSource,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.imagePath,
    required this.eatenAt,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id: json['id'] as int,
      dish: json['dish'] as String,
      grams: _toDouble(json['grams']) ?? 0.0,
      gramSource: (json['gram_source'] as String?) ?? 'estimate',
      kcal: _toDouble(json['kcal']),
      protein: _toDouble(json['protein']),
      fat: _toDouble(json['fat']),
      carbs: _toDouble(json['carbs']),
      imagePath: json['image_path'] as String?,
      eatenAt: (json['eaten_at'] as String?) ?? '',
    );
  }
}

/// Mirrors `ExerciseEntryRead` (schemas/log.py). Read-only in App Phase 1
/// (exercise logging is a later phase) but parsed so the report renders.
class ExerciseEntry {
  final int id;
  final String activity;
  final double? minutes;
  final double kcal;
  final String source; // "computed" | "user"
  final String performedAt;

  const ExerciseEntry({
    required this.id,
    required this.activity,
    required this.minutes,
    required this.kcal,
    required this.source,
    required this.performedAt,
  });

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseEntry(
      id: json['id'] as int,
      activity: json['activity'] as String,
      minutes: _toDouble(json['minutes']),
      kcal: _toDouble(json['kcal']) ?? 0.0,
      source: (json['source'] as String?) ?? 'user',
      performedAt: (json['performed_at'] as String?) ?? '',
    );
  }
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
