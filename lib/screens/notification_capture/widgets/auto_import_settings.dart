import 'package:flutter/material.dart';

import '../../../models/category.dart';
import '../../../services/capture_settings.dart';

/// Cartão de configuração da importação automática.
///
/// Desligado = modo manual: as notificações ficam listadas e o usuário lança
/// cada uma. Ligado = as transações de regra confirmada entram sozinhas, com a
/// categoria escolhida aqui e marcadas como automáticas.
class AutoImportSettings extends StatefulWidget {
  const AutoImportSettings({super.key, required this.categories});

  final List<Category> categories;

  @override
  State<AutoImportSettings> createState() => _AutoImportSettingsState();
}

class _AutoImportSettingsState extends State<AutoImportSettings> {
  final _settings = CaptureSettings();

  bool _loading = true;
  bool _enabled = false;
  String? _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _settings.isAutoImportEnabled();
    final category = await _settings.defaultCategory();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _category = category;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    await _settings.setAutoImportEnabled(value);
    setState(() => _enabled = value);
  }

  Future<void> _pickCategory(String? value) async {
    if (value == null) return;
    await _settings.setDefaultCategory(value);
    setState(() => _category = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    // A categoria selecionada pode ter sido renomeada/excluída; só oferece uma
    // seleção válida ao dropdown.
    final names = widget.categories.map((c) => c.name).toList();
    final selected = names.contains(_category) ? _category : null;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _enabled,
              onChanged: _toggle,
              contentPadding: EdgeInsets.zero,
              title: const Text('Importação automática'),
              subtitle: const Text(
                'Lança sozinho as transações reconhecidas com segurança. As '
                'demais continuam aqui para você revisar.',
                style: TextStyle(fontSize: 11),
              ),
            ),
            if (_enabled) ...[
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                items: [
                  for (final category in widget.categories)
                    DropdownMenuItem(
                      value: category.name,
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: category.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    ),
                ],
                onChanged: _pickCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoria dos lançamentos automáticos',
                  helperText: 'Você pode recategorizar cada um depois.',
                  helperMaxLines: 2,
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
