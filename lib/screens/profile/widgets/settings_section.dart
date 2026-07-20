import 'package:flutter/material.dart';

/// Título de uma seção da tela de configurações.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6E6E78),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
