import 'package:shared_preferences/shared_preferences.dart';
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

  /// Gets the storage key for a specific provider.
  String _getProviderKey(AIProviderType type) {
    return 'api_key_${type.name}';
  }

  /// Retrieves the API key for the given provider.
  Future<String?> getApiKey(AIProviderType type) async {
    if (_prefs == null) await init();
    return _prefs!.getString(_getProviderKey(type));
  }

  /// Saves the API key for the given provider.
  Future<void> saveApiKey(AIProviderType type, String apiKey) async {
    if (_prefs == null) await init();
    await _prefs!.setString(_getProviderKey(type), apiKey);
  }

  /// Deletes the API key for the given provider.
  Future<void> deleteApiKey(AIProviderType type) async {
    if (_prefs == null) await init();
    await _prefs!.remove(_getProviderKey(type));
  }
}
