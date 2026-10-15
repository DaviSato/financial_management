import 'package:flutter/material.dart';

import '../../models/bank_connection.dart';
import '../../services/bank_sync_service.dart';
import '../../services/gemini_config.dart';
import '../../services/pluggy_client.dart';
import '../../services/pluggy_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_avatar.dart';
import '../../widgets/logo_picker_field.dart';

typedef _BankInput = ({String itemId, String name, String? logoDomain});

/// Credenciais da Pluggy e bancos conectados (items do Meu Pluggy).
///
/// Os bancos são conectados em meu.pluggy.ai; aqui o usuário só informa as
/// credenciais da aplicação e cola o id de cada item, que é validado na hora.
class PluggyConfigScreen extends StatefulWidget {
  const PluggyConfigScreen({super.key});

  @override
  State<PluggyConfigScreen> createState() => _PluggyConfigScreenState();
}

class _PluggyConfigScreenState extends State<PluggyConfigScreen> {
  late final TextEditingController _idController;
  late final TextEditingController _secretController;
  late final TextEditingController _geminiController;
  bool _obscureSecret = true;
  bool _obscureGemini = true;
  late bool _autoLaunch;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    final cfg = PluggyConfig();
    // Pré-preenche com o valor ativo (app ou .env), para ver e ajustar.
    _idController = TextEditingController(text: cfg.clientId);
    _secretController = TextEditingController(text: cfg.clientSecret);
    _geminiController = TextEditingController(text: GeminiConfig().apiKey);
    _autoLaunch = GeminiConfig().autoLaunch;
  }

  @override
  void dispose() {
    _idController.dispose();
    _secretController.dispose();
    _geminiController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _saveCredentials() async {
    final cfg = PluggyConfig();
    final changed = _idController.text.trim() != cfg.clientId ||
        _secretController.text.trim() != cfg.clientSecret;
    if (!changed) return;
    await cfg.saveCredentials(
      clientId: _idController.text,
      clientSecret: _secretController.text,
    );
    BankSyncService().reset();
  }

  Future<void> _saveGemini() async {
    final cfg = GeminiConfig();
    if (_geminiController.text.trim() != cfg.apiKey) {
      await cfg.saveApiKey(_geminiController.text);
    }
    if (_autoLaunch != cfg.autoLaunch) await cfg.setAutoLaunch(_autoLaunch);
  }

  Future<void> _save() async {
    await _saveCredentials();
    await _saveGemini();
    if (!mounted) return;
    _snack('Credenciais salvas.');
    Navigator.of(context).pop();
  }

  Future<void> _addConnection() async {
    final input = await showDialog<_BankInput>(
      context: context,
      builder: (_) => const _BankDialog(),
    );
    if (input == null || input.itemId.isEmpty) return;
    final itemId = input.itemId;

    // O item é validado com as credenciais da tela, mesmo que ainda não
    // tenham sido salvas — senão o erro apontaria para o lugar errado.
    await _saveCredentials();
    final cfg = PluggyConfig();
    if (!cfg.hasCredentials) {
      if (mounted) _snack('Informe o Client ID e o Client Secret primeiro.');
      return;
    }

    setState(() => _adding = true);
    final client = PluggyClient(
      clientId: cfg.clientId,
      clientSecret: cfg.clientSecret,
    );
    try {
      final item = await client.getItem(itemId);
      // O conector de um item do Meu Pluggy é sempre "MeuPluggy"; o nome
      // informado pelo usuário é o que diz de qual banco é.
      final name = input.name.isNotEmpty ? input.name : item.institution;
      await cfg.addConnection(
        BankConnection(
          itemId: item.id,
          institution: name,
          connectedAt: DateTime.now(),
          logoDomain: input.logoDomain,
        ),
      );
      BankSyncService().reset();
      if (mounted) _snack('$name conectado.');
    } on PluggyException catch (e) {
      if (!mounted) return;
      _snack(switch (e.statusCode) {
        401 || 403 => 'Credenciais recusadas pela Pluggy.',
        404 || 400 => 'Item não encontrado. Confira o id.',
        null => 'Sem conexão com a Pluggy.',
        _ => 'Erro da Pluggy: ${e.message}',
      });
    } finally {
      client.close();
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _editConnection(BankConnection connection) async {
    final input = await showDialog<_BankInput>(
      context: context,
      builder: (_) => _BankDialog(initial: connection),
    );
    if (input == null) return;
    await PluggyConfig().updateConnection(
      connection.itemId,
      institution: input.name,
      logoDomain: input.logoDomain,
    );
    // A caixa de entrada guarda o nome antigo nas movimentações já lidas.
    BankSyncService().reset();
    if (mounted) setState(() {});
  }

  Future<void> _removeConnection(BankConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover banco?'),
        content: Text(
          '${connection.institution} deixa de ser sincronizado. A conexão no '
          'Meu Pluggy continua — remova lá se quiser revogar o acesso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await PluggyConfig().removeConnection(connection.itemId);
    BankSyncService().reset();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final connections = PluggyConfig().connections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bancos conectados'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Conecte seus bancos em meu.pluggy.ai e vincule-os à aplicação '
                'no Dashboard da Pluggy. Depois cole aqui as credenciais da '
                'aplicação e o id de cada item.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _idController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _secretController,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: _obscureSecret,
                decoration: InputDecoration(
                  labelText: 'Client Secret',
                  prefixIcon: const Icon(Icons.key_outlined),
                  helperText: 'Guardado no armazenamento seguro do aparelho',
                  suffixIcon: IconButton(
                    tooltip: _obscureSecret ? 'Mostrar' : 'Ocultar',
                    icon: Icon(
                      _obscureSecret
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureSecret = !_obscureSecret),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Lançamento automático',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cada movimentação nova vai para o Gemini, que lança o gasto ou '
                'rendimento, marca como pago o recorrente que ela está pagando '
                'ou descarta transferências entre suas contas. O que ele não '
                'tiver certeza fica para você, com a sugestão. Tudo pode ser '
                'desfeito pelo histórico.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _geminiController,
                autocorrect: false,
                enableSuggestions: false,
                obscureText: _obscureGemini,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Chave da API do Gemini',
                  prefixIcon: const Icon(Icons.auto_awesome_outlined),
                  helperText: 'aistudio.google.com · gratuita',
                  suffixIcon: IconButton(
                    tooltip: _obscureGemini ? 'Mostrar' : 'Ocultar',
                    icon: Icon(
                      _obscureGemini
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureGemini = !_obscureGemini),
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lançar automaticamente'),
                subtitle: const Text(
                  'Desligado, nada vai para a IA',
                  style: TextStyle(fontSize: 12),
                ),
                value: _autoLaunch && _geminiController.text.trim().isNotEmpty,
                onChanged: _geminiController.text.trim().isEmpty
                    ? null
                    : (v) => setState(() => _autoLaunch = v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bancos',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _adding ? null : _addConnection,
                    icon: _adding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              if (connections.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Nenhum banco conectado.',
                    style: TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                ),
              for (final c in connections)
                if (PluggyConfig().isFromEnv(c.itemId))
                  // Vem do PLUGGY_ITEMS: muda-se no .env, não aqui.
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _bankAvatar(c),
                    title: Text(
                      c.institution.isEmpty ? c.itemId : c.institution,
                    ),
                    subtitle: Text(
                      'Desde ${_formatDate(c.connectedAt)} · definido no .env',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Tooltip(
                      message: 'Altere em PLUGGY_ITEMS no .env',
                      child: Icon(Icons.lock_outline_rounded, size: 20),
                    ),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _bankAvatar(c),
                    title: Text(
                      c.institution.isEmpty ? c.itemId : c.institution,
                    ),
                    subtitle: Text(
                      'Desde ${_formatDate(c.connectedAt)} · toque para editar',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => _editConnection(c),
                    trailing: IconButton(
                      tooltip: 'Remover',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _removeConnection(c),
                    ),
                  ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _bankAvatar(BankConnection c) => (c.logoDomain ?? '').isEmpty
      ? const Icon(Icons.account_balance_outlined)
      : BrandAvatar(
          logoDomain: c.logoDomain,
          color: AppTheme.primaryColor,
          size: 36,
        );

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Dados do banco: Item ID (só ao adicionar), nome e logo (bandeira).
class _BankDialog extends StatefulWidget {
  const _BankDialog({this.initial});

  /// null = adicionar (pede o Item ID); preenchido = editar.
  final BankConnection? initial;

  @override
  State<_BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<_BankDialog> {
  final _idController = TextEditingController();
  late final _nameController =
      TextEditingController(text: widget.initial?.institution ?? '');
  late String? _logoDomain = widget.initial?.logoDomain;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, (
        itemId: _isEditing ? widget.initial!.itemId : _idController.text.trim(),
        name: _nameController.text.trim(),
        logoDomain: _logoDomain,
      ));

  @override
  Widget build(BuildContext context) {
    // Tela cheia: a busca de logo abre uma lista de resultados que não cabe
    // num AlertDialog.
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar banco' : 'Adicionar banco'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Salvar' : 'Adicionar'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isEditing) ...[
                TextField(
                  controller: _idController,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Item ID',
                    hintText: '00000000-0000-0000-0000-000000000000',
                    helperText: 'Dashboard → Demo → Itens Conectados',
                  ),
                ),
                const SizedBox(height: 20),
              ],
              LogoPickerField(
                logoDomain: _logoDomain,
                color: AppTheme.primaryColor,
                onChanged: (d) => setState(() => _logoDomain = d),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome do banco',
                  hintText: 'Ex.: Bradesco',
                  helperText: 'Aparece em cada movimentação',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
