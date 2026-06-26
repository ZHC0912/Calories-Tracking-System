import 'food_item.dart';

/// Mirrors the backend `AnalyzeResponse` (schemas/analysis.py): the result of
/// analyzing one meal image (+ optional caption). Totals are nullable when no
/// item had nutrient data.
class AnalyzeResponse {
  final List<FoodItem> items;
  final double? totalKcal;
  final double? totalProtein;
  final double? totalFat;
  final double? totalCarbs;

  const AnalyzeResponse({
    required this.items,
    this.totalKcal,
    this.totalProtein,
    this.totalFat,
    this.totalCarbs,
  });

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return AnalyzeResponse(
      items: rawItems
          .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalKcal: _toDouble(json['total_kcal']),
      totalProtein: _toDouble(json['total_protein']),
      totalFat: _toDouble(json['total_fat']),
      totalCarbs: _toDouble(json['total_carbs']),
    );
  }
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
