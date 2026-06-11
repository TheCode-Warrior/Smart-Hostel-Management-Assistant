import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationsSubscription;
  StreamSubscription<int>? _unreadSubscription;

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load notifications for user
  void loadNotifications(String userId) {
    _setLoading(true);

    _notificationsSubscription?.cancel();
    _notificationsSubscription = NotificationService.getUserNotifications(userId).listen(
      (notifications) {
        _notifications = notifications;
        _unreadCount = notifications.where((n) => n['isRead'] == false).length;
        _setLoading(false);
      },
      onError: (error) {
        _errorMessage = error.toString();
        _setLoading(false);
      },
    );
  }

  // Load unread count only
  void loadUnreadCount(String userId) {
    _unreadSubscription?.cancel();
    _unreadSubscription = NotificationService.getUnreadCount(userId).listen(
      (count) {
        _unreadCount = count;
        _safeNotify();
      },
      onError: (error) {
        debugPrint('Error loading unread count: $error');
      },
    );
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
      
      // Update local state
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['isRead'] = true;
        _unreadCount = _notifications.where((n) => n['isRead'] == false).length;
        _safeNotify();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _safeNotify();
    }
  }

  // Mark all as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await NotificationService.markAllAsRead(userId);
      
      // Update local state
      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
      _unreadCount = 0;
      _safeNotify();
    } catch (e) {
      _errorMessage = e.toString();
      _safeNotify();
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await NotificationService.deleteNotification(notificationId);
      
      // Update local state
      _notifications.removeWhere((n) => n['id'] == notificationId);
      _unreadCount = _notifications.where((n) => n['isRead'] == false).length;
      _safeNotify();
    } catch (e) {
      _errorMessage = e.toString();
      _safeNotify();
    }
  }

  // Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    try {
      await NotificationService.deleteAllNotifications(userId);
      _notifications.clear();
      _unreadCount = 0;
      _safeNotify();
    } catch (e) {
      _errorMessage = e.toString();
      _safeNotify();
    }
  }

  // Send notification (for staff/admin)
  Future<bool> sendNotification({
    required String title,
    required String body,
    required String userId,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    _setLoading(true);
    try {
      final success = await NotificationService.sendNotification(
        title: title,
        body: body,
        userId: userId,
        type: type,
        data: data,
      );
      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Send bulk notification
  Future<bool> sendBulkNotification({
    required String title,
    required String body,
    required List<String> userIds,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    _setLoading(true);
    try {
      final success = await NotificationService.sendBulkNotification(
        title: title,
        body: body,
        userIds: userIds,
        type: type,
        data: data,
      );
      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Send to all students
  Future<bool> sendToAllStudents({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    _setLoading(true);
    try {
      final success = await NotificationService.sendToAllStudents(
        title: title,
        body: body,
        type: type,
        data: data,
      );
      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Send to all staff
  Future<bool> sendToAllStaff({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    _setLoading(true);
    try {
      final success = await NotificationService.sendToAllStaff(
        title: title,
        body: body,
        type: type,
        data: data,
      );
      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Schedule notification
  Future<bool> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      await NotificationService.scheduleNotification(
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        payload: payload,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _safeNotify();
      return false;
    }
  }

  // Delete old notifications
  Future<void> deleteOldNotifications({int daysOld = 30}) async {
    try {
      await NotificationService.deleteOldNotifications(daysOld: daysOld);
    } catch (e) {
      _errorMessage = e.toString();
      _safeNotify();
    }
  }

  // Clear all notifications locally
  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    _safeNotify();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    _safeNotify();
  }

  // Refresh notifications
  Future<void> refreshNotifications(String userId) async {
    loadNotifications(userId);
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    _safeNotify();
  }

  void _safeNotify() {
    if (_isDisposed) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) return;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notificationsSubscription?.cancel();
    _unreadSubscription?.cancel();
    super.dispose();
  }
}