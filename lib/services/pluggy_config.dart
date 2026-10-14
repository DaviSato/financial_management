import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bank_connection.dart';
import 'logo_service.dart';

/// Credenciais da Pluggy e bancos conectados, no mesmo esquema do
/// [LogoConfig]: valor salvo no app > `.env` > vazio. Os bancos somam os dois:
/// os cadastrados no app e os de `PLUGGY_ITEMS`.
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
  static const _envItemsSeenKey = 'pluggy_env_items_seen';
  static const _clientIdEnv = 'PLUGGY_CLIENT_ID';
  static const _clientSecretEnv = 'PLUGGY_CLIENT_SECRET';
  static const _itemsEnv = 'PLUGGY_ITEMS';

  static const _secure = FlutterSecureStorage();

  String? _appClientId;
  String? _appClientSecret;
  List<BankConnection> _connections = const [];
  List<BankConnection> _envConnections = const [];

  /// Carrega o que foi salvo no app para um cache em memória. Chamar no boot.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _appClientId = _clean(prefs.getString(_clientIdKey));
    _appClientSecret = _clean(await _readSecret());
    _connections = _decodeConnections(prefs.getString(_connectionsKey));
    _envConnections = await _loadEnvConnections(prefs);
  }

  /// Bancos do `.env`, no formato `PLUGGY_ITEMS=itemId:Nome:dominio,...` (nome
  /// e domínio do logo são opcionais, ex.: `abc...:Bradesco:bradesco.com.br`).
  ///
  /// Não há data de cadastro no `.env`, então vale o dia em que o app viu o
  /// item pela primeira vez — gravado para não andar a cada boot e, com isso,
  /// não puxar histórico anterior.
  Future<List<BankConnection>> _loadEnvConnections(
    SharedPreferences prefs,
  ) async {
    final raw = dotenv.maybeGet(_itemsEnv) ?? '';
    final seen = <String, String>{};
    try {
      final stored = prefs.getString(_envItemsSeenKey);
      if (stored != null) {
        seen.addAll((jsonDecode(stored) as Map).cast<String, String>());
      }
    } catch (_) {
      // Registro corrompido: os itens recomeçam a contar de hoje.
    }

    final result = <BankConnection>[];
    var changed = false;
    for (final entry in raw.split(',')) {
      final parts = entry.split(':').map((p) => p.trim()).toList();
      final itemId = parts[0];
      if (itemId.isEmpty || result.any((c) => c.itemId == itemId)) continue;
      final name = parts.length > 1 ? parts[1] : '';
      final logo = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
      // Sem tela de escolha, o logo do .env é baixado aqui (só na 1ª vez).
      if (logo != null) {
        // Sem logo em disco o card só mostra a seta; falha aqui não importa.
        unawaited(LogoService().ensureLocal(logo).catchError((_) => null));
      }
      final firstSeen = DateTime.tryParse(seen[itemId] ?? '');
      if (firstSeen == null) changed = true;
      final connectedAt = firstSeen ?? DateTime.now();
      seen[itemId] = connectedAt.toIso8601String();
      result.add(BankConnection(
        itemId: itemId,
        institution: name,
        connectedAt: connectedAt,
        logoDomain: logo,
      ));
    }
    if (changed) await prefs.setString(_envItemsSeenKey, jsonEncode(seen));
    return result;
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
  /// Os cadastrados no app mais os do `.env`. O mesmo item nos dois vale o do
  /// app, que pode ter sido renomeado.
  List<BankConnection> get connections {
    final appIds = {for (final c in _connections) c.itemId};
    return List.unmodifiable([
      ..._connections,
      ..._envConnections.where((c) => !appIds.contains(c.itemId)),
    ]);
  }

  /// Item vindo só do `.env` — não dá para remover nem renomear pelo app.
  bool isFromEnv(String itemId) =>
      !_connections.any((c) => c.itemId == itemId) &&
      _envConnections.any((c) => c.itemId == itemId);

  bool get isConfigured => hasCredentials && connections.isNotEmpty;

  Future<void> addConnection(BankConnection connection) async {
    _connections = [
      ..._connections.where((c) => c.itemId != connection.itemId),
      connection,
    ];
    await _saveConnections();
  }

  /// Troca nome e logo do banco. O conector de um item do Meu Pluggy se chama
  /// sempre "MeuPluggy", então o banco de verdade vem do usuário.
  Future<void> updateConnection(
    String itemId, {
    required String institution,
    String? logoDomain,
  }) async {
    _connections = [
      for (final c in _connections)
        c.itemId == itemId
            ? BankConnection(
                itemId: c.itemId,
                institution: institution.trim(),
                connectedAt: c.connectedAt,
                logoDomain: logoDomain,
              )
            : c,
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
