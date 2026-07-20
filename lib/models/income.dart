import 'package:uuid/uuid.dart';

import 'recurrence.dart';

class Income {
  final String id;
  final double amount;
  final String title;
  final String? notes;
  final RecurrenceType recurrenceType;
  final int? durationMonths; // For period recurrence
  final int? intervalMonths; // For monthly recurrence: repete a cada N meses
  final DateTime receiveDate;
  final DateTime createdAt;

  Income({
    String? id,
    required this.amount,
    required this.title,
    this.notes,
    this.recurrenceType = RecurrenceType.once,
    this.durationMonths,
    this.intervalMonths,
    DateTime? receiveDate,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       receiveDate = receiveDate ?? createdAt ?? DateTime.now();

  /// Intervalo efetivo entre recebimentos recorrentes: 1 = mensal, 6 =
  /// semestral, 12 = anual (13º, saque-aniversário do FGTS).
  int get effectiveIntervalMonths =>
      (intervalMonths != null && intervalMonths! > 0) ? intervalMonths! : 1;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'id': id,
      'amount': amount,
      'notes': notes,
      'recurrenceType': recurrenceType.name,
      'durationMonths': durationMonths,
      'intervalMonths': intervalMonths,
      'receiveDate': receiveDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory Income.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now();

    return Income(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Rendimento',
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      recurrenceType: _parseRecurrenceType(json['recurrenceType'] as String?),
      durationMonths: json['durationMonths'] as int?,
      intervalMonths: json['intervalMonths'] as int?,
      // Rendimentos antigos não têm data própria — usam a de criação.
      receiveDate: json['receiveDate'] != null
          ? DateTime.parse(json['receiveDate'] as String)
          : createdAt,
      createdAt: createdAt,
    );
  }

  static RecurrenceType _parseRecurrenceType(String? value) {
    if (value == null || value.isEmpty) return RecurrenceType.once;
    return RecurrenceType.values.firstWhere(
      (e) => e.name == value,
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
    int? intervalMonths,
    DateTime? receiveDate,
    DateTime? createdAt,
  }) {
    return Income(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      durationMonths: durationMonths ?? this.durationMonths,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      receiveDate: receiveDate ?? this.receiveDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Income(id: $id, title: $title, amount: $amount, notes: $notes, '
      'recurrenceType: $recurrenceType, durationMonths: $durationMonths, '
      'intervalMonths: $intervalMonths, receiveDate: $receiveDate, '
      'createdAt: $createdAt)';
}
