import 'package:flutter/material.dart';

import '../screens/notification_capture/notification_capture_screen.dart';
import '../services/notification_capture_service.dart';

/// Sino no AppBar que mostra quantas notificações de banco foram capturadas e
/// aguardam ser lançadas, e abre a tela de revisão.
///
/// Some por completo fora do Android, onde a captura não existe. O contador é
/// relido ao abrir a aba e ao voltar ao primeiro plano (a fila cresce mesmo com
/// o app fechado).
class CaptureBellButton extends StatefulWidget {
  const CaptureBellButton({super.key});

  @override
  State<CaptureBellButton> createState() => _CaptureBellButtonState();
}

class _CaptureBellButtonState extends State<CaptureBellButton>
    with WidgetsBindingObserver {
  final _service = NotificationCaptureService();
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (!_service.isSupported) return;
    final captured = await _service.peekQueue();
    if (!mounted) return;
    setState(() => _pending = captured.length);
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationCaptureScreen()),
    );
    // Ao voltar, algumas podem ter sido lançadas ou descartadas.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isSupported) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Notificações capturadas',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _pending > 0,
        label: Text('$_pending'),
        child: Icon(
          _pending > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }
}
