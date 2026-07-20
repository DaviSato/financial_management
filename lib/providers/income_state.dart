import 'package:flutter/material.dart';

import '../models/income.dart';
import '../models/recurrence.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/date_utils.dart';

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

  /// Expande os rendimentos recorrentes em ocorrências concretas dentro de
  /// [startDate] (inclusivo) e [endDate] (exclusivo).
  List<Income> _expandIncomes(
    List<Income> incomes, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final expanded = <Income>[];
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? DateTime(now.year + 1, now.month, 1);

    bool inRange(DateTime date) => !date.isBefore(start) && date.isBefore(end);

    for (final income in incomes) {
      if (income.recurrenceType == RecurrenceType.monthly) {
        // Recorrente: repete a cada N meses a partir da data de recebimento.
        final step = income.effectiveIntervalMonths;
        var offset = 0;
        var current = income.receiveDate;
        while (current.isBefore(end)) {
          if (inRange(current)) {
            expanded.add(income.copyWith(receiveDate: current));
          }
          offset += step;
          current = addMonths(income.receiveDate, offset);
        }
      } else if (income.recurrenceType == RecurrenceType.period) {
        final duration = income.durationMonths ?? 0;
        for (var i = 0; i < duration; i++) {
          final date = addMonths(income.receiveDate, i);
          if (inRange(date)) {
            expanded.add(income.copyWith(receiveDate: date));
          }
        }
      } else {
        // Único (e qualquer tipo não previsto): uma ocorrência na data.
        if (inRange(income.receiveDate)) expanded.add(income);
      }
    }
    return expanded;
  }

  double get totalIncome {
    final expanded = _expandIncomes(_incomes);
    return expanded.fold(0.0, (sum, i) => sum + i.amount);
  }

  double getCurrentMonthIncome() => getIncomeForMonth(DateTime.now());

  double getIncomeForMonth(DateTime month) => getIncomesListForMonth(
    month,
  ).fold(0.0, (sum, i) => sum + i.amount);

  /// Ocorrências de rendimento que caem no mês informado.
  List<Income> getIncomesListForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return _expandIncomes(_incomes, startDate: start, endDate: end);
  }
}
