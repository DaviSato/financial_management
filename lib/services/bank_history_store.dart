import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bank_history_entry.dart';
import 'auth_service.dart';
import 'firebase_config.dart';
import 'firestore_service.dart';

/// Histórico das movimentações do banco que já saíram da caixa de entrada
/// (lançadas ou descartadas), por id da transação na Pluggy.
abstract class BankHistoryStore {
  /// Tudo dentro de [BankHistoryEntry.retention]; o que expirou é apagado.
  Future<Map<String, BankHistoryEntry>> load();
  Future<void> save(Iterable<BankHistoryEntry> entries);
  Future<void> remove(Iterable<String> transactionIds);
}

/// Grava local (sempre) e no Firestore (quando conectado), para que o que foi
/// tratado num aparelho suma da caixa de entrada nos outros.
class PrefsFirestoreHistoryStore implements BankHistoryStore {
  PrefsFirestoreHistoryStore({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Mesma chave e coleção de quando só se guardava o id: os registros
  /// antigos continuam valendo (como [BankOutcome.handled]).
  static const _key = 'bank_handled';

  FirestoreService? get _cloud =>
      FirebaseConfig.initialized && AuthService().uid != null
          ? FirestoreService()
          : null;

  @override
  Future<Map<String, BankHistoryEntry>> load() async {
    final all = await _loadLocal();
    final cloud = _cloud;
    if (cloud != null) {
      try {
        final remote = await cloud.getBankHistory();
        for (final e in remote.entries) {
          final entry = BankHistoryEntry.fromJson(e.key, e.value);
          // Um registro antigo (sem retrato) não apaga o retrato que o outro
          // lado já tem.
          if (entry.transaction != null || !all.containsKey(e.key)) {
            all[e.key] = entry;
          }
        }
      } catch (e) {
        // Sem rede: o que já está local basta para não duplicar neste aparelho.
        debugPrint('Falha ao ler o histórico do banco no Firestore: $e');
      }
    }

    final now = _now();
    final expired = [
      for (final e in all.values)
        if (e.isExpired(now)) e.transactionId,
    ];
    if (expired.isNotEmpty) {
      all.removeWhere((id, _) => expired.contains(id));
      await _writeLocal(all);
      try {
        await cloud?.deleteBankHistory(expired);
      } catch (e) {
        debugPrint('Falha ao apagar histórico expirado no Firestore: $e');
      }
    }
    return all;
  }

  @override
  Future<void> save(Iterable<BankHistoryEntry> entries) async {
    final list = entries.toList();
    if (list.isEmpty) return;
    final local = await _loadLocal();
    for (final e in list) {
      local[e.transactionId] = e;
    }
    await _writeLocal(local);

    try {
      await _cloud?.saveBankHistory({
        for (final e in list) e.transactionId: e.toJson(),
      });
    } catch (e) {
      debugPrint('Falha ao gravar o histórico do banco no Firestore: $e');
    }
  }

  @override
  Future<void> remove(Iterable<String> transactionIds) async {
    final ids = transactionIds.toSet();
    if (ids.isEmpty) return;
    final local = await _loadLocal()
      ..removeWhere((id, _) => ids.contains(id));
    await _writeLocal(local);

    try {
      await _cloud?.deleteBankHistory(ids);
    } catch (e) {
      debugPrint('Falha ao apagar do histórico do banco no Firestore: $e');
    }
  }

  Future<Map<String, BankHistoryEntry>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          e.key: e.value is Map
              ? BankHistoryEntry.fromJson(
                  e.key,
                  Map<String, dynamic>.from(e.value as Map),
                )
              // Formato antigo: id → fingerprint (ou null).
              : BankHistoryEntry(
                  transactionId: e.key,
                  fingerprint: e.value as String?,
                  outcome: BankOutcome.handled,
                ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeLocal(Map<String, BankHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({for (final e in entries.values) e.transactionId: e.toJson()}),
    );
  }
}
