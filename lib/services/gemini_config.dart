import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chave da API do Gemini e o liga/desliga do lançamento automático, no mesmo
/// esquema da [PluggyConfig]: valor salvo no app > `.env` > vazio.
///
/// A chave fica no armazenamento seguro do sistema, como o secret da Pluggy.
class GeminiConfig {
  GeminiConfig._();
  static final GeminiConfig _instance = GeminiConfig._();
  factory GeminiConfig() => _instance;

  /// Modelo usado na classificação. Flash: rápido e com cota gratuita folgada.
  static const model = 'gemini-3.5-flash';

  static const _apiKeyKey = 'gemini_api_key';
  static const _autoLaunchKey = 'gemini_auto_launch';
  static const _apiKeyEnv = 'GEMINI_API_KEY';

  static const _secure = FlutterSecureStorage();

  String? _appApiKey;
  bool _autoLaunch = true;

  /// Carrega o que foi salvo no app para um cache em memória. Chamar no boot.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _autoLaunch = prefs.getBool(_autoLaunchKey) ?? true;
    try {
      final key = await _secure.read(key: _apiKeyKey);
      _appApiKey = (key != null && key.isNotEmpty) ? key : null;
    } catch (e) {
      debugPrint('Falha ao ler a chave do Gemini: $e');
      _appApiKey = null;
    }
  }

  String get apiKey => _appApiKey ?? dotenv.maybeGet(_apiKeyEnv) ?? '';
  bool get hasApiKey => apiKey.isNotEmpty;

  /// Lançar sozinho o que a IA classificar com confiança alta.
  bool get autoLaunch => _autoLaunch;

  bool get isEnabled => hasApiKey && _autoLaunch;

  Future<void> saveApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _secure.delete(key: _apiKeyKey);
    } else {
      await _secure.write(key: _apiKeyKey, value: trimmed);
    }
    _appApiKey = trimmed.isEmpty ? null : trimmed;
  }

  Future<void> setAutoLaunch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLaunchKey, value);
    _autoLaunch = value;
  }
}
