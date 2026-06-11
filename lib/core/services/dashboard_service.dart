import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get unified dashboard data for student
  static Future<Map<String, dynamic>> getStudentDashboardData(String studentId) async {
    try {
      final now = DateTime.now();
      final todayDate = DateFormat('yyyy-MM-dd').format(now);
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // Fetch all required data in parallel
      final results = await Future.wait([
        _getTodayAttendance(studentId),
        _getTodayMealStatus(studentId),
        _getUpcomingMeals(studentId),
        _getStudentFeeStatus(studentId, currentMonth),
        _getActiveComplaintsCount(studentId),
        _getTodayMenu(),
        _getAttendanceStats(studentId),
      ]);

      // ✅ Cast each result to proper type
      final attendanceData = results[0] as Map<String, dynamic>;
      final mealStatusData = results[1] as Map<String, dynamic>;
      final upcomingMealsData = results[2] as List<Map<String, dynamic>>;
      final feeStatusData = results[3] as Map<String, dynamic>;
      final activeComplaintsData = results[4] as int;
      final todayMenuData = results[5] as Map<String, dynamic>;
      final attendanceStatsData = results[6] as Map<String, dynamic>;

      return {
        'attendance': attendanceData,
        'mealStatus': mealStatusData,
        'upcomingMeals': upcomingMealsData,
        'feeStatus': feeStatusData,
        'activeComplaints': activeComplaintsData,
        'todayMenu': todayMenuData,
        'attendancePercentage': attendanceStatsData['attendancePercentage'] ?? 0.0,
        'currentTime': DateFormat('hh:mm a').format(now),
        'currentDate': DateFormat('EEEE, dd MMM yyyy').format(now),
      };
    } catch (e) {
      debugPrint('Error getting student dashboard data: $e');
      return {};
    }
  }

  // ✅ NEW: Get attendance stats for percentage
  static Future<Map<String, dynamic>> _getAttendanceStats(String studentId) async {
    try {
      final startDate = DateTime.now().subtract(const Duration(days: 30));
      
      final records = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      int totalDays = records.docs.length;
      int presentDays = 0;

      for (var doc in records.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase() ?? 'absent';
        if (status == 'present' || status == 'late' || status == 'half-day') {
          presentDays++;
        }
      }

      double percentage = totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;

      return {
        'totalDays': totalDays,
        'presentDays': presentDays,
        'attendancePercentage': percentage,
      };
    } catch (e) {
      debugPrint('Error getting attendance stats: $e');
      return {
        'totalDays': 0,
        'presentDays': 0,
        'attendancePercentage': 0.0,
      };
    }
  }

  static Future<Map<String, dynamic>> getMessStaffDashboardData() async {
    try {
      final now = DateTime.now();
      final todayDate = DateFormat('yyyy-MM-dd').format(now);

      final results = await Future.wait([
        _getTodayMealConsumptionStats(todayDate),
        _getActiveMealTimings(),
        _getTodayMenu(),
        _getRecentScans(),
      ]);

      return {
        'mealConsumption': results[0] as Map<String, dynamic>? ?? {'breakfast': 0, 'lunch': 0, 'dinner': 0},
        'activeMealTimings': results[1] as Map<String, dynamic>? ?? {},
        'todayMenu': results[2] as Map<String, dynamic>?,
        'recentScans': results[3] as List<Map<String, dynamic>>? ?? [],
        'currentTime': DateFormat('hh:mm a').format(now),
        'currentDate': DateFormat('EEEE, dd MMM yyyy').format(now),
      };
    } catch (e) {
      debugPrint('Error getting mess staff dashboard data: $e');
      return {
        'mealConsumption': {'breakfast': 0, 'lunch': 0, 'dinner': 0},
        'activeMealTimings': {},
        'todayMenu': null,
        'recentScans': [],
        'currentTime': DateFormat('hh:mm a').format(DateTime.now()),
        'currentDate': DateFormat('EEEE, dd MMM yyyy').format(DateTime.now()),
      };
    }
  }

  static Future<Map<String, dynamic>> _getActiveMealTimings() async {
    try {
      final now = DateTime.now();
      final settings = await _firestore.collection('hostelSettings').doc('settings').get();
      final messTimings = settings.data()?['messTimings'] ?? {};
      final activeMeals = settings.data()?['messActiveMealTypes'] ?? ['breakfast', 'lunch', 'dinner'];

      Map<String, dynamic> activeTimings = {};

      for (var meal in activeMeals) {
        final timing = messTimings[meal] ?? {};
        final startStr = timing['start']?.toString() ?? '00:00';
        final endStr = timing['end']?.toString() ?? '00:00';

        final startParts = startStr.split(':');
        final endParts = endStr.split(':');

        final startTime = DateTime(now.year, now.month, now.day,
            int.parse(startParts[0]), int.parse(startParts[1]));
        final endTime = DateTime(now.year, now.month, now.day,
            int.parse(endParts[0]), int.parse(endParts[1]));

        activeTimings[meal] = {
          'start': startStr,
          'end': endStr,
          'isActive': now.isAfter(startTime) && now.isBefore(endTime),
        };
      }

      return activeTimings;
    } catch (e) {
      debugPrint('Error getting active meal timings: $e');
      return {};
    }
  }

  // Get unified dashboard data for admin
  static Future<Map<String, dynamic>> getAdminDashboardData() async {
    try {
      final now = DateTime.now();
      final todayDate = DateFormat('yyyy-MM-dd').format(now);

      final results = await Future.wait([
        _getTodayAttendanceStats(),
        _getTodayMealConsumptionStats(todayDate),
        _getPendingComplaintsCount(),
        _getPendingFeeRequestsCount(),
        _getAvailableRoomsCount(),
        _getTodayMenu(),
        _getRecentActivities(),
      ]);

      return {
        'attendanceStats': results[0] as Map<String, dynamic>? ?? {},
        'mealConsumption': results[1] as Map<String, dynamic>? ?? {},
        'pendingComplaints': results[2] as int? ?? 0,
        'pendingFeeRequests': results[3] as int? ?? 0,
        'availableRooms': results[4] as int? ?? 0,
        'todayMenu': results[5] as Map<String, dynamic>?,
        'recentActivities': results[6] as List<Map<String, dynamic>>? ?? [],
        'currentTime': DateFormat('hh:mm a').format(now),
        'currentDate': DateFormat('EEEE, dd MMM yyyy').format(now),
      };
    } catch (e) {
      debugPrint('Error getting admin dashboard data: $e');
      return {};
    }
  }

  // Private helper methods
  static Future<Map<String, dynamic>> _getTodayAttendance(String studentId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final record = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (record.docs.isEmpty) {
        return {
          'checkedIn': false,
          'checkedOut': false,
          'checkInTime': null,
          'checkOutTime': null,
        };
      }

      final data = record.docs.first.data();
      return {
        'checkedIn': data['checkInTime'] != null,
        'checkedOut': data['checkOutTime'] != null,
        'checkInTime': data['checkInTime'] != null
            ? DateFormat('hh:mm a').format((data['checkInTime'] as Timestamp).toDate())
            : null,
        'checkOutTime': data['checkOutTime'] != null
            ? DateFormat('hh:mm a').format((data['checkOutTime'] as Timestamp).toDate())
            : null,
      };
    } catch (e) {
      return {'checkedIn': false, 'checkedOut': false};
    }
  }

  static Future<Map<String, dynamic>> _getTodayMealStatus(String studentId) async {
    try {
      final today = DateTime.now();
      final todayDate = DateFormat('yyyy-MM-dd').format(today);

      final tokens = await _firestore
          .collection('messTokens')
          .where('studentId', isEqualTo: studentId)
          .where('mealCycle', isGreaterThanOrEqualTo: '$todayDate-')
          .get();

      Map<String, dynamic> meals = {
        'breakfast': {'taken': false, 'valid': false, 'time': '7:00-9:00 AM'},
        'lunch': {'taken': false, 'valid': false, 'time': '12:00-2:00 PM'},
        'dinner': {'taken': false, 'valid': false, 'time': '7:00-9:00 PM'},
      };

      for (var doc in tokens.docs) {
        final token = doc.data();
        final mealType = token['mealType']?.toString().toLowerCase();
        if (mealType != null && meals.containsKey(mealType)) {
          meals[mealType]['taken'] = token['isUsed'] == true;
          meals[mealType]['valid'] = token['status'] == 'active' && token['isUsed'] != true;
          if (token['validUntil'] != null) {
            meals[mealType]['validUntil'] = DateFormat('hh:mm a').format((token['validUntil'] as Timestamp).toDate());
          }
        }
      }

      return meals;
    } catch (e) {
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> _getUpcomingMeals(String studentId) async {
    try {
      final now = DateTime.now();
      final settings = await _firestore.collection('hostelSettings').doc('settings').get();
      final messTimings = settings.data()?['messTimings'] ?? {};
      final activeMeals = settings.data()?['messActiveMealTypes'] ?? ['breakfast', 'lunch', 'dinner'];

      final mealOrder = ['breakfast', 'lunch', 'dinner'];
      final mealNames = {'breakfast': 'Breakfast', 'lunch': 'Lunch', 'dinner': 'Dinner'};
      final mealIcons = {'breakfast': Icons.free_breakfast, 'lunch': Icons.lunch_dining, 'dinner': Icons.dinner_dining};

      List<Map<String, dynamic>> upcoming = [];

      for (var meal in mealOrder) {
        if (!activeMeals.contains(meal)) continue;

        final timing = messTimings[meal] ?? {};
        final startStr = timing['start'] ?? '00:00';
        final endStr = timing['end'] ?? '00:00';

        final startParts = startStr.split(':');
        final endParts = endStr.split(':');

        final startTime = DateTime(now.year, now.month, now.day,
            int.parse(startParts[0]), int.parse(startParts[1]));
        final endTime = DateTime(now.year, now.month, now.day,
            int.parse(endParts[0]), int.parse(endParts[1]));

        if (now.isBefore(startTime)) {
          final diff = startTime.difference(now);
          upcoming.add({
            'type': meal,
            'name': mealNames[meal],
            'icon': mealIcons[meal],
            'status': 'upcoming',
            'timeRemaining': _formatDuration(diff),
            'startTime': startStr,
          });
        } else if (now.isBefore(endTime)) {
          final diff = endTime.difference(now);
          upcoming.add({
            'type': meal,
            'name': mealNames[meal],
            'icon': mealIcons[meal],
            'status': 'active',
            'timeRemaining': _formatDuration(diff),
            'endTime': endStr,
          });
        }
      }

      return upcoming;
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> _getStudentFeeStatus(String studentId, String currentMonth) async {
    try {
      final student = await _firestore.collection('students').doc(studentId).get();
      if (!student.exists) return {'hasPending': false, 'status': 'No fee record'};

      final data = student.data() as Map<String, dynamic>;
      final messMonthlyFees = Map<String, bool>.from(data['messMonthlyFees'] ?? {});
      final isPaid = messMonthlyFees[currentMonth] ?? false;

      return {
        'hasPending': !isPaid && data['messMonthlyFeeSelected'] == true,
        'status': isPaid ? 'Paid' : (data['messMonthlyFeeSelected'] == true ? 'Pending' : 'Not Selected'),
        'currentMonth': currentMonth,
      };
    } catch (e) {
      return {'hasPending': false, 'status': 'Error'};
    }
  }

  static Future<int> _getActiveComplaintsCount(String studentId) async {
    try {
      final complaints = await _firestore
          .collection('complaints')
          .where('studentId', isEqualTo: studentId)
          .where('status', whereIn: ['pending', 'assigned'])
          .get();
      return complaints.docs.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<Map<String, dynamic>> _getTodayMenu() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final menu = await _firestore.collection('messMenuDaily').doc(today).get();

      if (menu.exists) {
        final data = menu.data() as Map<String, dynamic>;
        return {
          'breakfast': List<String>.from(data['breakfast']?['items'] ?? data['breakfast'] ?? []),
          'lunch': List<String>.from(data['lunch']?['items'] ?? data['lunch'] ?? []),
          'dinner': List<String>.from(data['dinner']?['items'] ?? data['dinner'] ?? []),
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> _getTodayAttendanceStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = Timestamp.fromDate(DateTime(today.year, today.month, today.day));
      final endOfDay = Timestamp.fromDate(startOfDay.toDate().add(const Duration(days: 1)));

      final attendance = await _firestore
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: endOfDay)
          .get();

      int checkedIn = attendance.docs.where((d) => d.data()['checkInTime'] != null).length;
      int checkedOut = attendance.docs.where((d) => d.data()['checkOutTime'] != null).length;

      return {
        'total': attendance.docs.length,
        'checkedIn': checkedIn,
        'checkedOut': checkedOut,
      };
    } catch (e) {
      return {'total': 0, 'checkedIn': 0, 'checkedOut': 0};
    }
  }

  static Future<Map<String, dynamic>> _getTodayMealConsumptionStats(String todayDate) async {
    try {
      final consumption = await _firestore
          .collection('mealConsumption')
          .where('date', isEqualTo: todayDate)
          .get();

      int breakfast = 0, lunch = 0, dinner = 0;

      for (var doc in consumption.docs) {
        final meals = doc.data()['meals'] as List? ?? [];
        for (var meal in meals) {
          final type = meal['type']?.toString().toLowerCase();
          if (type == 'breakfast') breakfast++;
          if (type == 'lunch') lunch++;
          if (type == 'dinner') dinner++;
        }
      }

      return {'breakfast': breakfast, 'lunch': lunch, 'dinner': dinner};
    } catch (e) {
      return {'breakfast': 0, 'lunch': 0, 'dinner': 0};
    }
  }

  static Future<int> _getPendingComplaintsCount() async {
    try {
      final complaints = await _firestore
          .collection('complaints')
          .where('status', isEqualTo: 'pending')
          .get();
      return complaints.docs.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> _getPendingFeeRequestsCount() async {
    try {
      final requests = await _firestore
          .collection('feeRequests')
          .where('status', isEqualTo: 'pending')
          .get();
      return requests.docs.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> _getAvailableRoomsCount() async {
    try {
      final rooms = await _firestore
          .collection('rooms')
          .where('isAvailable', isEqualTo: true)
          .get();
      return rooms.docs.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> _getRecentActivities() async {
    try {
      final complaints = await _firestore
          .collection('complaints')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      List<Map<String, dynamic>> activities = [];

      for (var doc in complaints.docs) {
        final data = doc.data();
        activities.add({
          'type': 'complaint',
          'title': data['title'],
          'status': data['status'],
          'time': (data['createdAt'] as Timestamp).toDate(),
          'studentName': data['studentName'],
        });
      }

      return activities;
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getRecentScans() async {
    try {
      final scans = await _firestore
          .collection('mealRecords')
          .orderBy('scannedAt', descending: true)
          .limit(5)
          .get();

      return scans.docs.map((doc) {
        final data = doc.data();
        return {
          'studentName': data['studentName'],
          'mealType': data['mealType'],
          'time': data['scannedAt'] != null
              ? DateFormat('hh:mm a').format((data['scannedAt'] as Timestamp).toDate())
              : 'Unknown',
          'counter': data['messCounter'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}