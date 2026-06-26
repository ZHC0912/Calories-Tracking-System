/// Mirrors the backend `FoodItem` (schemas/analysis.py) — one recognized food
/// from `POST /analyze` with a resolved portion and (optionally) nutrients.
///
/// Nutrient fields are nullable: the backend sends `null` (never fake zeros)
/// when USDA data is unavailable, so the UI must handle missing numbers.
class FoodItem {
  final String dish;
  final double grams;

  /// "user" | "bucket" | "estimate" — how trustworthy `grams` is, used for the
  /// honesty tag in the UI.
  final String gramSource;
  final double confidence;

  final double? kcal;
  final double? protein;
  final double? fat;
  final double? carbs;

  const FoodItem({
    required this.dish,
    required this.grams,
    required this.gramSource,
    required this.confidence,
    this.kcal,
    this.protein,
    this.fat,
    this.carbs,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      dish: json['dish'] as String,
      grams: _toDouble(json['grams']) ?? 0.0,
      gramSource: (json['gram_source'] as String?) ?? 'estimate',
      confidence: _toDouble(json['confidence']) ?? 0.0,
      kcal: _toDouble(json['kcal']),
      protein: _toDouble(json['protein']),
      fat: _toDouble(json['fat']),
      carbs: _toDouble(json['carbs']),
    );
  }
}

/// JSON numbers can arrive as int or double; normalize to double?, keeping null.
double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
