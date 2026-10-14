import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bank_connection.dart';

/// Credenciais da Pluggy e bancos conectados, no mesmo esquema do
/// [LogoConfig]: valor salvo no app > `.env` > vazio.
///
/// O clientSecret dá acesso aos dados bancários do usuário, então fica no
/// armazenamento seguro do sistema (Keystore/Keychain/Credential Manager), não
/// no SharedPreferences. A Pluggy recomenda mantê-lo num servidor; aqui vale o
/// modelo do Meu Pluggy — credencial do próprio usuário, no aparelho dele, que
/// só enxerga as contas dele.
class PluggyConfig {
  PluggyConfig._();
  static final PluggyConfig _instance = PluggyConfig._();
  factory PluggyConfig() => _instance;

  static const _clientIdKey = 'pluggy_client_id';
  static const _clientSecretKey = 'pluggy_client_secret';
  static const _connectionsKey = 'pluggy_connections';
  static const _clientIdEnv = 'PLUGGY_CLIENT_ID';
  static const _clientSecretEnv = 'PLUGGY_CLIENT_SECRET';

  static const _secure = FlutterSecureStorage();

  String? _appClientId;
  String? _appClientSecret;
  List<BankConnection> _connections = const [];

  /// Carrega o que foi salvo no app para um cache em memória. Chamar no boot.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _appClientId = _clean(prefs.getString(_clientIdKey));
    _appClientSecret = _clean(await _readSecret());
    _connections = _decodeConnections(prefs.getString(_connectionsKey));
  }

  /// No Android, restaurar um backup do Google Drive traz o valor cifrado sem
  /// a chave que o decifra, e a leitura lança. Tratar como "não configurado"
  /// é melhor que travar o boot — basta informar o secret de novo.
  Future<String?> _readSecret() async {
    try {
      return await _secure.read(key: _clientSecretKey);
    } catch (e) {
      debugPrint('Falha ao ler o secret da Pluggy: $e');
      return null;
    }
  }

  static String? _clean(String? v) => (v != null && v.isNotEmpty) ? v : null;

  static List<BankConnection> _decodeConnections(String? raw) {
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((c) => BankConnection.fromJson(c as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Credenciais ────────────────────────────────────────
  String get clientId => _appClientId ?? dotenv.maybeGet(_clientIdEnv) ?? '';
  String get clientSecret =>
      _appClientSecret ?? dotenv.maybeGet(_clientSecretEnv) ?? '';

  bool get isClientIdFromApp => _appClientId != null;
  bool get isClientSecretFromApp => _appClientSecret != null;
  bool get hasCredentials => clientId.isNotEmpty && clientSecret.isNotEmpty;

  /// Salva as credenciais informadas. Passe apenas as que quer alterar; string
  /// vazia remove aquela (volta a valer o `.env`).
  Future<void> saveCredentials({String? clientId, String? clientSecret}) async {
    if (clientId != null) {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = clientId.trim();
      if (trimmed.isEmpty) {
        await prefs.remove(_clientIdKey);
      } else {
        await prefs.setString(_clientIdKey, trimmed);
      }
      _appClientId = _clean(trimmed);
    }
    if (clientSecret != null) {
      final trimmed = clientSecret.trim();
      if (trimmed.isEmpty) {
        await _secure.delete(key: _clientSecretKey);
      } else {
        await _secure.write(key: _clientSecretKey, value: trimmed);
      }
      _appClientSecret = _clean(trimmed);
    }
  }

  // ── Bancos conectados ──────────────────────────────────
  List<BankConnection> get connections => List.unmodifiable(_connections);
  bool get isConfigured => hasCredentials && _connections.isNotEmpty;

  Future<void> addConnection(BankConnection connection) async {
    _connections = [
      ..._connections.where((c) => c.itemId != connection.itemId),
      connection,
    ];
    await _saveConnections();
  }

  Future<void> removeConnection(String itemId) async {
    _connections = _connections.where((c) => c.itemId != itemId).toList();
    await _saveConnections();
  }

  Future<void> _saveConnections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _connectionsKey,
      jsonEncode(_connections.map((c) => c.toJson()).toList()),
    );
  }
}
