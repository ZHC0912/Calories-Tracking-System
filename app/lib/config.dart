/// App-wide configuration. Keep all environment knobs here so there is a single
/// place to change the backend URL per device.
class AppConfig {
  /// Backend base URL.
  ///
  /// Pick the one that matches where you run the app:
  ///   - Android emulator : http://10.0.2.2:8000   (10.0.2.2 = the host machine)
  ///   - iOS simulator    : http://localhost:8000
  ///   - Physical device  : `http://<your-dev-machine-LAN-IP>:8000`
  ///     (e.g. http://192.168.1.42:8000 — phone and computer on the same Wi-Fi)
  ///
  /// Defaults to the Android-emulator URL.
  static const String baseUrl = 'http://10.0.2.2:8000';
  // static const String baseUrl = 'http://localhost:8000';      // iOS simulator
  // static const String baseUrl = 'http://192.168.1.42:8000';   // physical device

  /// Below this `/analyze` confidence, the confirm screen leads with a
  /// "Is this `<dish>`?" prompt before anything else.
  static const double lowConfidenceThreshold = 0.6;

  /// Shown wherever calorie numbers appear — mirrors the backend's own note.
  static const String notMedicalAdvice = 'Estimates only — not medical advice.';

  /// Minimum password length the backend accepts (RegisterRequest).
  static const int minPasswordLength = 8;
}
