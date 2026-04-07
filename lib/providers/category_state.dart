import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'expense_state.dart';

class CategoryState extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final FirestoreService? _firestoreService;
  final ExpenseState _expenseState;

  List<Category> _categories = [];

  CategoryState(this._expenseState, [this._firestoreService]);

  List<Category> get categories => _categories;

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _categories = await _storageService.getCategories();
    notifyListeners();
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  Future<void> addCustomCategory(Category category) async {
    await _storageService.addCustomCategory(category);
    _categories = await _storageService.getCategories();
    notifyListeners();
    _firestoreService?.saveCategory(category).catchError((_) {});
  }

  Future<void> updateCategory(Category category) async {
    final old = _categories.firstWhere(
      (c) => c.id == category.id,
      orElse: () => category,
    );
    await _storageService.updateCategory(category);
    _categories = await _storageService.getCategories();
    notifyListeners();

    if (old.name != category.name) {
      await _expenseState.renameCategoryOnExpenses(old.name, category.name);
    }

    _firestoreService?.saveCategory(category).catchError((_) {});
  }

  Future<void> deleteCustomCategory(String categoryId) async {
    final deleted = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(id: categoryId, name: ''),
    );
    await _storageService.deleteCustomCategory(categoryId);
    _categories = await _storageService.getCategories();
    notifyListeners();

    if (deleted.name.isNotEmpty) {
      await _expenseState.clearCategoryOnExpenses(deleted.name);
    }

    _firestoreService?.deleteCategory(categoryId).catchError((_) {});
  }
}
