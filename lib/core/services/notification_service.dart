import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  static Future<void> initialize() async {
    // Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Get FCM token
    try {
      String? token = await _fcm.getToken();
      debugPrint('FCM Token: $token');
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // Listen to messages
    FirebaseMessaging.onMessage.listen(_onMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }

  // Send notification to specific user
  static Future<bool> sendNotification({
    required String title,
    required String body,
    required String userId,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Store in Firestore
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'type': type ?? 'general',
        'userId': userId,
        'data': data ?? {},
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      debugPrint('✅ Notification sent to $userId: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      return false;
    }
  }

  // Send notification to multiple users (batch - max 500)
  static Future<bool> sendBulkNotification({
    required String title,
    required String body,
    required List<String> userIds,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Firebase batch has limit of 500 operations
      // Process in chunks of 500
      const batchSize = 500;
      for (int i = 0; i < userIds.length; i += batchSize) {
        final end = (i + batchSize < userIds.length) ? i + batchSize : userIds.length;
        final chunk = userIds.sublist(i, end);
        
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        
        for (String userId in chunk) {
          final ref = FirebaseFirestore.instance
              .collection('notifications')
              .doc();
          
          batch.set(ref, {
            'title': title,
            'body': body,
            'type': type ?? 'general',
            'userId': userId,
            'data': data ?? {},
            'sentAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
        
        await batch.commit();
        debugPrint('✅ Sent batch ${i ~/ batchSize + 1} to ${chunk.length} users');
      }
      
      debugPrint('✅ Bulk notification sent to ${userIds.length} users total');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending bulk notification: $e');
      return false;
    }
  }

  // Send notification to all active students
  static Future<bool> sendToAllStudents({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final students = await FirebaseFirestore.instance
          .collection('students')
          .get();
      
      if (students.docs.isEmpty) {
        debugPrint('No students found');
        return false;
      }
      
      final studentIds = students.docs.map((doc) => doc.id).toList();
      debugPrint('Found ${studentIds.length} students');
      
      return await sendBulkNotification(
        title: title,
        body: body,
        userIds: studentIds,
        type: type,
        data: data,
      );
    } catch (e) {
      debugPrint('❌ Error sending to all students: $e');
      return false;
    }
  }

  // Send notification to all admins and staff
  static Future<bool> sendToAllStaff({
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final staff = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'messStaff'])
          .get();
      
      if (staff.docs.isEmpty) {
        debugPrint('No staff found');
        return false;
      }
      
      final staffIds = staff.docs.map((doc) => doc.id).toList();
      debugPrint('Found ${staffIds.length} staff members');
      
      return await sendBulkNotification(
        title: title,
        body: body,
        userIds: staffIds,
        type: type,
        data: data,
      );
    } catch (e) {
      debugPrint('❌ Error sending to all staff: $e');
      return false;
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read for a user
  static Future<void> markAllAsRead(String userId) async {
    try {
      final unread = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      if (unread.docs.isEmpty) return;
      
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      
      for (var doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
      debugPrint('✅ Marked ${unread.docs.length} notifications as read');
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  // Get notifications for a user (without index requirement)
  static Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs.map((doc) {
            return {...doc.data(), 'id': doc.id};
          }).toList();
          
          // Sort in memory
          notifications.sort((a, b) {
            final aTime = a['sentAt'] as Timestamp?;
            final bTime = b['sentAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.toDate().compareTo(aTime.toDate());
          });
          
          return notifications;
        });
  }

  // Get unread count for user
  static Stream<int> getUnreadCount(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Delete old notifications (cleanup)
  static Future<void> deleteOldNotifications({int daysOld = 30}) async {
    try {
      DateTime cutoff = DateTime.now().subtract(Duration(days: daysOld));
      
      final oldNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('sentAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();
      
      if (oldNotifications.docs.isEmpty) return;
      
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      
      for (var doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('Deleted ${oldNotifications.docs.length} old notifications');
    } catch (e) {
      debugPrint('Error deleting old notifications: $e');
    }
  }

  // Delete notification by ID
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
      debugPrint('✅ Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  // Delete all notifications for a user
  static Future<void> deleteAllNotifications(String userId) async {
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      
      if (notifications.docs.isEmpty) return;
      
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('✅ Deleted ${notifications.docs.length} notifications for user');
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
    }
  }

  // Notification handlers
  static void _onMessage(RemoteMessage message) {
    debugPrint('Received message: ${message.messageId}');
    _showLocalNotification(message);
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.messageId}');
    // Navigate to relevant screen based on message data
  }

  @pragma('vm:entry-point')
  static Future<void> _onBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background message: ${message.messageId}');
    _showLocalNotification(message);
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle navigation
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = 
        AndroidNotificationDetails(
      'hostel_channel',
      'Hostel Notifications',
      channelDescription: 'Notifications from Hostel Management System',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const DarwinNotificationDetails iosDetails = 
        DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title ?? 'Hostel Notification',
      body: message.notification?.body ?? 'You have a new notification',
      notificationDetails: platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  // Schedule notification
  static Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = 
        AndroidNotificationDetails(
      'hostel_channel',
      'Hostel Notifications',
      channelDescription: 'Notifications from Hostel Management System',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = 
        DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
      scheduledTime,
      tz.local,
    );

    await _localNotifications.zonedSchedule(
      id: scheduledTime.hashCode,
      title: title,
      body: body,
      scheduledDate: tzScheduledTime,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  // Cancel notification
  static Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id: id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}