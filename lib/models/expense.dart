import 'package:uuid/uuid.dart';

import 'payment_method.dart';
import 'recurrence.dart';

class Expense {
  final String id;
  final double amount;
  final String title;
  final String category;
  final String? notes;
  final RecurrenceType recurrenceType;
  final int? durationMonths;
  final PaymentMethod? paymentMethod;
  final DateTime dueDate;
  final DateTime createdAt;
  final Map<String, DateTime> paidByMonth;
  final bool notifyOnDue;

  /// Domínio da marca (ex.: "spotify.com") para o logo. É só uma string — o
  /// arquivo do logo vive em disco (ver LogoService) e sincroniza por este
  /// campo, nunca pelos bytes. Null = sem logo (cai no visual padrão).
  final String? logoDomain;

  Expense({
    String? id,
    required this.amount,
    required this.title,
    required this.category,
    this.notes,
    this.recurrenceType = RecurrenceType.once,
    this.durationMonths,
    this.paymentMethod,
    required this.dueDate,
    DateTime? createdAt,
    Map<String, DateTime>? paidByMonth,
    this.notifyOnDue = false,
    this.logoDomain,
  }) : id = id ?? Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       paidByMonth = paidByMonth ?? {};

  static String _monthKey(DateTime m) =>
      '${m.year}-${m.month.toString().padLeft(2, '0')}';

  bool isPaidForMonth(DateTime month) {
    final key = recurrenceType == RecurrenceType.once ? 'once' : _monthKey(month);
    return paidByMonth.containsKey(key);
  }

  DateTime? paidDateForMonth(DateTime month) {
    final key = recurrenceType == RecurrenceType.once ? 'once' : _monthKey(month);
    return paidByMonth[key];
  }

  // ------------------------
  // Serialization
  // ------------------------
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'title': title,
      'category': category,
      'notes': notes,
      'recurrenceType': recurrenceType.name,
      'durationMonths': durationMonths,
      'paymentMethod': paymentMethod?.name,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'paidByMonth': paidByMonth.map((k, v) => MapEntry(k, v.toIso8601String())),
      'notifyOnDue': notifyOnDue,
      'logoDomain': logoDomain,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Gasto',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? 'Outros',
      notes: json['notes'] as String?,
      recurrenceType: _parseRecurrenceType(json['recurrenceType'] as String?),
      durationMonths: json['durationMonths'] as int?,
      paymentMethod: PaymentMethod.fromString(json['paymentMethod'] as String?),
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      paidByMonth: (json['paidByMonth'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, DateTime.parse(v as String))) ??
          {},
      notifyOnDue: json['notifyOnDue'] as bool? ?? false,
      logoDomain: json['logoDomain'] as String?,
    );
  }

  // ------------------------
  // Helpers
  // ------------------------
  static RecurrenceType _parseRecurrenceType(String? value) {
    if (value == null || value.isEmpty) return RecurrenceType.once;

    return RecurrenceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecurrenceType.once,
    );
  }

  // ------------------------
  // Copy
  // ------------------------
  Expense copyWith({
    String? id,
    double? amount,
    String? title,
    String? category,
    String? notes,
    RecurrenceType? recurrenceType,
    int? durationMonths,
    PaymentMethod? paymentMethod,
    DateTime? dueDate,
    DateTime? createdAt,
    Map<String, DateTime>? paidByMonth,
    bool? notifyOnDue,
    String? logoDomain,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      title: title ?? this.title,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      durationMonths: durationMonths ?? this.durationMonths,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      paidByMonth: paidByMonth ?? Map.of(this.paidByMonth),
      notifyOnDue: notifyOnDue ?? this.notifyOnDue,
      logoDomain: logoDomain ?? this.logoDomain,
    );
  }

  @override
  String toString() {
    return 'Expense('
        'id: $id, '
        'amount: $amount, '
        'title: $title, '
        'category: $category, '
        'notes: $notes, '
        'recurrenceType: $recurrenceType, '
        'durationMonths: $durationMonths, '
        'paymentMethod: $paymentMethod, '
        'dueDate: $dueDate, '
        'createdAt: $createdAt'
        ')';
  }
}
