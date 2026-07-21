import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chaves do logo.dev, informadas pelo usuário no app e sobrepondo o `.env`,
/// no mesmo esquema do [CloudConfig] do Firebase (cada usuário traz as suas).
///
/// São DUAS chaves diferentes:
/// - [token] — publicável (`pk_`): usada em `img.logo.dev` para baixar a imagem.
/// - [secretKey] — secreta (`sk_`): usada na Brand Search API (busca por nome).
///   É "server-side" pela doc do logo.dev; aqui fica no modelo BYO — é a chave
///   do próprio usuário, na conta dele, no aparelho dele.
///
/// Precedência de cada uma: valor salvo no app > `.env` > vazio.
class LogoConfig {
  LogoConfig._();
  static final LogoConfig _instance = LogoConfig._();
  factory LogoConfig() => _instance;

  static const _tokenKey = 'logo_dev_token';
  static const _secretKey = 'logo_dev_secret';
  static const _tokenEnv = 'LOGO_DEV_TOKEN';
  static const _secretEnv = 'LOGO_DEV_SECRET';

  String? _appToken;
  String? _appSecret;
  bool _loaded = false;

  /// Carrega as chaves salvas no app para um cache em memória. Chamar no boot.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _appToken = _clean(prefs.getString(_tokenKey));
    _appSecret = _clean(prefs.getString(_secretKey));
    _loaded = true;
  }

  bool get isLoaded => _loaded;

  static String? _clean(String? v) => (v != null && v.isNotEmpty) ? v : null;

  // ── Publicável (imagens) ───────────────────────────────
  String get token {
    if (_appToken != null) return _appToken!;
    return dotenv.maybeGet(_tokenEnv) ?? '';
  }

  bool get isFromApp => _appToken != null;
  bool get hasToken => token.isNotEmpty;

  // ── Secreta (busca por nome) ───────────────────────────
  String get secretKey {
    if (_appSecret != null) return _appSecret!;
    return dotenv.maybeGet(_secretEnv) ?? '';
  }

  bool get isSecretFromApp => _appSecret != null;
  bool get hasSecret => secretKey.isNotEmpty;

  /// Salva as chaves informadas. Passe apenas as que quer alterar; string vazia
  /// remove aquela chave (volta a valer o `.env`).
  Future<void> save({String? publishable, String? secret}) async {
    final prefs = await SharedPreferences.getInstance();
    if (publishable != null) {
      _appToken = await _write(prefs, _tokenKey, publishable);
    }
    if (secret != null) {
      _appSecret = await _write(prefs, _secretKey, secret);
    }
  }

  static Future<String?> _write(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
      return null;
    }
    await prefs.setString(key, trimmed);
    return trimmed;
  }

  /// Remove as chaves salvas no app — voltam a valer as do `.env`, se houver.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_secretKey);
    _appToken = null;
    _appSecret = null;
  }
}
