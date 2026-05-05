import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../models/recurrence.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class ExpenseState extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final FirestoreService? _firestoreService;

  List<Expense> _expenses = [];

  ExpenseState([this._firestoreService]);

  List<Expense> get expenses => _expenses;

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _expenses = await _storageService.getExpenses();
    notifyListeners();
    NotificationService().reschedule(_expenses).catchError((_) {});
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  Future<void> addExpense(Expense expense) async {
    await _storageService.saveExpense(expense);
    _expenses.add(expense);
    notifyListeners();
    _firestoreService?.saveExpense(expense).catchError((_) {});
    NotificationService().reschedule(_expenses).catchError((_) {});
  }

  Future<void> updateExpense(Expense expense) async {
    await _storageService.saveExpense(expense);
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
      notifyListeners();
    }
    _firestoreService?.saveExpense(expense).catchError((_) {});
    NotificationService().reschedule(_expenses).catchError((_) {});
  }

  Future<void> deleteExpense(String id) async {
    await _storageService.deleteExpense(id);
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    _firestoreService?.deleteExpense(id).catchError((_) {});
    NotificationService().reschedule(_expenses).catchError((_) {});
  }

  Future<void> toggleExpensePaid(String id, DateTime month) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final expense = _expenses[index];
    final updated = Map<String, DateTime>.of(expense.paidByMonth);
    final key = expense.recurrenceType.name == 'once'
        ? 'once'
        : '${month.year}-${month.month.toString().padLeft(2, '0')}';
    if (updated.containsKey(key)) {
      updated.remove(key);
    } else {
      updated[key] = DateTime.now();
    }
    final newExpense = expense.copyWith(paidByMonth: updated);
    await _storageService.saveExpense(newExpense);
    _expenses[index] = newExpense;
    notifyListeners();
    _firestoreService?.saveExpense(newExpense).catchError((_) {});
  }

  Future<void> toggleNotifyOnDue(String id) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final updated = _expenses[index].copyWith(
      notifyOnDue: !_expenses[index].notifyOnDue,
    );
    await _storageService.saveExpense(updated);
    _expenses[index] = updated;
    notifyListeners();
    _firestoreService?.saveExpense(updated).catchError((_) {});
    NotificationService().reschedule(_expenses).catchError((_) {});
  }

  /// Called by CategoryState when a category is renamed.
  Future<void> renameCategoryOnExpenses(String oldName, String newName) async {
    _expenses = _expenses
        .map((e) => e.category == oldName ? e.copyWith(category: newName) : e)
        .toList();
    await _storageService.saveAllExpenses(_expenses);
    final affected = _expenses.where((e) => e.category == newName).toList();
    _firestoreService?.saveExpensesBatch(affected).catchError((_) {});
    notifyListeners();
  }

  /// Called by CategoryState when a category is deleted.
  Future<void> clearCategoryOnExpenses(String categoryName) async {
    _expenses = _expenses
        .map((e) => e.category == categoryName ? e.copyWith(category: '') : e)
        .toList();
    final affected = _expenses.where((e) => e.category == '').toList();
    await _storageService.saveAllExpenses(_expenses);
    _firestoreService?.saveExpensesBatch(affected).catchError((_) {});
    notifyListeners();
  }

  // ── Computed ─────────────────────────────────────────────────────────────────

  List<Expense> _expandExpenses(
    List<Expense> expenses, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final expanded = <Expense>[];
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? DateTime(now.year + 1, now.month, 1);

    for (final expense in expenses) {
      if (expense.recurrenceType == RecurrenceType.once) {
        expanded.add(expense);
      } else if (expense.recurrenceType == RecurrenceType.monthly) {
        final day = expense.dueDate.day;
        var current = DateTime(expense.dueDate.year, expense.dueDate.month, day);
        while (current.isBefore(end)) {
          if (!current.isBefore(start)) {
            expanded.add(expense.copyWith(dueDate: current));
          }
          current = DateTime(current.year, current.month + 1, day);
        }
      } else if (expense.recurrenceType == RecurrenceType.installment) {
        if (expense.durationMonths != null && expense.durationMonths! > 0) {
          final installmentAmount = expense.amount / expense.durationMonths!;
          for (int i = 0; i < expense.durationMonths!; i++) {
            final monthDate = DateTime(
              expense.dueDate.year,
              expense.dueDate.month + i,
              expense.dueDate.day,
            );
            expanded.add(expense.copyWith(dueDate: monthDate, amount: installmentAmount));
          }
        }
      } else if (expense.recurrenceType == RecurrenceType.period) {
        if (expense.durationMonths != null && expense.durationMonths! > 0) {
          for (int i = 0; i < expense.durationMonths!; i++) {
            final monthDate = DateTime(
              expense.dueDate.year,
              expense.dueDate.month + i,
              expense.dueDate.day,
            );
            expanded.add(expense.copyWith(dueDate: monthDate));
          }
        }
      }
    }
    return expanded;
  }

  double get totalExpenses {
    final expanded = _expandExpenses(_expenses);
    return expanded.fold(0.0, (sum, e) => sum + e.amount);
  }

  double getCurrentMonthExpenses() {
    final now = DateTime.now();
    final expanded = _expandExpenses(_expenses);
    return expanded
        .where((e) => e.dueDate.month == now.month && e.dueDate.year == now.year)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double getExpensesForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final expanded = _expandExpenses(_expenses, startDate: start, endDate: end);
    return expanded
        .where((e) => e.dueDate.year == month.year && e.dueDate.month == month.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  List<Expense> getExpensesListForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return _expandExpenses(_expenses, startDate: start, endDate: end)
        .where((e) => e.dueDate.year == month.year && e.dueDate.month == month.month)
        .toList();
  }

  Map<String, double> getExpensesByCategoryForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final expanded = _expandExpenses(_expenses, startDate: start, endDate: end);
    final filtered = expanded.where(
      (e) => e.dueDate.year == month.year && e.dueDate.month == month.month,
    );
    final map = <String, double>{};
    for (final e in filtered) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    final normalizedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final expanded = _expandExpenses(_expenses);
    return expanded
        .where((e) => !e.dueDate.isBefore(start) && e.dueDate.isBefore(normalizedEnd))
        .toList();
  }

  Map<String, double> getExpensesByCategory() {
    final expanded = _expandExpenses(_expenses);
    final map = <String, double>{};
    for (final e in expanded) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }
}
