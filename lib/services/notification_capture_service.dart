import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/captured_notification.dart';

/// Configuração da captura, espelhada do lado nativo.
class CaptureConfig {
  final bool discoveryMode;
  final List<String> watchedPackages;

  /// Packages que notificaram enquanto o modo descoberta esteve ligado.
  /// Contém apenas nomes de apps — nunca conteúdo de notificação.
  final List<String> seenPackages;

  const CaptureConfig({
    this.discoveryMode = false,
    this.watchedPackages = const [],
    this.seenPackages = const [],
  });
}

/// Ponte para o NotificationCaptureService nativo (Android).
///
/// Não confundir com [NotificationService], que agenda os avisos de vencimento
/// deste app. Aqui é o contrário: lê notificações de outros apps.
///
/// Todo o parsing fica em Dart, de propósito — o nativo só captura texto cru.
/// Assim as regras de cada banco mudam sem recompilar Kotlin.
class NotificationCaptureService {
  NotificationCaptureService._();
  static final NotificationCaptureService _instance =
      NotificationCaptureService._();
  factory NotificationCaptureService() => _instance;

  static const _channel = MethodChannel(
    'financial_management/notification_capture',
  );

  /// Só existe no Android: o iOS não tem API para ler notificações de
  /// outros apps — não é permissão difícil, é ausência de API.
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> isPermissionGranted() async {
    if (!isSupported) return false;
    final granted = await _channel.invokeMethod<bool>('isPermissionGranted');
    return granted ?? false;
  }

  /// Abre Ajustes > Acesso a notificações. Não há como conceder por código.
  Future<void> openSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openSettings');
  }

  Future<CaptureConfig> getConfig() async {
    if (!isSupported) return const CaptureConfig();
    final raw = await _channel.invokeMapMethod<String, dynamic>('getConfig');
    if (raw == null) return const CaptureConfig();
    return CaptureConfig(
      discoveryMode: raw['discoveryMode'] as bool? ?? false,
      watchedPackages: (raw['watchedPackages'] as List?)?.cast<String>() ?? [],
      seenPackages: (raw['seenPackages'] as List?)?.cast<String>() ?? [],
    );
  }

  Future<void> setConfig({
    bool? discoveryMode,
    List<String>? watchedPackages,
  }) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('setConfig', {
      'discoveryMode': ?discoveryMode,
      'watchedPackages': ?watchedPackages,
    });
  }

  Future<void> clearSeenPackages() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('clearSeenPackages');
  }

  /// Caminho da fila segundo o próprio nativo — não derivado do path_provider,
  /// para não depender de um mapeamento de diretório que pode divergir.
  Future<Directory?> _queueDir() async {
    final path = await _channel.invokeMethod<String>('getQueueDir');
    if (path == null) return null;
    final dir = Directory(path);
    return dir.existsSync() ? dir : null;
  }

  /// Lê a fila sem consumir. Usado pela tela de captura, onde o objetivo é
  /// inspecionar os formatos reais antes de escrever qualquer parser.
  Future<List<CapturedNotification>> peekQueue() async {
    if (!isSupported) return [];

    final dir = await _queueDir();
    if (dir == null) return [];

    final captured = <CapturedNotification>[];
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(await entity.readAsString());
        captured.add(
          CapturedNotification.fromJson(
            json as Map<String, dynamic>,
            filePath: entity.path,
          ),
        );
      } catch (_) {
        // Arquivo corrompido ou escrito pela metade: descarta em vez de
        // derrubar a leitura inteira da fila.
        await _deleteQuietly(entity);
      }
    }

    captured.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return captured;
  }

  /// Remove da fila os itens já processados.
  Future<void> consume(Iterable<CapturedNotification> notifications) async {
    for (final notification in notifications) {
      await _deleteQuietly(File(notification.filePath));
    }
  }

  Future<void> clearQueue() async {
    final dir = await _queueDir();
    if (dir == null) return;
    for (final entity in dir.listSync()) {
      if (entity is File) await _deleteQuietly(entity);
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Some na próxima drenagem; não vale interromper o fluxo por isso.
    }
  }
}
