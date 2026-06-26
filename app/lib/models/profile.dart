/// Mirrors the backend `ProfileSummary` and `ProfileUpdate` (schemas/user.py).
///
/// All health numbers (bmi, bmr, tdee, target) are COMPUTED BY THE BACKEND and
/// nullable until the profile has the stats they need. The app only displays
/// them — it never recomputes BMI or targets.
library;

class ProfileSummary {
  final String email;
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final String? sex;
  final String? activityLevel;
  final String? goal;
  final String timezone;
  final bool allowTrainingUse;

  // Computed by services/target.py — estimates, not medical advice.
  final double? bmi;
  final String? bmiNote;
  final double? bmrKcal;
  final double? tdeeKcal;
  final double? targetKcal;
  final String activityGuidance;
  final String note;

  const ProfileSummary({
    required this.email,
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.sex,
    required this.activityLevel,
    required this.goal,
    required this.timezone,
    required this.allowTrainingUse,
    required this.bmi,
    required this.bmiNote,
    required this.bmrKcal,
    required this.tdeeKcal,
    required this.targetKcal,
    required this.activityGuidance,
    required this.note,
  });

  /// The backend computes a target once weight/height/age/sex are all present.
  bool get isComplete =>
      weightKg != null && heightCm != null && age != null && sex != null;

  bool get hasTarget => targetKcal != null;

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    return ProfileSummary(
      email: json['email'] as String,
      weightKg: _toDouble(json['weight_kg']),
      heightCm: _toDouble(json['height_cm']),
      age: (json['age'] as num?)?.toInt(),
      sex: json['sex'] as String?,
      activityLevel: json['activity_level'] as String?,
      goal: json['goal'] as String?,
      timezone: (json['timezone'] as String?) ?? 'UTC',
      allowTrainingUse: (json['allow_training_use'] as bool?) ?? false,
      bmi: _toDouble(json['bmi']),
      bmiNote: json['bmi_note'] as String?,
      bmrKcal: _toDouble(json['bmr_kcal']),
      tdeeKcal: _toDouble(json['tdee_kcal']),
      targetKcal: _toDouble(json['target_kcal']),
      activityGuidance: (json['activity_guidance'] as String?) ?? '',
      note: (json['note'] as String?) ?? '',
    );
  }
}

/// Partial update for `PUT /profile` — only non-null fields are sent, matching
/// the backend's `exclude_unset` behavior.
class ProfileUpdate {
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final String? sex;
  final String? activityLevel;
  final String? goal;
  final String? timezone;
  final bool? allowTrainingUse;

  const ProfileUpdate({
    this.weightKg,
    this.heightCm,
    this.age,
    this.sex,
    this.activityLevel,
    this.goal,
    this.timezone,
    this.allowTrainingUse,
  });

  Map<String, dynamic> toJson() => {
        if (weightKg != null) 'weight_kg': weightKg,
        if (heightCm != null) 'height_cm': heightCm,
        if (age != null) 'age': age,
        if (sex != null) 'sex': sex,
        if (activityLevel != null) 'activity_level': activityLevel,
        if (goal != null) 'goal': goal,
        if (timezone != null) 'timezone': timezone,
        if (allowTrainingUse != null) 'allow_training_use': allowTrainingUse,
      };
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
