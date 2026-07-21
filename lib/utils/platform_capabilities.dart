import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Capacidades que variam por plataforma, reunidas num só lugar para não
/// espalhar checagens de `Platform.isX` pela árvore de widgets.
///
/// Firebase/Firestore não aparece aqui de propósito: `cloud_firestore` e
/// `firebase_auth` suportam Android, iOS e Windows, então a nuvem segue o
/// caminho normal em todas as plataformas que este app compila.
class PlatformCapabilities {
  PlatformCapabilities._();

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Notificações locais agendadas (avisos de vencimento). Mobile e Windows —
  /// no Windows o `flutter_local_notifications` precisa de `appName`/AUMID/GUID
  /// no init (ver [NotificationService.init]), já configurados.
  static bool get supportsScheduledNotifications =>
      _isMobile || (!kIsWeb && Platform.isWindows);

  /// Captura de notificações de outros apps: só o Android expõe API para isso.
  /// Espelha [NotificationCaptureService.isSupported].
  static bool get supportsNotificationCapture =>
      !kIsWeb && Platform.isAndroid;
}
