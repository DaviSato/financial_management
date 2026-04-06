import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/income.dart';

class StorageService {
  static const String _incomeKey = 'incomes';
  static const String _expenseKey = 'expenses';
  static const String _customCategoriesKey = 'custom_categories';

  late SharedPreferences _prefs;

  StorageService._();

  static final StorageService _instance = StorageService._();

  factory StorageService() {
    return _instance;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Income operations
  Future<List<Income>> getIncomes() async {
    try {
      final jsonString = _prefs.getString(_incomeKey);
      if (jsonString == null) return [];
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((item) => Income.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveIncome(Income income) async {
    final incomes = await getIncomes();
    incomes.removeWhere((i) => i.id == income.id);
    incomes.add(income);
    await _saveIncomes(incomes);
  }

  Future<void> deleteIncome(String id) async {
    final incomes = await getIncomes();
    incomes.removeWhere((i) => i.id == id);
    await _saveIncomes(incomes);
  }

  Future<void> _saveIncomes(List<Income> incomes) async {
    final jsonList = incomes.map((i) => i.toJson()).toList();
    await _prefs.setString(_incomeKey, jsonEncode(jsonList));
  }

  // Expense operations
  Future<List<Expense>> getExpenses() async {
    try {
      final jsonString = _prefs.getString(_expenseKey);
      if (jsonString == null) return [];
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((item) => Expense.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveExpense(Expense expense) async {
    final expenses = await getExpenses();
    expenses.removeWhere((e) => e.id == expense.id);
    expenses.add(expense);
    await _saveExpenses(expenses);
  }

  Future<void> deleteExpense(String id) async {
    final expenses = await getExpenses();
    expenses.removeWhere((e) => e.id == id);
    await _saveExpenses(expenses);
  }

  Future<void> saveAllExpenses(List<Expense> expenses) => _saveExpenses(expenses);

  Future<void> _saveExpenses(List<Expense> expenses) async {
    final jsonList = expenses.map((e) => e.toJson()).toList();
    await _prefs.setString(_expenseKey, jsonEncode(jsonList));
  }

  // Category operations
  Future<List<Category>> getCategories() async {
    try {
      final jsonString = _prefs.getString(_customCategoriesKey);
      if (jsonString == null) return [];
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((item) => Category.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addCustomCategory(Category category) async {
    final categories = await getCategories();
    categories.removeWhere((c) => c.id == category.id);
    categories.add(category);
    await _saveCategories(categories);
  }

  Future<void> updateCategory(Category category) async {
    final categories = await getCategories();
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      categories[index] = category;
      await _saveCategories(categories);
    }
  }

  Future<void> deleteCustomCategory(String categoryId) async {
    final categories = await getCategories();
    categories.removeWhere((c) => c.id == categoryId);
    await _saveCategories(categories);
  }

  Future<void> _saveCategories(List<Category> categories) async {
    final jsonList = categories.map((c) => c.toJson()).toList();
    await _prefs.setString(_customCategoriesKey, jsonEncode(jsonList));
  }

  // Clear all data (for testing)
  Future<void> clearAll() async {
    await _prefs.remove(_incomeKey);
    await _prefs.remove(_expenseKey);
    await _prefs.remove(_customCategoriesKey);
  }
}
