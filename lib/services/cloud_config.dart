import 'package:shared_preferences/shared_preferences.dart';

/// Config do Firebase informada pelo usuário no app, sobrepondo o `.env`.
///
/// As chaves do Firebase (apiKey, appId…) são identificadores, não segredos —
/// a segurança vem das regras do Firestore/Storage e do Auth. Por isso ficam em
/// SharedPreferences em texto puro, sem criptografia.
///
/// Carregada uma vez no boot (`load`) para um cache em memória, de modo que
/// [FirebaseConfig] possa lê-la de forma síncrona antes do `runApp`.
class CloudConfig {
  CloudConfig._();
  static final CloudConfig _instance = CloudConfig._();
  factory CloudConfig() => _instance;

  static const _prefix = 'cloud_config_';

  /// Campos, na ordem em que aparecem no formulário.
  static const fields = [
    'apiKey',
    'appId',
    'messagingSenderId',
    'projectId',
    'storageBucket',
  ];

  final Map<String, String> _cache = {};
  bool _loaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cache.clear();
    for (final field in fields) {
      final value = prefs.getString('$_prefix$field');
      if (value != null && value.isNotEmpty) _cache[field] = value;
    }
    _loaded = true;
  }

  /// Valor de um campo, ou null se não definido no app. Requer [load] antes.
  String? get(String field) => _cache[field];

  /// Há uma config utilizável definida no app (apiKey é o mínimo).
  bool get hasConfig => (_cache['apiKey'] ?? '').isNotEmpty;

  bool get isLoaded => _loaded;

  Future<void> save(Map<String, String> values) async {
    final prefs = await SharedPreferences.getInstance();
    for (final field in fields) {
      final value = values[field]?.trim() ?? '';
      if (value.isEmpty) {
        await prefs.remove('$_prefix$field');
        _cache.remove(field);
      } else {
        await prefs.setString('$_prefix$field', value);
        _cache[field] = value;
      }
    }
  }

  /// Remove a config do app — o boot volta a usar o `.env` (padrão embutido).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final field in fields) {
      await prefs.remove('$_prefix$field');
    }
    _cache.clear();
  }
}
