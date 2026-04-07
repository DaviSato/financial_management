import 'package:flutter/material.dart';

import '../models/income.dart';
import '../models/recurrence.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class IncomeState extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final FirestoreService? _firestoreService;

  List<Income> _incomes = [];

  IncomeState([this._firestoreService]);

  List<Income> get incomes => _incomes;

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _incomes = await _storageService.getIncomes();
    notifyListeners();
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  Future<void> addIncome(Income income) async {
    await _storageService.saveIncome(income);
    _incomes.add(income);
    notifyListeners();
    _firestoreService?.saveIncome(income).catchError((_) {});
  }

  Future<void> updateIncome(Income income) async {
    await _storageService.saveIncome(income);
    final index = _incomes.indexWhere((i) => i.id == income.id);
    if (index != -1) {
      _incomes[index] = income;
      notifyListeners();
    }
    _firestoreService?.saveIncome(income).catchError((_) {});
  }

  Future<void> deleteIncome(String id) async {
    await _storageService.deleteIncome(id);
    _incomes.removeWhere((i) => i.id == id);
    notifyListeners();
    _firestoreService?.deleteIncome(id).catchError((_) {});
  }

  // ── Computed ─────────────────────────────────────────────────────────────────

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
        var current = DateTime(income.createdAt.year, income.createdAt.month, 1);
        while (current.isBefore(end)) {
          if (current.isAfter(start) || current.isAtSameMomentAs(start)) {
            expanded.add(income.copyWith(createdAt: current));
          }
          current = DateTime(current.year, current.month + 1, 1);
        }
      } else if (income.recurrenceType == RecurrenceType.period) {
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

  double get totalIncome {
    final expanded = _expandIncomes(_incomes);
    return expanded.fold(0.0, (sum, i) => sum + i.amount);
  }

  double getCurrentMonthIncome() {
    final now = DateTime.now();
    final expanded = _expandIncomes(_incomes);
    return expanded
        .where((i) => i.createdAt.month == now.month && i.createdAt.year == now.year)
        .fold(0.0, (sum, i) => sum + i.amount);
  }

  double getIncomeForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final expanded = _expandIncomes(_incomes, startDate: start, endDate: end);
    return expanded
        .where((i) => i.createdAt.year == month.year && i.createdAt.month == month.month)
        .fold(0.0, (sum, i) => sum + i.amount);
  }
}
