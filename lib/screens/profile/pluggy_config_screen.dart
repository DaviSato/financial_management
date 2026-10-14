import 'package:flutter/material.dart';

import '../../models/bank_connection.dart';
import '../../services/bank_sync_service.dart';
import '../../services/pluggy_client.dart';
import '../../services/pluggy_config.dart';

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
  bool _obscureSecret = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    final cfg = PluggyConfig();
    // Pré-preenche com o valor ativo (app ou .env), para ver e ajustar.
    _idController = TextEditingController(text: cfg.clientId);
    _secretController = TextEditingController(text: cfg.clientSecret);
  }

  @override
  void dispose() {
    _idController.dispose();
    _secretController.dispose();
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

  Future<void> _save() async {
    await _saveCredentials();
    if (!mounted) return;
    _snack('Credenciais salvas.');
    Navigator.of(context).pop();
  }

  Future<void> _addConnection() async {
    final itemId = await showDialog<String>(
      context: context,
      builder: (_) => const _ItemIdDialog(),
    );
    if (itemId == null || itemId.isEmpty) return;

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
      await cfg.addConnection(
        BankConnection(
          itemId: item.id,
          institution: item.institution,
          connectedAt: DateTime.now(),
        ),
      );
      BankSyncService().reset();
      if (mounted) _snack('${item.institution} conectado.');
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_balance_outlined),
                  title: Text(c.institution.isEmpty ? c.itemId : c.institution),
                  subtitle: Text(
                    'Desde ${_formatDate(c.connectedAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
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

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Pede o id do item (UUID mostrado no Dashboard/Meu Pluggy).
class _ItemIdDialog extends StatefulWidget {
  const _ItemIdDialog();

  @override
  State<_ItemIdDialog> createState() => _ItemIdDialogState();
}

class _ItemIdDialogState extends State<_ItemIdDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar banco'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Item ID',
          hintText: '00000000-0000-0000-0000-000000000000',
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
