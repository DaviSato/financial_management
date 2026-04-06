import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../models/income.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService _instance = FirestoreService._();
  factory FirestoreService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  CollectionReference<Map<String, dynamic>> _col(String name) {
    final uid = _auth.uid;
    if (uid == null) throw StateError('User not authenticated');
    return _db.collection('users').doc(uid).collection(name);
  }

  // ─── Income ───────────────────────────────────────────────────────────────

  Future<void> saveIncome(Income income) async {
    await _col('incomes').doc(income.id).set(income.toJson());
  }

  Future<void> deleteIncome(String id) async {
    await _col('incomes').doc(id).delete();
  }

  // ─── Expense ──────────────────────────────────────────────────────────────

  Future<void> saveExpense(Expense expense) async {
    await _col('expenses').doc(expense.id).set(expense.toJson());
  }

  Future<void> deleteExpense(String id) async {
    await _col('expenses').doc(id).delete();
  }

  Future<void> saveExpensesBatch(List<Expense> expenses) async {
    if (expenses.isEmpty) return;
    const chunkSize = 400;
    for (var i = 0; i < expenses.length; i += chunkSize) {
      final chunk = expenses.sublist(i, min(i + chunkSize, expenses.length));
      final batch = _db.batch();
      for (final expense in chunk) {
        batch.set(_col('expenses').doc(expense.id), expense.toJson());
      }
      await batch.commit();
    }
  }

  // ─── Category ─────────────────────────────────────────────────────────────

  Future<void> saveCategory(Category category) async {
    await _col('categories').doc(category.id).set(category.toJson());
  }

  Future<void> deleteCategory(String id) async {
    await _col('categories').doc(id).delete();
  }

  // ─── Sync from Firestore → SharedPreferences ──────────────────────────────
  //
  // Called once on login. Firestore is the source of truth: its data overwrites
  // local SharedPreferences. If Firestore has no data yet (new account), the
  // local data is pushed up to Firestore instead.

  Future<void> syncFromFirestore(StorageService local) async {
    final results = await Future.wait([
      _col('incomes').get(),
      _col('expenses').get(),
      _col('categories').get(),
    ]);

    final incomeDocs = results[0].docs;
    final expenseDocs = results[1].docs;
    final categoryDocs = results[2].docs;

    final hasCloudData =
        incomeDocs.isNotEmpty || expenseDocs.isNotEmpty || categoryDocs.isNotEmpty;

    if (hasCloudData) {
      // Overwrite local with cloud data
      final incomes = incomeDocs
          .map((d) => Income.fromJson(d.data()))
          .toList();
      final expenses = expenseDocs
          .map((d) => Expense.fromJson(d.data()))
          .toList();
      final categories = categoryDocs
          .map((d) => Category.fromJson(d.data()))
          .toList();

      await local.saveAllIncomes(incomes);
      await local.saveAllExpenses(expenses);
      await local.saveAllCategories(categories);
    } else {
      // No cloud data yet — push local data up to Firestore
      final incomes = await local.getIncomes();
      final expenses = await local.getExpenses();
      final categories = await local.getCategories();

      for (final i in incomes) {
        await saveIncome(i);
      }
      await saveExpensesBatch(expenses);
      for (final c in categories) {
        await saveCategory(c);
      }
    }
  }
}
