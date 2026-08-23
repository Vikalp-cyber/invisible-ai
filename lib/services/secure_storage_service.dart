import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../features/assistant/domain/repositories/ai_provider_interface.dart';

/// ── Secure Storage Service ──────────────────────────────────────────────────
/// Manages persistence of API keys.
/// Uses shared_preferences as a fallback since flutter_secure_storage
/// requires C++ ATL components on Windows which may not be installed.
class SecureStorageService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> _ensurePrefs() async {
    if (_prefs == null) await init();
    return _prefs!;
  }

  /// Gets the storage key for a specific provider.
  String _getProviderKey(AIProviderType type) {
    return 'api_key_${type.name}';
  }

  /// Retrieves the API key for the given provider.
  Future<String?> getApiKey(AIProviderType type) async {
    final prefs = await _ensurePrefs();
    return prefs.getString(_getProviderKey(type));
  }

  /// Saves the API key for the given provider.
  Future<void> saveApiKey(AIProviderType type, String apiKey) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_getProviderKey(type), apiKey);
  }

  /// Deletes the API key for the given provider.
  Future<void> deleteApiKey(AIProviderType type) async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_getProviderKey(type));
  }

  /// Ordered Groq API key pool (first key is tried first; then fallback).
  Future<List<String>> getGroqApiKeys() async {
    final prefs = await _ensurePrefs();
    final stored = prefs.getStringList(AppConstants.keyGroqApiKeys);
    if (stored != null) {
      return _normalizeKeys(stored);
    }

    // Migrate legacy single-key storage if present.
    final legacy = prefs.getString(_getProviderKey(AIProviderType.groq))?.trim();
    if (legacy != null && legacy.isNotEmpty) {
      await prefs.setStringList(AppConstants.keyGroqApiKeys, [legacy]);
      await prefs.remove(_getProviderKey(AIProviderType.groq));
      return [legacy];
    }
    return const [];
  }

  /// Replaces the entire Groq key list (order = fallback order).
  Future<void> saveGroqApiKeys(List<String> keys) async {
    final prefs = await _ensurePrefs();
    final normalized = _normalizeKeys(keys);
    await prefs.setStringList(AppConstants.keyGroqApiKeys, normalized);
  }

  /// Appends a key if non-empty and not already present.
  Future<List<String>> addGroqApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    final current = await getGroqApiKeys();
    if (trimmed.isEmpty || current.contains(trimmed)) {
      return current;
    }
    final next = [...current, trimmed];
    await saveGroqApiKeys(next);
    return next;
  }

  /// Removes the key at [index] if in range.
  Future<List<String>> removeGroqApiKeyAt(int index) async {
    final current = await getGroqApiKeys();
    if (index < 0 || index >= current.length) {
      return current;
    }
    final next = [...current]..removeAt(index);
    await saveGroqApiKeys(next);
    return next;
  }

  /// Ordered Cursor API key pool (first key is tried first; then fallback).
  Future<List<String>> getCursorApiKeys() async {
    final prefs = await _ensurePrefs();
    final stored = prefs.getStringList(AppConstants.keyCursorApiKeys);
    if (stored != null) {
      return _normalizeKeys(stored);
    }
    return const [];
  }

  Future<void> saveCursorApiKeys(List<String> keys) async {
    final prefs = await _ensurePrefs();
    final normalized = _normalizeKeys(keys);
    await prefs.setStringList(AppConstants.keyCursorApiKeys, normalized);
  }

  Future<List<String>> addCursorApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    final current = await getCursorApiKeys();
    if (trimmed.isEmpty || current.contains(trimmed)) {
      return current;
    }
    final next = [...current, trimmed];
    await saveCursorApiKeys(next);
    return next;
  }

  Future<List<String>> removeCursorApiKeyAt(int index) async {
    final current = await getCursorApiKeys();
    if (index < 0 || index >= current.length) {
      return current;
    }
    final next = [...current]..removeAt(index);
    await saveCursorApiKeys(next);
    return next;
  }

  List<String> _normalizeKeys(List<String> keys) {
    final seen = <String>{};
    final out = <String>[];
    for (final key in keys) {
      final trimmed = key.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      out.add(trimmed);
    }
    return out;
  }
}
