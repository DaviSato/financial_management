import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/expense.dart';
import '../models/recurrence.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  static const _hourKey = 'notification_hour';
  static const _minuteKey = 'notification_minute';
  static const _defaultHour = 12;
  static const _defaultMinute = 0;

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _androidDetails = AndroidNotificationDetails(
    'due_expenses',
    'Vencimentos',
    channelDescription: 'Notificações de gastos a vencer',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    tz_data.initializeTimeZones();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final iOS = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    bool granted = true;
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
    }
    if (iOS != null) {
      granted = await iOS.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return granted;
  }

  Future<TimeOfDay> getNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_hourKey) ?? _defaultHour,
      minute: prefs.getInt(_minuteKey) ?? _defaultMinute,
    );
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);
  }

  /// Cancels all scheduled notifications and re-schedules one per day
  /// for the next 60 days, covering all expenses with notifyOnDue = true.
  Future<void> reschedule(List<Expense> allExpenses) async {
    await _plugin.cancelAll();

    final notifyExpenses = allExpenses.where((e) => e.notifyOnDue).toList();
    if (notifyExpenses.isEmpty) return;

    final time = await getNotificationTime();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int dayOffset = 0; dayOffset < 60; dayOffset++) {
      final checkDate = today.add(Duration(days: dayOffset));
      final due = _expensesDueOnDate(notifyExpenses, checkDate);
      if (due.isEmpty) continue;

      final scheduledTime = DateTime(
        checkDate.year,
        checkDate.month,
        checkDate.day,
        time.hour,
        time.minute,
      );
      if (scheduledTime.isBefore(now)) continue;

      final title = due.length == 1
          ? 'Vencimento hoje: ${due.first.title}'
          : '${due.length} gastos vencem hoje';
      final body = due.map((e) => e.title).join(', ');

      await _plugin.zonedSchedule(
        id: _idForDate(checkDate),
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// Fires an immediate notification for expenses due today.
  Future<void> sendTestNotification(List<Expense> allExpenses) async {
    final today = DateTime.now();
    final due = _expensesDueOnDate(
      allExpenses.where((e) => e.notifyOnDue).toList(),
      DateTime(today.year, today.month, today.day),
    );
    if (due.isEmpty) return;

    final title = due.length == 1
        ? 'Vencimento hoje: ${due.first.title}'
        : '${due.length} gastos vencem hoje';
    final body = due.map((e) => e.title).join(', ');

    await _plugin.show(
      id: 999999,
      title: title,
      body: body,
      notificationDetails: _notificationDetails,
    );
  }

  List<Expense> _expensesDueOnDate(List<Expense> expenses, DateTime date) {
    final result = <Expense>[];
    for (final expense in expenses) {
      if (expense.isPaidForMonth(date)) continue;

      if (expense.recurrenceType == RecurrenceType.once) {
        if (_sameDay(expense.dueDate, date)) result.add(expense);
      } else if (expense.recurrenceType == RecurrenceType.monthly) {
        if (expense.dueDate.day == date.day &&
            !date.isBefore(
                DateTime(expense.dueDate.year, expense.dueDate.month, 1))) {
          result.add(expense);
        }
      } else if (expense.recurrenceType == RecurrenceType.period) {
        final months = expense.durationMonths ?? 0;
        for (int i = 0; i < months; i++) {
          final occurrence = DateTime(
            expense.dueDate.year,
            expense.dueDate.month + i,
            expense.dueDate.day,
          );
          if (_sameDay(occurrence, date)) {
            result.add(expense);
            break;
          }
        }
      }
    }
    return result;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _idForDate(DateTime date) => date.difference(DateTime(2000)).inDays;
}
