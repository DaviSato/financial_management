import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/recurrence.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<Income> _incomes = [];
  List<Expense> _expenses = [];
  List<Category> _categories = [];

  AppState() {
    _loadData();
  }

  // Getters
  List<Income> get incomes => _incomes;
  List<Expense> get expenses => _expenses;
  List<Category> get categories => _categories;

  // Helper methods to expand recurring transactions
  List<Income> _expandIncomes(
    List<Income> incomes, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final expanded = <Income>[];
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? DateTime(now.year + 1, now.month, 1);

    for (final income in incomes) {
      if (income.recurrenceType == RecurrenceType.once) {
        expanded.add(income);
      } else if (income.recurrenceType == RecurrenceType.monthly) {
        // Create instances for each month from date onwards (indefinite, but limited by range)
        var current = DateTime(
          income.createdAt.year,
          income.createdAt.month,
          1,
        );
        while (current.isBefore(end)) {
          if (current.isAfter(start) || current.isAtSameMomentAs(start)) {
            expanded.add(income.copyWith(createdAt: current));
          }
          current = DateTime(current.year, current.month + 1, 1);
        }
      } else if (income.recurrenceType == RecurrenceType.period) {
        // Create instances for durationMonths starting from date
        if (income.durationMonths != null && income.durationMonths! > 0) {
          for (int i = 0; i < income.durationMonths!; i++) {
            final monthDate = DateTime(
              income.createdAt.year,
              income.createdAt.month + i,
              income.createdAt.day,
            );
            expanded.add(income.copyWith(createdAt: monthDate));
          }
        }
      }
    }
    return expanded;
  }

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
        // Create instances for each month from date onwards (indefinite, but limited by range)
        var current = DateTime(expense.dueDate.year, expense.dueDate.month, 1);
        while (current.isBefore(end)) {
          if (current.isAfter(start) || current.isAtSameMomentAs(start)) {
            expanded.add(expense.copyWith(dueDate: current));
          }
          current = DateTime(current.year, current.month + 1, 1);
        }
      } else if (expense.recurrenceType == RecurrenceType.period) {
        // Create instances for durationMonths starting from date
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

  // Calculated properties
  double get totalIncome {
    final expandedIncomes = _expandIncomes(_incomes);
    return expandedIncomes.fold(0.0, (sum, income) => sum + income.amount);
  }

  double get totalExpenses {
    final expandedExpenses = _expandExpenses(_expenses);
    return expandedExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double get balance => totalIncome - totalExpenses;

  double getCurrentMonthIncome() {
    final now = DateTime.now();
    final expandedIncomes = _expandIncomes(_incomes);
    return expandedIncomes
        .where(
          (income) =>
              income.createdAt.month == now.month &&
              income.createdAt.year == now.year,
        )
        .fold(0.0, (sum, income) => sum + income.amount);
  }

  double getCurrentMonthExpenses() {
    final now = DateTime.now();
    final expandedExpenses = _expandExpenses(_expenses);
    return expandedExpenses
        .where(
          (expense) =>
              expense.dueDate.month == now.month &&
              expense.dueDate.year == now.year,
        )
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Get expenses filtered by date range
  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    final normalizedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final expandedExpenses = _expandExpenses(_expenses);
    return expandedExpenses
        .where(
          (expense) =>
              expense.dueDate.isAfter(start) &&
              expense.dueDate.isBefore(normalizedEnd),
        )
        .toList();
  }

  // Get expenses by category
  Map<String, double> getExpensesByCategory() {
    final expandedExpenses = _expandExpenses(_expenses);
    final map = <String, double>{};
    for (var expense in expandedExpenses) {
      map[expense.category] = (map[expense.category] ?? 0) + expense.amount;
    }
    return map;
  }

  // Get expenses by category for a date range
  Map<String, double> getExpensesByCategoryForDateRange(
    DateTime start,
    DateTime end,
  ) {
    final expenses = getExpensesByDateRange(start, end);
    final map = <String, double>{};
    for (var expense in expenses) {
      map[expense.category] = (map[expense.category] ?? 0) + expense.amount;
    }
    return map;
  }

  // Income operations
  Future<void> addIncome(Income income) async {
    await _storageService.saveIncome(income);
    _incomes.add(income);
    notifyListeners();
  }

  Future<void> updateIncome(Income income) async {
    await _storageService.saveIncome(income);
    final index = _incomes.indexWhere((i) => i.id == income.id);
    if (index != -1) {
      _incomes[index] = income;
      notifyListeners();
    }
  }

  Future<void> deleteIncome(String id) async {
    await _storageService.deleteIncome(id);
    _incomes.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  // Expense operations
  Future<void> addExpense(Expense expense) async {
    await _storageService.saveExpense(expense);
    _expenses.add(expense);
    notifyListeners();
  }

  Future<void> updateExpense(Expense expense) async {
    await _storageService.saveExpense(expense);
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
      notifyListeners();
    }
  }

  Future<void> deleteExpense(String id) async {
    await _storageService.deleteExpense(id);
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // Category operations
  Future<void> addCustomCategory(Category category) async {
    await _storageService.addCustomCategory(category);
    _categories = await _storageService.getCategories();
    notifyListeners();
  }

  Future<void> updateCategory(Category category) async {
    await _storageService.updateCategory(category);
    _categories = await _storageService.getCategories();
    notifyListeners();
  }

  Future<void> deleteCustomCategory(String categoryId) async {
    await _storageService.deleteCustomCategory(categoryId);
    _categories = await _storageService.getCategories();
    notifyListeners();
  }

  // Load all data from storage
  Future<void> _loadData() async {
    _incomes = await _storageService.getIncomes();
    _expenses = await _storageService.getExpenses();
    _categories = await _storageService.getCategories();
    notifyListeners();
  }

  // Refresh data from storage
  Future<void> refreshData() async {
    await _loadData();
  }
}
