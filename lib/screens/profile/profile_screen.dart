import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_state.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_config.dart';
import '../../services/data_import_service.dart';
import '../../services/firebase_config.dart';
import '../../services/notification_capture_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_capabilities.dart';
import '../../widgets/responsive_body.dart';
import '../notification_capture/notification_capture_screen.dart';
import 'cloud_config_screen.dart';
import 'import_review_screen.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_tile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  TimeOfDay? _notificationTime;

  @override
  void initState() {
    super.initState();
    _loadNotificationTime();
  }

  Future<void> _loadNotificationTime() async {
    final time = await NotificationService().getNotificationTime();
    if (!mounted) return;
    setState(() => _notificationTime = time);
  }

  Future<void> _pickNotificationTime() async {
    final current = _notificationTime ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Horário do aviso diário de vencimentos',
    );
    if (picked == null) return;

    await NotificationService().setNotificationTime(picked);
    if (!mounted) return;
    setState(() => _notificationTime = picked);

    // Reagenda com o novo horário a partir dos gastos atuais.
    await NotificationService()
        .reschedule(context.read<ExpenseState>().expenses)
        .catchError((_) {});
  }

  Future<void> _confirmLogout() async {
    final email = AuthService().currentUser?.email ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.expenseColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: AppTheme.expenseColor,
            size: 24,
          ),
        ),
        title: const Text('Encerrar sessão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Seus dados locais serão limpos e recarregados da nuvem no '
              'próximo login.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              email,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.expenseColor,
                    minimumSize: const Size(0, 42),
                  ),
                  child: const Text('Sair'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService().clearAll();
      await AuthService().signOut();
      // O StreamBuilder de autenticação em main.dart leva de volta ao login.
    }
  }

  /// Avisa antes de abrir o formulário: trocar a conexão troca o projeto na
  /// nuvem e só vale após reiniciar. Depois abre o formulário.
  Future<void> _openCloudConfig() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cloud_sync_outlined, size: 28),
        title: const Text('Conexão com a nuvem'),
        content: const Text(
          'Você vai informar o projeto Firebase que guarda seus dados. Trocar '
          'esses dados troca a conta na nuvem e só passa a valer depois de '
          'reiniciar o app.',
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CloudConfigScreen()),
    );
    if (mounted) setState(() {}); // reflete "pendente de reinício" ao voltar
  }

  Future<void> _restoreDefault() async {
    await CloudConfig().clear();
    if (!mounted) return;
    setState(() {});
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded, size: 28),
        title: const Text('Reinicie o app'),
        content: const Text(
          'A conexão configurada no app foi removida. Reinicie para voltar ao '
          'padrão do build.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  /// Abre o seletor de arquivos, lê a planilha escolhida e leva o que foi
  /// extraído para a tela de revisão, onde o usuário confirma a importação.
  Future<void> _importData() async {
    final FilePickerResult? picked;
    try {
      // FileType.any (não custom): no Android o filtro por extensão vira MIME
      // type e o seletor acinzenta arquivos .xlsx/.xls cujo MIME não bate
      // (comum em downloads). Filtramos a extensão nós mesmos, depois.
      picked = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      if (mounted) _snack('Não foi possível abrir o seletor de arquivos.');
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final ext = (file.extension ?? '').toLowerCase();
    if (ext != 'xlsx' && ext != 'xls') {
      if (mounted) _snack('Escolha uma planilha .xlsx ou .xls.');
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) _snack('Não consegui ler o arquivo.');
      return;
    }

    final ImportPayload payload;
    try {
      payload = DataImportService().parse(bytes);
    } catch (e) {
      if (mounted) _snack('Arquivo inválido ou fora do formato esperado.');
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ImportReviewScreen(payload: payload)),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Firebase ativo NESTA sessão — não apenas "há config salva". Só aqui é
    // seguro tocar no AuthService.
    final cloudLive = FirebaseConfig.initialized;
    // Config salva porém ainda não aplicada (mudou desde o último boot).
    final pendingRestart = !cloudLive && FirebaseConfig.isConfigured;
    final email = cloudLive ? AuthService().currentUser?.email : null;
    final captureSupported = NotificationCaptureService().isSupported;
    final notificationsSupported =
        PlatformCapabilities.supportsScheduledNotifications;

    final timeLabel = _notificationTime == null
        ? '—'
        : _notificationTime!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ResponsiveBody(
        child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Conta / Nuvem ────────────────────────────────
          const SettingsSection(title: 'Conta'),
          if (cloudLive) ...[
            SettingsTile(
              icon: Icons.cloud_done_outlined,
              iconColor: AppTheme.incomColor,
              title: 'Sincronização na nuvem',
              subtitle: email ?? 'Conectado · toque para editar a conexão',
              onTap: _openCloudConfig,
            ),
            if (FirebaseConfig.isFromApp)
              SettingsTile(
                icon: Icons.settings_backup_restore_rounded,
                title: 'Restaurar padrão',
                subtitle: 'Volta à conexão embutida no build',
                onTap: _restoreDefault,
              ),
            SettingsTile(
              icon: Icons.logout_rounded,
              iconColor: AppTheme.expenseColor,
              title: 'Sair',
              subtitle: 'Encerra a sessão neste aparelho',
              onTap: _confirmLogout,
            ),
          ] else if (pendingRestart)
            SettingsTile(
              icon: Icons.restart_alt_rounded,
              iconColor: AppTheme.primaryColor,
              title: 'Conexão configurada',
              subtitle: 'Reinicie o app para conectar à nuvem',
              onTap: _openCloudConfig,
            )
          else ...[
            const SettingsTile(
              icon: Icons.cloud_off_outlined,
              title: 'Modo local',
              subtitle: 'Dados salvos apenas neste aparelho, sem sincronização',
            ),
            SettingsTile(
              icon: Icons.cloud_sync_outlined,
              title: 'Conectar à nuvem',
              subtitle: 'Sincronizar com seu projeto Firebase',
              onTap: _openCloudConfig,
            ),
          ],

          // ── Notificações ─────────────────────────────────
          // Só onde o agendamento local roda (mobile). No desktop a seção some.
          if (notificationsSupported) ...[
            const SettingsSection(title: 'Notificações'),
            SettingsTile(
              icon: Icons.schedule_outlined,
              title: 'Horário do aviso de vencimentos',
              subtitle: 'Um aviso por dia, às $timeLabel',
              trailing: Text(
                timeLabel,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _pickNotificationTime,
            ),
          ],

          // ── Importação ───────────────────────────────────
          const SettingsSection(title: 'Importação'),
          if (captureSupported)
            SettingsTile(
              icon: Icons.notifications_paused_outlined,
              title: 'Captura de notificações',
              subtitle: 'Importar gastos e rendimentos das notificações do banco',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationCaptureScreen(),
                ),
              ),
            ),
          SettingsTile(
            icon: Icons.file_download_outlined,
            title: 'Importação de dados .csx lixo',
            subtitle: 'Traz a estrutura da planilha para o app',
            onTap: _importData,
          ),
        ],
        ),
      ),
    );
  }
}
