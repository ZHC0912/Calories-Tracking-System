/// Fixed option sets for profile fields, mirroring the backend's Literal types
/// in schemas/user.py. Values must match the backend exactly; labels are for
/// display only.
library;

class Option {
  final String value;
  final String label;
  const Option(this.value, this.label);
}

const List<Option> sexes = [
  Option('male', 'Male'),
  Option('female', 'Female'),
];

const List<Option> activityLevels = [
  Option('sedentary', 'Sedentary — little or no exercise'),
  Option('light', 'Light — 1–3 days/week'),
  Option('moderate', 'Moderate — 3–5 days/week'),
  Option('active', 'Active — 6–7 days/week'),
  Option('very_active', 'Very active — hard training / physical job'),
];

const List<Option> goals = [
  Option('lose', 'Lose weight'),
  Option('maintain', 'Maintain weight'),
  Option('gain', 'Gain weight'),
];

/// A curated list of IANA timezones (the backend validates against the full
/// set, but a short list covers the expected users). Default is Kuala Lumpur.
const String defaultTimezone = 'Asia/Kuala_Lumpur';

const List<String> commonTimezones = [
  'Asia/Kuala_Lumpur',
  'Asia/Singapore',
  'Asia/Jakarta',
  'Asia/Bangkok',
  'Asia/Manila',
  'Asia/Hong_Kong',
  'Asia/Tokyo',
  'Asia/Kolkata',
  'Asia/Dubai',
  'Australia/Sydney',
  'Europe/London',
  'Europe/Paris',
  'America/New_York',
  'America/Los_Angeles',
  'UTC',
];

String labelFor(List<Option> options, String? value) {
  if (value == null) return '—';
  for (final o in options) {
    if (o.value == value) return o.label;
  }
  return value;
}
