import 'package:flutter/material.dart';

import '../../services/cloud_config.dart';
import '../../services/firebase_config.dart';

/// Formulário de conexão com o Firebase.
///
/// Valida só o formato (campos obrigatórios preenchidos), sem testar a rede — o
/// resultado real aparece no próximo boot, quando o Firebase é inicializado.
class CloudConfigScreen extends StatefulWidget {
  const CloudConfigScreen({super.key});

  @override
  State<CloudConfigScreen> createState() => _CloudConfigScreenState();
}

class _CloudConfigScreenState extends State<CloudConfigScreen> {
  static const _labels = {
    'apiKey': 'API Key',
    'appId': 'App ID',
    'messagingSenderId': 'Messaging Sender ID',
    'projectId': 'Project ID',
    'storageBucket': 'Storage Bucket',
  };

  // Storage Bucket é opcional (só necessário para anexos, ainda não usados).
  static const _optional = {'storageBucket'};

  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    // Pré-preenche com a config ativa (do app ou do .env), para o usuário ver e
    // ajustar em vez de digitar do zero.
    final current = FirebaseConfig.effectiveValues();
    _controllers = {
      for (final field in CloudConfig.fields)
        field: TextEditingController(text: current[field]),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    // Validação de formato: obrigatórios não podem estar vazios.
    for (final field in CloudConfig.fields) {
      if (_optional.contains(field)) continue;
      if (_controllers[field]!.text.trim().isEmpty) {
        _showError('Informe o ${_labels[field]}');
        return;
      }
    }

    await CloudConfig().save({
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    });

    if (!mounted) return;
    await _showRestartNotice();
    if (mounted) Navigator.of(context).pop();
  }

  /// Aviso depois de salvar: a mudança só vale no próximo boot.
  Future<void> _showRestartNotice() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded, size: 28),
        title: const Text('Reinicie o app'),
        content: const Text(
          'A conexão foi salva. Feche e abra o app novamente para conectar à '
          'nuvem — o Firebase só é inicializado na abertura.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexão com a nuvem'),
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
                'Cole os dados do seu projeto Firebase (Configurações do '
                'projeto → Seus apps → SDK). Eles sobrepõem o padrão do build.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 20),
              for (final field in CloudConfig.fields) ...[
                TextField(
                  controller: _controllers[field],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: _optional.contains(field)
                        ? '${_labels[field]} (opcional)'
                        : _labels[field],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
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
}
