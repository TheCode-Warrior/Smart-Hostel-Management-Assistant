import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/attendance_model.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get hostel location from settings
  static Future<Map<String, dynamic>> getHostelLocation() async {
    try {
      final settingsDoc = await _firestore
          .collection('hostelSettings')
          .doc('settings')
          .get();
      
      if (settingsDoc.exists) {
        final data = settingsDoc.data() as Map<String, dynamic>;
        final location = data['location'];
        if (location is GeoPoint) {
          return {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'radius': (data['attendanceRadius'] as num?)?.toDouble() ?? 500.0,
          };
        }
      }
      return {'latitude': 0.0, 'longitude': 0.0, 'radius': 500.0};
    } catch (e) {
      debugPrint('Error getting hostel location: $e');
      return {'latitude': 0.0, 'longitude': 0.0, 'radius': 500.0};
    }
  }

  // Check if within geofence
  static Future<bool> isWithinGeofence(Position position) async {
    try {
      final hostelLocation = await getHostelLocation();
      if (hostelLocation['latitude'] == 0.0) return true;
      
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        hostelLocation['latitude'],
        hostelLocation['longitude'],
      );
      
      debugPrint('Distance from hostel: ${distance.toStringAsFixed(2)} meters');
      debugPrint('Allowed radius: ${hostelLocation['radius']} meters');
      
      return distance <= hostelLocation['radius'];
    } catch (e) {
      debugPrint('Error checking geofence: $e');
      return true;
    }
  }

  // Get distance from hostel
  static Future<double> getDistanceFromHostel(Position position) async {
    try {
      final hostelLocation = await getHostelLocation();
      if (hostelLocation['latitude'] == 0.0) return 0.0;
      
      return Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        hostelLocation['latitude'],
        hostelLocation['longitude'],
      );
    } catch (e) {
      return 0.0;
    }
  }

  // Mark check-in
  static Future<Map<String, dynamic>> markCheckIn({
    required String studentId,
    required Position location,
    required String method,
    String? qrCode,
  }) async {
    try {
      // Check if already checked in today
      bool alreadyCheckedIn = await _isAlreadyCheckedIn(studentId);
      if (alreadyCheckedIn) {
        return {
          'success': false,
          'message': 'Already checked in today',
        };
      }

      // Check if within geofence
      bool withinGeofence = await isWithinGeofence(location);
      if (!withinGeofence && method == 'gps') {
        final distance = await getDistanceFromHostel(location);
        return {
          'success': false,
          'message': 'You are ${distance.toStringAsFixed(0)} meters outside the hostel premises.\nPlease move closer to the hostel.',
        };
      }

      // Get address
      String address = await _getAddressFromLatLng(location);
      
      // Check if late
      bool isLate = await _isLateCheckIn();
      
      // Create attendance record
      AttendanceModel attendance = AttendanceModel(
        studentId: studentId,
        date: Timestamp.now(),
        checkInTime: Timestamp.now(),
        checkInLocation: GeoPoint(location.latitude, location.longitude),
        checkInAddress: address,
        checkInMethod: method,
        qrCodeUsed: qrCode,
        status: isLate ? AttendanceStatus.late : AttendanceStatus.present,
      );

      String id = await FirestoreService.createDocument(
        collection: 'attendance',
        data: attendance.toMap(),
      );

      // Send notification
      await NotificationService.sendNotification(
        title: isLate ? '⚠️ Late Check-in' : '✅ Check-in Successful',
        body: 'You checked in at ${DateFormat('hh:mm a').format(DateTime.now())}${isLate ? ' (Late)' : ''}',
        userId: studentId,
        type: 'attendance',
        data: {'attendanceId': id, 'status': isLate ? 'late' : 'present', 'method': method},
      );

      // Generate meal tokens after check-in
      try {
        await _generateMealTokens(studentId);
      } catch (e) {
        debugPrint('Error generating meal tokens: $e');
      }

      return {
        'success': true,
        'message': isLate ? 'Check-in successful (Late Entry)' : 'Check-in successful',
        'attendanceId': id,
        'isLate': isLate,
        'time': DateFormat('hh:mm a').format(DateTime.now()),
        'address': address,
        'distance': await getDistanceFromHostel(location),
      };
    } catch (e) {
      debugPrint('Error marking check-in: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Generate meal tokens after check-in
  static Future<void> _generateMealTokens(String studentId) async {
    try {
      final now = DateTime.now();
      final todayDate = DateFormat('yyyy-MM-dd').format(now);
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // Get student data
      final studentDoc = await _firestore.collection('students').doc(studentId).get();
      if (!studentDoc.exists) return;
      
      final studentData = studentDoc.data() as Map<String, dynamic>;
      
      // Check if mess fee is paid
      final monthlyFees = Map<String, bool>.from(studentData['messMonthlyFees'] ?? {});
      if (monthlyFees[currentMonth] != true) return;
      
      // Get active meal types
      final settingsDoc = await _firestore.collection('hostelSettings').doc('settings').get();
      final settings = settingsDoc.data() as Map<String, dynamic>? ?? {};
      final activeMealsRaw = settings['messActiveMealTypes'];
      final activeMeals = activeMealsRaw is List
          ? activeMealsRaw.map((e) => e.toString().toLowerCase()).toList()
          : ['breakfast', 'lunch', 'dinner'];
      
      // Generate tokens for each active meal
      for (final mealKey in activeMeals) {
        final mealCycle = '$todayDate-$mealKey';
        
        // Check if token already exists
        final existing = await _firestore
            .collection('messTokens')
            .where('studentId', isEqualTo: studentId)
            .where('mealCycle', isEqualTo: mealCycle)
            .limit(1)
            .get();
        
        if (existing.docs.isNotEmpty) continue;
        
        // Get meal timings
        final messTimings = settings['messTimings'] ?? {};
        final mealTime = messTimings[mealKey] ?? {};
        
        final validFrom = _getMealStartTime(now, mealKey, mealTime);
        final validUntil = _getMealEndTime(now, mealKey, mealTime);
        
        // Create token
        final tokenId = _generateTokenId();
        final qrData = _generateQRData(
          tokenId: tokenId,
          studentId: studentId,
          mealType: mealKey,
          date: todayDate,
          validFrom: validFrom,
          validUntil: validUntil,
        );
        
        final encryptedData = _encryptQRData(qrData);
        
        await _firestore.collection('messTokens').doc(tokenId).set({
          'studentId': studentId,
          'studentName': studentData['fullName'] ?? 'Unknown',
          'tokenCode': tokenId,
          'mealType': mealKey,
          'mealDate': Timestamp.fromDate(now),
          'validFrom': Timestamp.fromDate(validFrom),
          'validUntil': Timestamp.fromDate(validUntil),
          'isUsed': false,
          'qrData': encryptedData,
          'generatedBy': 'attendance',
          'status': 'active',
          'mealCycle': mealCycle,
        });
      }
    } catch (e) {
      debugPrint('Error generating meal tokens: $e');
    }
  }

  // Mark check-out
  static Future<Map<String, dynamic>> markCheckOut(String studentId) async {
    try {
      // Get today's attendance record
      final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final records = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();
      
      if (records.docs.isEmpty) {
        return {
          'success': false,
          'message': 'No check-in record found for today',
        };
      }

      final record = records.docs.first;
      final recordData = record.data();
      
      if (recordData['checkOutTime'] != null) {
        return {
          'success': false,
          'message': 'Already checked out today',
        };
      }

      // Get current location
      Position position = await _getCurrentPosition();
      
      // Calculate working hours
      final checkInTime = (recordData['checkInTime'] as Timestamp).toDate();
      final workingHours = DateTime.now().difference(checkInTime).inMinutes / 60.0;

      // Update record
      await record.reference.update({
        'checkOutTime': FieldValue.serverTimestamp(),
        'checkOutLocation': GeoPoint(position.latitude, position.longitude),
        'checkOutAddress': await _getAddressFromLatLng(position),
        'checkOutMethod': 'gps',
        'workingHours': workingHours,
      });

      // Send notification
      await NotificationService.sendNotification(
        title: '👋 Check-out Recorded',
        body: 'You checked out at ${DateFormat('hh:mm a').format(DateTime.now())}. Worked for ${workingHours.toStringAsFixed(1)} hours.',
        userId: studentId,
        type: 'attendance',
        data: {'attendanceId': record.id, 'status': 'checked_out'},
      );

      return {
        'success': true,
        'message': 'Check-out successful',
        'workingHours': workingHours,
        'time': DateFormat('hh:mm a').format(DateTime.now()),
      };
    } catch (e) {
      debugPrint('Error marking check-out: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Check if late check-in
  static Future<bool> _isLateCheckIn() async {
    try {
      final settingsDoc = await _firestore
          .collection('hostelSettings')
          .doc('settings')
          .get();
      
      final settings = settingsDoc.data() as Map<String, dynamic>? ?? {};
      final lateTimeStr = settings['lateEntryTime'] ?? '09:30';
      
      final now = DateTime.now();
      final lateTimeParts = lateTimeStr.split(':');
      final lateTime = DateTime(now.year, now.month, now.day, 
          int.parse(lateTimeParts[0]), int.parse(lateTimeParts[1]));
      
      return now.isAfter(lateTime);
    } catch (e) {
      return false;
    }
  }

  // Get attendance history
  static Future<List<AttendanceModel>> getStudentAttendance(
    String studentId, {
    int days = 30,
  }) async {
    try {
      DateTime startDate = DateTime.now().subtract(Duration(days: days));
      
      var records = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final history = records.docs
          .map((doc) => AttendanceModel.fromMap(doc.data(), doc.id))
          .toList();

      history.sort((a, b) {
        final aDate = a.date?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.date?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return history;
    } catch (e) {
      debugPrint('Error getting attendance history: $e');
      return [];
    }
  }

  // Get today's attendance
  static Future<Map<String, dynamic>> getTodayAttendance(String studentId) async {
    try {
      final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      var records = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (records.docs.isEmpty) {
        return {
          'checkedIn': false,
          'checkedOut': false,
          'record': null,
        };
      }

      var record = records.docs.first;
      var data = record.data();
      return {
        'checkedIn': true,
        'checkedOut': data['checkOutTime'] != null,
        'checkInTime': data['checkInTime'],
        'checkOutTime': data['checkOutTime'],
        'record': AttendanceModel.fromMap(data, record.id),
      };
    } catch (e) {
      debugPrint('Error getting today attendance: $e');
      return {
        'checkedIn': false,
        'checkedOut': false,
        'error': e.toString(),
      };
    }
  }

  // Get attendance statistics
  static Future<Map<String, dynamic>> getAttendanceStats(
    String studentId, {
    int months = 1,
  }) async {
    try {
      DateTime startDate = DateTime.now().subtract(Duration(days: 30 * months));
      
      var records = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();
      
      var recordsList = records.docs.map((doc) => doc.data()).toList();

      int totalDays = recordsList.length;
      int presentDays = 0;
      int absentDays = 0;
      int lateDays = 0;
      int halfDays = 0;

      for (var record in recordsList) {
        String status = record['status']?.toString().toLowerCase() ?? 'absent';
        if (status == 'present') {
          presentDays++;
        } else if (status == 'absent') {
          absentDays++;
        } else if (status == 'late') {
          lateDays++;
          presentDays++;
        } else if (status == 'half-day' || status == 'halfday') {
          halfDays++;
          presentDays++;
        }
      }

      double attendancePercentage = totalDays > 0
          ? (presentDays / totalDays) * 100
          : 0.0;

      return {
        'totalDays': totalDays,
        'presentDays': presentDays,
        'absentDays': absentDays,
        'lateDays': lateDays,
        'halfDays': halfDays,
        'attendancePercentage': attendancePercentage,
        'records': recordsList,
      };
    } catch (e) {
      debugPrint('Error getting attendance stats: $e');
      return {
        'totalDays': 0,
        'presentDays': 0,
        'absentDays': 0,
        'lateDays': 0,
        'halfDays': 0,
        'attendancePercentage': 0.0,
        'records': [],
      };
    }
  }

  // Generate QR for attendance
  static String generateAttendanceQR(String studentId) {
    Map<String, dynamic> data = {
      'studentId': studentId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'attendance',
      'hash': _generateHash('$studentId${DateTime.now().millisecondsSinceEpoch}'),
    };
    return jsonEncode(data);
  }

  // Private helper methods
  static Future<bool> _isAlreadyCheckedIn(String studentId) async {
    final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    var records = await _firestore
        .collection('attendance')
        .where('studentId', isEqualTo: studentId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (records.docs.isEmpty) return false;
    var recordData = records.docs.first.data();
    return recordData['checkOutTime'] == null;
  }

  static Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<String> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return '${place.name}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
    return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
  }

  static DateTime _getMealStartTime(DateTime now, String mealType, Map<String, dynamic> mealTime) {
    String startTimeStr = mealTime['start'] ?? _getDefaultStartTime(mealType);
    List<String> parts = startTimeStr.split(':');
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static DateTime _getMealEndTime(DateTime now, String mealType, Map<String, dynamic> mealTime) {
    String endTimeStr = mealTime['end'] ?? _getDefaultEndTime(mealType);
    List<String> parts = endTimeStr.split(':');
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  static String _getDefaultStartTime(String mealType) {
    switch (mealType) {
      case 'breakfast': return '07:00';
      case 'lunch': return '12:00';
      case 'dinner': return '19:00';
      default: return '12:00';
    }
  }

  static String _getDefaultEndTime(String mealType) {
    switch (mealType) {
      case 'breakfast': return '09:00';
      case 'lunch': return '14:00';
      case 'dinner': return '21:00';
      default: return '14:00';
    }
  }

  static String _generateTokenId() {
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String random = DateTime.now().microsecond.toString().substring(0, 4);
    return 'TKN${timestamp.substring(timestamp.length - 8)}$random';
  }

  static String _generateQRData({
    required String tokenId,
    required String studentId,
    required String mealType,
    required String date,
    required DateTime validFrom,
    required DateTime validUntil,
  }) {
    Map<String, dynamic> data = {
      'tokenId': tokenId,
      'studentId': studentId,
      'mealType': mealType,
      'date': date,
      'validFrom': validFrom.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'hash': _generateHash('$tokenId$studentId$date'),
    };
    return jsonEncode(data);
  }

  static String _generateHash(String input) {
    var bytes = utf8.encode(input);
    var digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  static String _encryptQRData(String data) {
    return base64.encode(utf8.encode(data));
  }
}