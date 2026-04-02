import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String colorHex;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.colorHex = '0xFF1E88E5',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Color get color => Color(int.parse(colorHex));

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      colorHex: json['colorHex'] as String? ?? '0xFF1E88E5',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // Copy with modifications
  Category copyWith({
    String? id,
    String? name,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Category(id: $id, name: $name, colorHex: $colorHex, createdAt: $createdAt)';
}
