import 'package:shared_preferences/shared_preferences.dart';

/// Preferências da importação de notificações.
///
/// Lidas e escritas apenas no foreground (Flutter), nunca no serviço nativo em
/// background — por isso o SharedPreferences padrão é seguro aqui, sem o risco
/// de cache entre isolates que afeta a fila de captura.
class CaptureSettings {
  CaptureSettings._();
  static final CaptureSettings _instance = CaptureSettings._();
  factory CaptureSettings() => _instance;

  static const _autoImportKey = 'auto_import_enabled';
  static const _defaultCategoryKey = 'auto_import_default_category';

  /// Se ligado, transações de regra confirmada viram lançamento sozinhas.
  /// Desligado por padrão: nada entra sem revisão até o usuário optar.
  Future<bool> isAutoImportEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoImportKey) ?? false;
  }

  Future<void> setAutoImportEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoImportKey, value);
  }

  /// Categoria aplicada ao que for importado automaticamente. Null = não
  /// configurada; o chamador resolve um fallback a partir das categorias.
  Future<String?> defaultCategory() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_defaultCategoryKey);
    return (value != null && value.isNotEmpty) ? value : null;
  }

  Future<void> setDefaultCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultCategoryKey, category);
  }
}
