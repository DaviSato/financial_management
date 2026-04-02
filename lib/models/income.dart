import 'package:uuid/uuid.dart';

import 'recurrence.dart';

class Income {
  final String id;
  final double amount;
  final String title;
  final String? notes;
  final RecurrenceType recurrenceType;
  final int? durationMonths; // For period recurrence
  final DateTime createdAt;

  Income({
    String? id,
    required this.amount,
    required this.title,
    this.notes,
    this.recurrenceType = RecurrenceType.once,
    this.durationMonths,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'id': id,
      'amount': amount,
      'notes': notes,
      'recurrenceType': recurrenceType.toString(),
      'durationMonths': durationMonths,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Rendimento',
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      recurrenceType: _parseRecurrenceType(json['recurrenceType'] as String?),
      durationMonths: json['durationMonths'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static RecurrenceType _parseRecurrenceType(String? value) {
    if (value == null || value.isEmpty) return RecurrenceType.once;
    return RecurrenceType.values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => RecurrenceType.once,
    );
  }

  // Copy with modifications
  Income copyWith({
    String? id,
    double? amount,
    String? title,
    String? notes,
    RecurrenceType? recurrenceType,
    int? durationMonths,
    DateTime? createdAt,
  }) {
    return Income(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      title: title ?? this.title,

      notes: notes ?? this.notes,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      durationMonths: durationMonths ?? this.durationMonths,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Income(id: $id, amount: $amount, notes: $notes, recurrenceType: $recurrenceType, createdAt: $createdAt)';
}
