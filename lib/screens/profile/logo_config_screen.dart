import 'package:flutter/material.dart';

import '../../services/logo_config.dart';

/// Formulário das chaves do logo.dev, no mesmo molde da conexão com a nuvem.
///
/// São duas chaves: a publicável (`pk_`, baixa as imagens) e a secreta (`sk_`,
/// busca por nome). Cada usuário traz as suas, sobrepondo o `.env`. Diferente do
/// Firebase, valem na hora — não precisa reiniciar.
class LogoConfigScreen extends StatefulWidget {
  const LogoConfigScreen({super.key});

  @override
  State<LogoConfigScreen> createState() => _LogoConfigScreenState();
}

class _LogoConfigScreenState extends State<LogoConfigScreen> {
  late final TextEditingController _pkController;
  late final TextEditingController _skController;

  @override
  void initState() {
    super.initState();
    final cfg = LogoConfig();
    // Pré-preenche com a chave ativa (app ou .env), para ver e ajustar.
    _pkController = TextEditingController(text: cfg.token);
    _skController = TextEditingController(text: cfg.secretKey);
  }

  @override
  void dispose() {
    _pkController.dispose();
    _skController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await LogoConfig().save(
      publishable: _pkController.text,
      secret: _skController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chaves salvas.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logos de marca'),
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
                'Cole suas chaves do logo.dev (Dashboard → API Keys). Elas '
                'sobrepõem o padrão do build e valem na hora.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pkController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Chave publicável (pk_...)',
                  prefixIcon: Icon(Icons.key_outlined),
                  helperText: 'Baixa a imagem do logo',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _skController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Chave de busca (sk_...)',
                  prefixIcon: Icon(Icons.search_rounded),
                  helperText: 'Busca as marcas por nome',
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
}
