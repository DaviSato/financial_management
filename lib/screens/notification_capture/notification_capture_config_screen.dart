import 'package:flutter/material.dart';

import '../../services/notification_capture_service.dart';
import 'widgets/discovery_panel.dart';
import 'widgets/permission_banner.dart';

/// Configuração de quais apps têm as notificações capturadas — separada da
/// lista de capturas para manter aquela tela só com a lista.
class NotificationCaptureConfigScreen extends StatefulWidget {
  const NotificationCaptureConfigScreen({super.key});

  @override
  State<NotificationCaptureConfigScreen> createState() =>
      _NotificationCaptureConfigScreenState();
}

class _NotificationCaptureConfigScreenState
    extends State<NotificationCaptureConfigScreen> with WidgetsBindingObserver {
  final _service = NotificationCaptureService();

  bool _loading = true;
  bool _permissionGranted = false;
  CaptureConfig _config = const CaptureConfig();

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
    final granted = await _service.isPermissionGranted();
    final config = await _service.getConfig();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _config = config;
      _loading = false;
    });
  }

  Future<void> _toggleDiscovery(bool value) async {
    await _service.setConfig(discoveryMode: value);
    await _load();
  }

  Future<void> _toggleWatched(String package) async {
    final updated = [..._config.watchedPackages];
    updated.contains(package)
        ? updated.remove(package)
        : updated.add(package);
    await _service.setConfig(watchedPackages: updated);
    await _load();
  }

  Future<void> _clearSeen() async {
    await _service.clearSeenPackages();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apps monitorados')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (!_permissionGranted)
                  PermissionBanner(
                    onOpenSettings: () async {
                      await _service.openSettings();
                    },
                  ),
                DiscoveryPanel(
                  discoveryMode: _config.discoveryMode,
                  seenPackages: _config.seenPackages,
                  watchedPackages: _config.watchedPackages,
                  onToggleDiscovery: _toggleDiscovery,
                  onToggleWatched: _toggleWatched,
                  onClearSeen: _clearSeen,
                ),
              ],
            ),
    );
  }
}
