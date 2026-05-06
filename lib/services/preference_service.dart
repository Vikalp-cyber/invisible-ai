import 'package:shared_preferences/shared_preferences.dart';

/// ── Preference Service ─────────────────────────────────────────────────────
/// Thin typed wrapper over SharedPreferences for window state persistence.
/// All preference keys are defined in [AppConstants].
class PreferenceService {
  late SharedPreferences _prefs;

  /// Initialize SharedPreferences. Must be called once at app startup.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  /// Reads a double value, returning [defaultValue] if not set.
  double getDouble(String key, {double defaultValue = 0.0}) {
    return _prefs.getDouble(key) ?? defaultValue;
  }

  /// Reads a bool value, returning [defaultValue] if not set.
  bool getBool(String key, {bool defaultValue = false}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  /// Reads a string value, returning [defaultValue] if not set.
  String getString(String key, {String defaultValue = ''}) {
    return _prefs.getString(key) ?? defaultValue;
  }

  // ── Setters ──────────────────────────────────────────────────────────────

  /// Persists a double value.
  Future<bool> setDouble(String key, double value) {
    return _prefs.setDouble(key, value);
  }

  /// Persists a bool value.
  Future<bool> setBool(String key, bool value) {
    return _prefs.setBool(key, value);
  }

  /// Persists a string value.
  Future<bool> setString(String key, String value) {
    return _prefs.setString(key, value);
  }

  Future<bool> remove(String key) {
    return _prefs.remove(key);
  }

  /// Checks if a key exists in preferences.
  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
}
