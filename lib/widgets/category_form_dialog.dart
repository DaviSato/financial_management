import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/app_state.dart';

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog._({this.category});

  final Category? category;

  /// Shows the dialog and returns the saved [Category], or null if cancelled.
  static Future<Category?> show(BuildContext context, {Category? category}) {
    return showDialog<Category>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoryFormDialog._(category: category),
    );
  }

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  late final TextEditingController _nameController;
  late Color _selectedColor;
  String? _nameError;

  static const List<_ColorGroup> _colorGroups = [
    _ColorGroup('Azuis', [
      Color(0xFF1E88E5),
      Color(0xFF1565C0),
      Color(0xFF2196F3),
      Color(0xFF00BCD4),
      Color(0xFF0288D1),
    ]),
    _ColorGroup('Verdes', [
      Color(0xFF4CAF50),
      Color(0xFF2E7D32),
      Color(0xFF00897B),
      Color(0xFF43A047),
      Color(0xFF8BC34A),
    ]),
    _ColorGroup('Quentes', [
      Color(0xFFFF5252),
      Color(0xFFFF7043),
      Color(0xFFFFB300),
      Color(0xFFE91E63),
      Color(0xFFFF9800),
    ]),
    _ColorGroup('Outros', [
      Color(0xFF9C27B0),
      Color(0xFF673AB7),
      Color(0xFF607D8B),
      Color(0xFF795548),
      Color(0xFF03DAC6),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? _colorGroups.first.colors.first;
    _nameController.addListener(() {
      if (_nameError != null && _nameController.text.isNotEmpty) {
        setState(() => _nameError = null);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _colorHex =>
      '0x${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0')}';

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Informe um nome para a categoria');
      return;
    }

    final appState = context.read<AppState>();
    Category saved;

    if (widget.category == null) {
      saved = Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        colorHex: _colorHex,
      );
      appState.addCustomCategory(saved);
    } else {
      saved = widget.category!.copyWith(name: name, colorHex: _colorHex);
      appState.updateCategory(saved);
    }

    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    isEdit ? 'Editar Categoria' : 'Nova Categoria',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Preview
              ValueListenableBuilder(
                valueListenable: _nameController,
                builder: (context, value, _) {
                  final previewName = value.text.trim().isEmpty
                      ? 'Pré-visualização'
                      : value.text.trim();
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            previewName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: value.text.trim().isEmpty
                                  ? Colors.grey
                                  : Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Name field
              TextField(
                controller: _nameController,
                autofocus: !isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nome da Categoria',
                  hintText: 'Ex: Alimentação, Transporte...',
                  errorText: _nameError,
                  prefixIcon: const Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 24),

              // Color picker
              Text('Cor', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              ..._colorGroups.map((group) => _buildColorGroup(group)),

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(isEdit ? 'Salvar' : 'Criar'),
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

  Widget _buildColorGroup(_ColorGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: group.colors.map((color) {
              final isSelected = color.toARGB32() == _selectedColor.toARGB32();
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2.5)
                          : Border.all(color: Colors.transparent, width: 2.5),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ColorGroup {
  const _ColorGroup(this.label, this.colors);
  final String label;
  final List<Color> colors;
}
