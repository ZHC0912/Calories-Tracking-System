/// Small display helpers shared across screens. Nutrient values can be null
/// (USDA unavailable) — these render an em dash rather than crashing.
library;

String kcalText(double? kcal) {
  if (kcal == null) return '—';
  return '${kcal.round()} kcal';
}

String kcalNumber(double? kcal) {
  if (kcal == null) return '—';
  return '${kcal.round()}';
}

String gramsText(double grams) {
  // Whole grams read cleaner than "300.0 g".
  if (grams == grams.roundToDouble()) return '${grams.round()} g';
  return '${grams.toStringAsFixed(1)} g';
}

String macroText(String label, double? grams) {
  if (grams == null) return '$label —';
  return '$label ${grams.round()}g';
}

/// Human label for a gram_source, given the resolved grams. This is the
/// "honesty" string the backend's gram_source is meant to drive.
///   user     -> "from 250 g" (the user's own number)
///   bucket   -> "medium portion"-style; we only know it's a chosen bucket
///   estimate -> "estimated"
String gramSourceLabel(String gramSource, double grams) {
  switch (gramSource) {
    case 'user':
      return 'from ${gramsText(grams)}';
    case 'bucket':
      return '${gramsText(grams)} portion';
    case 'estimate':
    default:
      return 'estimated';
  }
}
