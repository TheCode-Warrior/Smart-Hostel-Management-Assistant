// import 'dart:convert';
// import 'dart:math';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
// import 'package:crypto/crypto.dart';
// import '../models/mess_token_model.dart';
// import '../models/student_model.dart';
// import 'mess_menu_service.dart';
// import 'firestore_service.dart';
// import 'package:intl/intl.dart';

// class MessService {
//   static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   static bool _isMessRecordSelected(Map<String, dynamic> studentData) {
//     return studentData['messMonthlyFeeSelected'] == true ||
//         studentData['feePlan']?.toString() == 'messMonthly' ||
//         studentData['feePlan']?.toString() == 'hostelSemester+messMonthly';
//   }

//   static bool _isMessFeePaidForMonth(Map<String, dynamic> studentData, String currentMonth) {
//     final messMonthlyFees = Map<String, bool>.from(studentData['messMonthlyFees'] ?? {});
//     return messMonthlyFees[currentMonth] ?? false;
//   }
  
//   // Auto-detect current meal time and generate tokens
//   static Future<void> generateTokensForCurrentMealTime() async {
//     try {
//       final settingsDoc = await _firestore
//           .collection('hostelSettings')
//           .doc('settings')
//           .get();

//       final Map<String, dynamic> settings = settingsDoc.exists
//           ? Map<String, dynamic>.from(settingsDoc.data() as Map)
//           : <String, dynamic>{};
      
//       final currentMeal = _getCurrentMealType(settings);

//       if (currentMeal == null) {
//         debugPrint('No active meal time right now');
//         return;
//       }

//       debugPrint('Current meal detected: $currentMeal');
//       await _generateMealTokensForType(currentMeal);
//     } catch (e) {
//       debugPrint('Error generating tokens for current meal time: $e');
//       rethrow;
//     }
//   }

//   // Generate mess tokens for all students for a specific meal (internal)
//   static Future<void> _generateMealTokensForType(MealType mealType) async {

//     try {
//       DateTime now = DateTime.now();
//       String todayDate = DateFormat('yyyy-MM-dd').format(now);
//       String mealCycle = '$todayDate-${mealType.toString().split('.').last}';
      
//       // Get current month for fee checking
//       String currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
//       // Backfill mode: do not stop if some tokens already exist.
//       // We will generate only for students who do not yet have a token for this mealCycle.
      
//       // Get all active students from Firestore
//       var allStudents = await FirestoreService.queryDocuments(
//         collection: 'students',
//       );
      
//       // Filter students who have paid fees for current month
//       var students = allStudents.where((student) {
//         return _isMessRecordSelected(student) && _isMessFeePaidForMonth(student, currentMonth);
//       }).toList();
      
//       // Get meal timings from settings
//       DocumentSnapshot settingsDoc = await _firestore
//           .collection('hostelSettings')
//           .doc('settings')
//           .get();

//         Map<String, dynamic> settings = settingsDoc.exists
//           ? Map<String, dynamic>.from(settingsDoc.data() as Map)
//           : <String, dynamic>{};
//       final activeMealTypes = _getActiveMealTypes(settings);
//       if (!activeMealTypes.contains(mealType.toString().split('.').last)) {
//         debugPrint('Skipping $mealType because it is disabled in hostelSettings/settings');
//         return;
//       }
//       Map<String, dynamic> messTimings = settings['messTimings'] ?? {};
      
//       // Get meal timings
//       Map<String, dynamic> mealTime = messTimings[mealType.toString().split('.').last] ?? {};
      
//       DateTime validFrom = _getMealStartTime(now, mealType, mealTime);
//       DateTime validUntil = _getMealEndTime(now, mealType, mealTime);
      
//       int generatedCount = 0;

//       // Generate token for each student (only if missing)
//       for (var student in students) {
//         final String studentUserId =
//             (student['userId'] ?? student['id'] ?? '').toString();
//         if (studentUserId.isEmpty) {
//           continue;
//         }

//         if (!await _isStudentSubscribedForMeal(studentUserId, currentMonth, mealType)) {
//           continue;
//         }

//         final existingForStudent = await _firestore
//             .collection('messTokens')
//             .where('studentId', isEqualTo: studentUserId)
//             .where('mealCycle', isEqualTo: mealCycle)
//             .limit(1)
//             .get();

//         if (existingForStudent.docs.isNotEmpty) {
//           continue;
//         }

//         String tokenId = _generateTokenId();
//         String qrData = _generateQRData(
//           tokenId: tokenId,
//           studentId: studentUserId,
//           mealType: mealType,
//           date: todayDate,
//           validFrom: validFrom,
//           validUntil: validUntil,
//         );
        
//         String encryptedData = _encryptQRData(qrData);
        
//         MessTokenModel token = MessTokenModel(
//           id: tokenId,
//           studentId: studentUserId,
//           studentName: student['studentName'] ?? 'Unknown',
//           tokenCode: tokenId,
//           mealType: mealType,
//           mealDate: Timestamp.fromDate(now),
//           validFrom: Timestamp.fromDate(validFrom),
//           validUntil: Timestamp.fromDate(validUntil),
//           isUsed: false,
//           qrData: encryptedData,
//           generatedBy: 'system',
//           status: TokenStatus.active,
//           mealCycle: mealCycle,
//         );
        
//         await _firestore.collection('messTokens').doc(tokenId).set(token.toMap());
//         generatedCount++;
//       }
      
//       debugPrint('Generated $generatedCount new tokens for $mealCycle (eligible students: ${students.length})');
//     } catch (e) {
//       debugPrint('Error generating meal tokens: $e');
//       rethrow;
//     }
//   }

//   // Generate today's meal tokens for a single student after successful attendance check-in
//   static Future<void> generateDailyTokensForStudent(String studentId) async {
//     try {
//       final studentDoc = await _firestore.collection('students').doc(studentId).get();
//       Map<String, dynamic> studentData = {};

//       if (studentDoc.exists) {
//         studentData = studentDoc.data() as Map<String, dynamic>;
//       } else {
//         final userDoc = await _firestore.collection('users').doc(studentId).get();
//         if (!userDoc.exists) {
//           debugPrint('Student/user record not found for token generation: $studentId');
//           return;
//         }
//         studentData = userDoc.data() as Map<String, dynamic>;
//       }

//       DateTime now = DateTime.now();
//       String currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
//       // Check if student has paid fees for current month
//       if (!_isMessRecordSelected(studentData)) {
//         debugPrint('Skipping token generation: mess record not selected for $studentId');
//         return;
//       }

//       if (!_isMessFeePaidForMonth(studentData, currentMonth)) {
//         debugPrint('Skipping token generation: mess fee not paid for $studentId in $currentMonth');
//         return;
//       }

//       String todayDate = DateFormat('yyyy-MM-dd').format(now);

//       DocumentSnapshot settingsDoc = await _firestore
//           .collection('hostelSettings')
//           .doc('settings')
//           .get();

//         Map<String, dynamic> settings = settingsDoc.exists
//           ? Map<String, dynamic>.from(settingsDoc.data() as Map)
//           : <String, dynamic>{};
//       Map<String, dynamic> messTimings = settings['messTimings'] ?? {};
//       final activeMealTypes = _getActiveMealTypes(settings);

//       final String studentName = studentData['fullName'] ??
//           studentData['studentName'] ??
//           studentData['name'] ??
//           'Unknown';

//       final List<MealType> mealTypes = activeMealTypes.map(_stringToMealType).toList();

//       for (final mealType in mealTypes) {
//         final String mealKey = mealType.toString().split('.').last;
//         if (!await _isStudentSubscribedForMeal(studentId, currentMonth, mealType)) {
//           continue;
//         }
//         final String mealCycle = '$todayDate-$mealKey';

//         final existing = await _firestore
//             .collection('messTokens')
//             .where('studentId', isEqualTo: studentId)
//             .where('mealCycle', isEqualTo: mealCycle)
//             .limit(1)
//             .get();

//         if (existing.docs.isNotEmpty) continue;

//         final Map<String, dynamic> mealTime = messTimings[mealKey] ?? {};
//         final DateTime validFrom = _getMealStartTime(now, mealType, mealTime);
//         final DateTime validUntil = _getMealEndTime(now, mealType, mealTime);

//         final String tokenId = _generateTokenId();
//         final String qrData = _generateQRData(
//           tokenId: tokenId,
//           studentId: studentId,
//           mealType: mealType,
//           date: todayDate,
//           validFrom: validFrom,
//           validUntil: validUntil,
//         );

//         final String encryptedData = _encryptQRData(qrData);

//         final token = MessTokenModel(
//           id: tokenId,
//           studentId: studentId,
//           studentName: studentName,
//           tokenCode: tokenId,
//           mealType: mealType,
//           mealDate: Timestamp.fromDate(now),
//           validFrom: Timestamp.fromDate(validFrom),
//           validUntil: Timestamp.fromDate(validUntil),
//           isUsed: false,
//           qrData: encryptedData,
//           generatedBy: 'attendance',
//           status: TokenStatus.active,
//           mealCycle: mealCycle,
//         );

//         await _firestore.collection('messTokens').doc(tokenId).set(token.toMap());
//       }
//     } catch (e) {
//       debugPrint('Error generating daily tokens for student: $e');
//     }
//   }

//   static Future<bool> _isStudentSubscribedForMeal(
//     String studentId,
//     String month,
//     MealType mealType,
//   ) async {
//     final String mealKey = mealType.toString().split('.').last;
//     final subscriptionDoc = await _firestore.collection('mealSubscriptions').doc('${studentId}_$month').get();

//     if (!subscriptionDoc.exists) {
//       return false;
//     }

//     final data = subscriptionDoc.data() as Map<String, dynamic>?;
//     final monthlyMeals = data?['subscribedMeals'];
//     if (monthlyMeals is List) {
//       return monthlyMeals
//           .map((meal) => meal.toString().toLowerCase())
//           .contains(mealKey);
//     }

//     return false;
//   }

//   // Validate and mark token as used (called when staff scans QR)
//   static Future<Map<String, dynamic>> validateAndMarkToken({
//     required String scannedData,
//     required String staffId,
//     required String location,
//   }) async {
//     try {
//       // Local validation (works on free Firebase tier)
//       String decrypted = _decryptQRData(scannedData);
//       Map<String, dynamic> tokenData = jsonDecode(decrypted);

//       DocumentSnapshot tokenDoc = await _firestore.collection('messTokens').doc(tokenData['tokenId']).get();
//       if (!tokenDoc.exists) {
//         return {'success': false, 'message': 'Invalid token'};
//       }

//       MessTokenModel token = MessTokenModel.fromMap(tokenDoc.data() as Map<String, dynamic>, tokenDoc.id);
//       if (token.isUsed == true) {
//         return {'success': false, 'message': 'Token already used at ${_formatDate(token.usedAt)}'};
//       }
//       if (token.status != TokenStatus.active) {
//         return {'success': false, 'message': 'Token is ${token.statusString.toLowerCase()}'};
//       }

//       DateTime now = DateTime.now();
//       if (now.isBefore(token.validFrom!.toDate())) {
//         return {'success': false, 'message': 'Token not yet valid. Valid from ${_formatTime(token.validFrom)}'};
//       }
//       if (now.isAfter(token.validUntil!.toDate())) {
//         return {'success': false, 'message': 'Token expired at ${_formatTime(token.validUntil)}'};
//       }

//       bool alreadyAte = await _checkMealTaken(token.studentId!, token.mealType!, token.mealDate!);
//       if (alreadyAte) {
//         return {'success': false, 'message': 'Student already took ${token.mealTypeString} today'};
//       }

//       DocumentSnapshot studentDoc = await _firestore.collection('students').doc(token.studentId).get();
//       Map<String, dynamic> studentData = studentDoc.exists ? studentDoc.data() as Map<String, dynamic> : {};

//       await tokenDoc.reference.update({
//         'isUsed': true,
//         'usedAt': FieldValue.serverTimestamp(),
//         'usedBy': staffId,
//         'scannedAtLocation': location,
//         'status': 'used',
//       });

//       await _recordMeal(token, staffId, location);

//       final String mealTime = DateFormat('HH:mm').format(now);
//       await MessMenuService.recordMealConsumption(
//         token.studentId!,
//         DateFormat('yyyy-MM-dd').format(now),
//         token.mealTypeString.toLowerCase(),
//         mealTime,
//       );

//       return {
//         'success': true,
//         'message': '✅ ${token.mealTypeString} verified successfully',
//         'studentName': token.studentName,
//         'studentId': token.studentId,
//         'enrollmentNo': studentData['enrollmentNo'] ?? '',
//         'photoUrl': studentData['profileImage'] ?? '',
//         'mealType': token.mealTypeString,
//         'time': mealTime,
//       };
//     } catch (e) {
//       debugPrint('Error validating token: $e');
//       return {'success': false, 'message': 'Error validating token: $e'};
//     }
//   }


// // Get current token for a student.
//   // Returns currently valid token first, otherwise falls back to today's latest token
//   // so users can still see upcoming/expired token details instead of "No Active Token".
//   static Future<MessTokenModel?> getCurrentTokenForStudent(String studentId) async {
//     try {
//       final DateTime now = DateTime.now();
//       final String todayDate = DateFormat('yyyy-MM-dd').format(now);
//       final settingsDoc = await _firestore.collection('hostelSettings').doc('settings').get();
//       final Map<String, dynamic> settings = settingsDoc.exists
//           ? Map<String, dynamic>.from(settingsDoc.data() as Map)
//           : <String, dynamic>{};
//       final activeMealTypes = _getActiveMealTypes(settings);

//       final QuerySnapshot snapshot = await _firestore
//           .collection('messTokens')
//           .where('studentId', isEqualTo: studentId)
//           .get();

//       final List<MessTokenModel> todaysTokens = snapshot.docs
//           .map(
//             (doc) => MessTokenModel.fromMap(
//               doc.data() as Map<String, dynamic>,
//               doc.id,
//             ),
//           )
//           .where((token) {
//             final mealCycle = token.mealCycle ?? '';
//             final mealKey = token.mealType?.toString().split('.').last ?? '';
//             return mealCycle.startsWith('$todayDate-') &&
//                 activeMealTypes.contains(mealKey);
//           })
//           .toList();

//       if (todaysTokens.isEmpty) {
//         return null;
//       }

//       todaysTokens.sort((a, b) {
//         final aTime = a.validFrom?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
//         final bTime = b.validFrom?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
//         return bTime.compareTo(aTime);
//       });

//       for (final token in todaysTokens) {
//         if (token.status == TokenStatus.active && token.isValid) {
//           return token;
//         }
//       }

//       for (final token in todaysTokens) {
//         if (token.status == TokenStatus.active && token.isUsed != true) {
//           return token;
//         }
//       }

//       return todaysTokens.first;
//     } catch (e) {
//       debugPrint('Error getting current token: $e');
//       return null;
//     }
//   }

//   // Get meal history for a student
//   static Future<List<MessTokenModel>> getStudentMealHistory(
//     String studentId, {
//     int days = 7,
//   }) async {
//     try {
//       DateTime startDate = DateTime.now().subtract(Duration(days: days));
      
//       var tokens = await FirestoreService.queryDocuments(
//         collection: 'messTokens',
//         field: 'studentId',
//         isEqualTo: studentId,
//       );

//       final history = tokens
//           .map((t) => MessTokenModel.fromMap(t, t['id']))
//           .where((t) => t.mealDate!.toDate().isAfter(startDate))
//           .toList();

//       history.sort((a, b) {
//         final aDate = a.mealDate?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
//         final bDate = b.mealDate?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
//         return bDate.compareTo(aDate);
//       });

//       return history;
//     } catch (e) {
//       debugPrint('Error getting meal history: $e');
//       return [];
//     }
//   }

//   // Get today's meal status for a student
//   static Future<Map<String, bool>> getTodayMealStatus(String studentId) async {
//     try {
//       DateTime now = DateTime.now();
//       DateTime startOfDay = DateTime(now.year, now.month, now.day);
//       DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      
//       final firestore = FirebaseFirestore.instance;
//       QuerySnapshot snapshot = await firestore
//           .collection('messTokens')
//           .where('studentId', isEqualTo: studentId)
//           .get();
      
//       Map<String, bool> status = {
//         'breakfast': false,
//         'lunch': false,
//         'dinner': false,
//       };
      
//       for (var doc in snapshot.docs) {
//         MessTokenModel t = MessTokenModel.fromMap(
//           doc.data() as Map<String, dynamic>,
//           doc.id,
//         );
//         final DateTime? mealDate = t.mealDate?.toDate();
//         if (mealDate != null &&
//             mealDate.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
//             mealDate.isBefore(endOfDay) &&
//             t.isUsed == true) {
//           status[t.mealTypeString.toLowerCase()] = true;
//         }
//       }
      
//       return status;
//     } catch (e) {
//       debugPrint('Error getting meal status: $e');
//       return {};
//     }
//   }

//   // Private helper methods
//   static String _generateTokenId() {
//     String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
//     String random = Random().nextInt(9999).toString().padLeft(4, '0');
//     return 'TKN${timestamp.substring(timestamp.length - 8)}$random';
//   }

//   static String _generateQRData({
//     required String tokenId,
//     required String studentId,
//     required MealType mealType,
//     required String date,
//     required DateTime validFrom,
//     required DateTime validUntil,
//   }) {
//     Map<String, dynamic> data = {
//       'tokenId': tokenId,
//       'studentId': studentId,
//       'mealType': mealType.toString().split('.').last,
//       'date': date,
//       'validFrom': validFrom.toIso8601String(),
//       'validUntil': validUntil.toIso8601String(),
//       'hash': _generateHash('$tokenId$studentId$date'),
//     };
//     return jsonEncode(data);
//   }

//   static String _generateHash(String input) {
//     var bytes = utf8.encode(input);
//     var digest = sha256.convert(bytes);
//     return digest.toString().substring(0, 16);
//   }

//   static String _encryptQRData(String data) {
//     // Simple base64 encoding (in production, use proper encryption)
//     return base64.encode(utf8.encode(data));
//   }

//   static String _decryptQRData(String encrypted) {
//     // Simple base64 decoding
//     return utf8.decode(base64.decode(encrypted));
//   }

//   static MealType? _getCurrentMealType(Map<String, dynamic> settings) {
//     final now = DateTime.now();
//     final activeMealTypes = _getActiveMealTypes(settings);
//     final messTimings = settings['messTimings'] ?? {};

//     bool isWithinWindow(String mealKey) {
//       if (!activeMealTypes.contains(mealKey)) return false;
//       final Map<String, dynamic> mealTime = messTimings[mealKey] ?? {};
//       final start = _getMealStartTime(now, _stringToMealType(mealKey), mealTime);
//       final end = _getMealEndTime(now, _stringToMealType(mealKey), mealTime);
//       return !now.isBefore(start) && !now.isAfter(end);
//     }

//     if (isWithinWindow('breakfast')) return MealType.breakfast;
//     if (isWithinWindow('lunch')) return MealType.lunch;
//     if (isWithinWindow('dinner')) return MealType.dinner;

//     return null;
//   }

//   static List<String> _getActiveMealTypes(Map<String, dynamic> settings) {
//     final stored = settings['messActiveMealTypes'];
//     if (stored is List) {
//       final meals = stored.map((e) => e.toString().toLowerCase()).toList();
//       if (meals.isNotEmpty) return meals;
//     }
//     return ['breakfast', 'lunch', 'dinner'];
//   }

//   static MealType _stringToMealType(String mealType) {
//     switch (mealType) {
//       case 'breakfast':
//         return MealType.breakfast;
//       case 'dinner':
//         return MealType.dinner;
//       case 'lunch':
//       default:
//         return MealType.lunch;
//     }
//   }

//   static DateTime _getMealStartTime(
//     DateTime now,
//     MealType mealType,
//     Map<String, dynamic> mealTime,
//   ) {
//     String startTimeStr = mealTime['start'] ?? _getDefaultStartTime(mealType);
//     List<String> parts = startTimeStr.split(':');
//     return DateTime(
//       now.year,
//       now.month,
//       now.day,
//       int.parse(parts[0]),
//       int.parse(parts[1]),
//     );
//   }

//   static DateTime _getMealEndTime(
//     DateTime now,
//     MealType mealType,
//     Map<String, dynamic> mealTime,
//   ) {
//     String endTimeStr = mealTime['end'] ?? _getDefaultEndTime(mealType);
//     List<String> parts = endTimeStr.split(':');
//     return DateTime(
//       now.year,
//       now.month,
//       now.day,
//       int.parse(parts[0]),
//       int.parse(parts[1]),
//     );
//   }

//   static String _getDefaultStartTime(MealType mealType) {
//     switch (mealType) {
//       case MealType.breakfast:
//         return '07:00';
//       case MealType.lunch:
//         return '12:00';
//       case MealType.dinner:
//         return '19:00';
//     }
//   }

//   static String _getDefaultEndTime(MealType mealType) {
//     switch (mealType) {
//       case MealType.breakfast:
//         return '09:00';
//       case MealType.lunch:
//         return '14:00';
//       case MealType.dinner:
//         return '21:00';
//     }
//   }

//   static Future<bool> _checkMealTaken(
//     String studentId,
//     MealType mealType,
//     Timestamp mealDate,
//   ) async {
//     try {
//       DateTime date = mealDate.toDate();
//       DateTime startOfDay = DateTime(date.year, date.month, date.day);
//       DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      
//       var records = await _firestore
//           .collection('mealRecords')
//           .where('studentId', isEqualTo: studentId)
//           .where('mealType', isEqualTo: mealType.toString().split('.').last)
//           .where('mealDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
//           .where('mealDate', isLessThan: Timestamp.fromDate(endOfDay))
//           .get();
      
//       return records.docs.isNotEmpty;
//     } catch (e) {
//       debugPrint('Error checking meal taken: $e');
//       return false;
//     }
//   }

//   static Future<void> _recordMeal(
//     MessTokenModel token,
//     String staffId,
//     String location,
//   ) async {
//     try {
//       await _firestore.collection('mealRecords').add({
//         'studentId': token.studentId,
//         'studentName': token.studentName,
//         'mealType': token.mealTypeString,
//         'mealDate': token.mealDate,
//         'scannedAt': FieldValue.serverTimestamp(),
//         'scannedBy': staffId,
//         'messCounter': location,
//         'tokenId': token.id,
//         'status': 'taken',
//       });
//     } catch (e) {
//       debugPrint('Error recording meal: $e');
//     }
//   }

//   static String _formatDate(Timestamp? timestamp) {
//     if (timestamp == null) return 'Unknown';
//     return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
//   }

//   static String _formatTime(Timestamp? timestamp) {
//     if (timestamp == null) return 'Unknown';
//     return DateFormat('hh:mm a').format(timestamp.toDate());
//   }
// }

import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../models/mess_token_model.dart';
import '../models/student_model.dart';
import 'mess_menu_service.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'package:intl/intl.dart';

class MessService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _isMessRecordSelected(Map<String, dynamic> studentData) {
    return studentData['messMonthlyFeeSelected'] == true ||
        studentData['feePlan']?.toString() == 'messMonthly' ||
        studentData['feePlan']?.toString() == 'hostelSemester+messMonthly';
  }

  static bool _isMessFeePaidForMonth(Map<String, dynamic> studentData, String currentMonth) {
    final messMonthlyFees = Map<String, bool>.from(studentData['messMonthlyFees'] ?? {});
    return messMonthlyFees[currentMonth] ?? false;
  }
  
  // Auto-detect current meal time and generate tokens
  static Future<void> generateTokensForCurrentMealTime() async {
    try {
      final settingsDoc = await _firestore
          .collection('hostelSettings')
          .doc('settings')
          .get();

      final Map<String, dynamic> settings = settingsDoc.exists
          ? Map<String, dynamic>.from(settingsDoc.data() as Map)
          : <String, dynamic>{};
      
      final currentMeal = _getCurrentMealType(settings);

      if (currentMeal == null) {
        debugPrint('No active meal time right now');
        return;
      }

      debugPrint('Current meal detected: $currentMeal');
      await _generateMealTokensForType(currentMeal);
    } catch (e) {
      debugPrint('Error generating tokens for current meal time: $e');
      rethrow;
    }
  }

  // Generate mess tokens for all students for a specific meal (internal)
  static Future<void> _generateMealTokensForType(MealType mealType) async {

    try {
      DateTime now = DateTime.now();
      String todayDate = DateFormat('yyyy-MM-dd').format(now);
      String mealCycle = '$todayDate-${mealType.toString().split('.').last}';
      
      // Get current month for fee checking
      String currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // Get all active students from Firestore
      var allStudents = await FirestoreService.queryDocuments(
        collection: 'students',
      );
      
      // Filter students who have paid fees for current month
      var students = allStudents.where((student) {
        return _isMessRecordSelected(student) && _isMessFeePaidForMonth(student, currentMonth);
      }).toList();
      
      // Get meal timings from settings
      DocumentSnapshot settingsDoc = await _firestore
          .collection('hostelSettings')
          .doc('settings')
          .get();

      Map<String, dynamic> settings = settingsDoc.exists
          ? Map<String, dynamic>.from(settingsDoc.data() as Map)
          : <String, dynamic>{};
      final activeMealTypes = _getActiveMealTypes(settings);
      if (!activeMealTypes.contains(mealType.toString().split('.').last)) {
        debugPrint('Skipping $mealType because it is disabled in hostelSettings/settings');
        return;
      }
      Map<String, dynamic> messTimings = settings['messTimings'] ?? {};
      
      // Get meal timings
      Map<String, dynamic> mealTime = messTimings[mealType.toString().split('.').last] ?? {};
      
      DateTime validFrom = _getMealStartTime(now, mealType, mealTime);
      DateTime validUntil = _getMealEndTime(now, mealType, mealTime);
      
      int generatedCount = 0;

      // Generate token for each student (only if missing)
      for (var student in students) {
        final String studentUserId =
            (student['userId'] ?? student['id'] ?? '').toString();
        if (studentUserId.isEmpty) {
          continue;
        }

        if (!await _isStudentSubscribedForMeal(studentUserId, currentMonth, mealType)) {
          continue;
        }

        final existingForStudent = await _firestore
            .collection('messTokens')
            .where('studentId', isEqualTo: studentUserId)
            .where('mealCycle', isEqualTo: mealCycle)
            .limit(1)
            .get();

        if (existingForStudent.docs.isNotEmpty) {
          continue;
        }

        String tokenId = _generateTokenId();
        String qrData = _generateQRData(
          tokenId: tokenId,
          studentId: studentUserId,
          mealType: mealType,
          date: todayDate,
          validFrom: validFrom,
          validUntil: validUntil,
        );
        
        String encryptedData = _encryptQRData(qrData);
        
        MessTokenModel token = MessTokenModel(
          id: tokenId,
          studentId: studentUserId,
          studentName: student['studentName'] ?? 'Unknown',
          tokenCode: tokenId,
          mealType: mealType,
          mealDate: Timestamp.fromDate(now),
          validFrom: Timestamp.fromDate(validFrom),
          validUntil: Timestamp.fromDate(validUntil),
          isUsed: false,
          qrData: encryptedData,
          generatedBy: 'system',
          status: TokenStatus.active,
          mealCycle: mealCycle,
        );
        
        await _firestore.collection('messTokens').doc(tokenId).set(token.toMap());
        generatedCount++;
      }
      
      // ✅ Send notification to all students about token availability
      if (generatedCount > 0) {
        await NotificationService.sendToAllStudents(
          title: '🍽️ ${mealType.toString().split('.').last.toUpperCase()} Token Available',
          body: 'Your ${mealType.toString().split('.').last} token is now active. Valid until ${DateFormat('hh:mm a').format(validUntil)}.',
          type: 'mess',
          data: {'mealType': mealType.toString().split('.').last, 'validUntil': validUntil.toIso8601String()},
        );
      }
      
      debugPrint('Generated $generatedCount new tokens for $mealCycle (eligible students: ${students.length})');
    } catch (e) {
      debugPrint('Error generating meal tokens: $e');
      rethrow;
    }
  }

  // Generate today's meal tokens for a single student after successful attendance check-in
  static Future<void> generateDailyTokensForStudent(String studentId) async {
    try {
      final studentDoc = await _firestore.collection('students').doc(studentId).get();
      Map<String, dynamic> studentData = {};

      if (studentDoc.exists) {
        studentData = studentDoc.data() as Map<String, dynamic>;
      } else {
        final userDoc = await _firestore.collection('users').doc(studentId).get();
        if (!userDoc.exists) {
          debugPrint('Student/user record not found for token generation: $studentId');
          return;
        }
        studentData = userDoc.data() as Map<String, dynamic>;
      }

      DateTime now = DateTime.now();
      String currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // Check if student has paid fees for current month
      if (!_isMessRecordSelected(studentData)) {
        debugPrint('Skipping token generation: mess record not selected for $studentId');
        return;
      }

      if (!_isMessFeePaidForMonth(studentData, currentMonth)) {
        debugPrint('Skipping token generation: mess fee not paid for $studentId in $currentMonth');
        return;
      }

      String todayDate = DateFormat('yyyy-MM-dd').format(now);

      DocumentSnapshot settingsDoc = await _firestore
          .collection('hostelSettings')
          .doc('settings')
          .get();

      Map<String, dynamic> settings = settingsDoc.exists
          ? Map<String, dynamic>.from(settingsDoc.data() as Map)
          : <String, dynamic>{};
      Map<String, dynamic> messTimings = settings['messTimings'] ?? {};
      final activeMealTypes = _getActiveMealTypes(settings);

      final String studentName = studentData['fullName'] ??
          studentData['studentName'] ??
          studentData['name'] ??
          'Unknown';

      final List<MealType> mealTypes = activeMealTypes.map(_stringToMealType).toList();

      for (final mealType in mealTypes) {
        final String mealKey = mealType.toString().split('.').last;
        if (!await _isStudentSubscribedForMeal(studentId, currentMonth, mealType)) {
          continue;
        }
        final String mealCycle = '$todayDate-$mealKey';

        final existing = await _firestore
            .collection('messTokens')
            .where('studentId', isEqualTo: studentId)
            .where('mealCycle', isEqualTo: mealCycle)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) continue;

        final Map<String, dynamic> mealTime = messTimings[mealKey] ?? {};
        final DateTime validFrom = _getMealStartTime(now, mealType, mealTime);
        final DateTime validUntil = _getMealEndTime(now, mealType, mealTime);

        final String tokenId = _generateTokenId();
        final String qrData = _generateQRData(
          tokenId: tokenId,
          studentId: studentId,
          mealType: mealType,
          date: todayDate,
          validFrom: validFrom,
          validUntil: validUntil,
        );

        final String encryptedData = _encryptQRData(qrData);

        final token = MessTokenModel(
          id: tokenId,
          studentId: studentId,
          studentName: studentName,
          tokenCode: tokenId,
          mealType: mealType,
          mealDate: Timestamp.fromDate(now),
          validFrom: Timestamp.fromDate(validFrom),
          validUntil: Timestamp.fromDate(validUntil),
          isUsed: false,
          qrData: encryptedData,
          generatedBy: 'attendance',
          status: TokenStatus.active,
          mealCycle: mealCycle,
        );

        await _firestore.collection('messTokens').doc(tokenId).set(token.toMap());
      }
    } catch (e) {
      debugPrint('Error generating daily tokens for student: $e');
    }
  }

  static Future<bool> _isStudentSubscribedForMeal(
    String studentId,
    String month,
    MealType mealType,
  ) async {
    final String mealKey = mealType.toString().split('.').last;
    final subscriptionDoc = await _firestore.collection('mealSubscriptions').doc('${studentId}_$month').get();

    if (!subscriptionDoc.exists) {
      return false;
    }

    final data = subscriptionDoc.data() as Map<String, dynamic>?;
    final monthlyMeals = data?['subscribedMeals'];
    if (monthlyMeals is List) {
      return monthlyMeals
          .map((meal) => meal.toString().toLowerCase())
          .contains(mealKey);
    }

    return false;
  }

  // Validate and mark token as used (called when staff scans QR)
  static Future<Map<String, dynamic>> validateAndMarkToken({
    required String scannedData,
    required String staffId,
    required String location,
  }) async {
    try {
      // Local validation (works on free Firebase tier)
      String decrypted = _decryptQRData(scannedData);
      Map<String, dynamic> tokenData = jsonDecode(decrypted);

      DocumentSnapshot tokenDoc = await _firestore.collection('messTokens').doc(tokenData['tokenId']).get();
      if (!tokenDoc.exists) {
        return {'success': false, 'message': 'Invalid token'};
      }

      MessTokenModel token = MessTokenModel.fromMap(tokenDoc.data() as Map<String, dynamic>, tokenDoc.id);
      if (token.isUsed == true) {
        return {'success': false, 'message': 'Token already used at ${_formatDate(token.usedAt)}'};
      }
      if (token.status != TokenStatus.active) {
        return {'success': false, 'message': 'Token is ${token.statusString.toLowerCase()}'};
      }

      DateTime now = DateTime.now();
      if (now.isBefore(token.validFrom!.toDate())) {
        return {'success': false, 'message': 'Token not yet valid. Valid from ${_formatTime(token.validFrom)}'};
      }
      if (now.isAfter(token.validUntil!.toDate())) {
        return {'success': false, 'message': 'Token expired at ${_formatTime(token.validUntil)}'};
      }

      bool alreadyAte = await _checkMealTaken(token.studentId!, token.mealType!, token.mealDate!);
      if (alreadyAte) {
        return {'success': false, 'message': 'Student already took ${token.mealTypeString} today'};
      }

      DocumentSnapshot studentDoc = await _firestore.collection('students').doc(token.studentId).get();
      Map<String, dynamic> studentData = studentDoc.exists ? studentDoc.data() as Map<String, dynamic> : {};

      await tokenDoc.reference.update({
        'isUsed': true,
        'usedAt': FieldValue.serverTimestamp(),
        'usedBy': staffId,
        'scannedAtLocation': location,
        'status': 'used',
      });

      await _recordMeal(token, staffId, location);

      final String mealTime = DateFormat('HH:mm').format(now);
      await MessMenuService.recordMealConsumption(
        token.studentId!,
        DateFormat('yyyy-MM-dd').format(now),
        token.mealTypeString.toLowerCase(),
        mealTime,
      );

      // ✅ Send notification to student about meal usage
      await NotificationService.sendNotification(
        title: '✅ Meal Token Used',
        body: 'Your ${token.mealTypeString} has been recorded at $mealTime at $location counter.',
        userId: token.studentId!,
        type: 'mess',
        data: {'mealType': token.mealTypeString, 'counter': location, 'time': mealTime},
      );

      return {
        'success': true,
        'message': '✅ ${token.mealTypeString} verified successfully',
        'studentName': token.studentName,
        'studentId': token.studentId,
        'enrollmentNo': studentData['enrollmentNo'] ?? '',
        'photoUrl': studentData['profileImage'] ?? '',
        'mealType': token.mealTypeString,
        'time': mealTime,
      };
    } catch (e) {
      debugPrint('Error validating token: $e');
      return {'success': false, 'message': 'Error validating token: $e'};
    }
  }


// Get current token for a student.
  // Returns currently valid token first, otherwise falls back to today's latest token
  // so users can still see upcoming/expired token details instead of "No Active Token".
  static Future<MessTokenModel?> getCurrentTokenForStudent(String studentId) async {
    try {
      final DateTime now = DateTime.now();
      final String todayDate = DateFormat('yyyy-MM-dd').format(now);
      final settingsDoc = await _firestore.collection('hostelSettings').doc('settings').get();
      final Map<String, dynamic> settings = settingsDoc.exists
          ? Map<String, dynamic>.from(settingsDoc.data() as Map)
          : <String, dynamic>{};
      final activeMealTypes = _getActiveMealTypes(settings);

      final QuerySnapshot snapshot = await _firestore
          .collection('messTokens')
          .where('studentId', isEqualTo: studentId)
          .get();

      final List<MessTokenModel> todaysTokens = snapshot.docs
          .map(
            (doc) => MessTokenModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .where((token) {
            final mealCycle = token.mealCycle ?? '';
            final mealKey = token.mealType?.toString().split('.').last ?? '';
            return mealCycle.startsWith('$todayDate-') &&
                activeMealTypes.contains(mealKey);
          })
          .toList();

      if (todaysTokens.isEmpty) {
        return null;
      }

      todaysTokens.sort((a, b) {
        final aTime = a.validFrom?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.validFrom?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      for (final token in todaysTokens) {
        if (token.status == TokenStatus.active && token.isValid) {
          return token;
        }
      }

      for (final token in todaysTokens) {
        if (token.status == TokenStatus.active && token.isUsed != true) {
          return token;
        }
      }

      return todaysTokens.first;
    } catch (e) {
      debugPrint('Error getting current token: $e');
      return null;
    }
  }

  // Get meal history for a student
  static Future<List<MessTokenModel>> getStudentMealHistory(
    String studentId, {
    int days = 7,
  }) async {
    try {
      DateTime startDate = DateTime.now().subtract(Duration(days: days));
      
      var tokens = await FirestoreService.queryDocuments(
        collection: 'messTokens',
        field: 'studentId',
        isEqualTo: studentId,
      );

      final history = tokens
          .map((t) => MessTokenModel.fromMap(t, t['id']))
          .where((t) => t.mealDate!.toDate().isAfter(startDate))
          .toList();

      history.sort((a, b) {
        final aDate = a.mealDate?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.mealDate?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      return history;
    } catch (e) {
      debugPrint('Error getting meal history: $e');
      return [];
    }
  }

  // Get today's meal status for a student
  static Future<Map<String, bool>> getTodayMealStatus(String studentId) async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      
      final firestore = FirebaseFirestore.instance;
      QuerySnapshot snapshot = await firestore
          .collection('messTokens')
          .where('studentId', isEqualTo: studentId)
          .get();
      
      Map<String, bool> status = {
        'breakfast': false,
        'lunch': false,
        'dinner': false,
      };
      
      for (var doc in snapshot.docs) {
        MessTokenModel t = MessTokenModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        final DateTime? mealDate = t.mealDate?.toDate();
        if (mealDate != null &&
            mealDate.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
            mealDate.isBefore(endOfDay) &&
            t.isUsed == true) {
          status[t.mealTypeString.toLowerCase()] = true;
        }
      }
      
      return status;
    } catch (e) {
      debugPrint('Error getting meal status: $e');
      return {};
    }
  }

  // Private helper methods
  static String _generateTokenId() {
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String random = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'TKN${timestamp.substring(timestamp.length - 8)}$random';
  }

  static String _generateQRData({
    required String tokenId,
    required String studentId,
    required MealType mealType,
    required String date,
    required DateTime validFrom,
    required DateTime validUntil,
  }) {
    Map<String, dynamic> data = {
      'tokenId': tokenId,
      'studentId': studentId,
      'mealType': mealType.toString().split('.').last,
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
    // Simple base64 encoding (in production, use proper encryption)
    return base64.encode(utf8.encode(data));
  }

  static String _decryptQRData(String encrypted) {
    // Simple base64 decoding
    return utf8.decode(base64.decode(encrypted));
  }

  static MealType? _getCurrentMealType(Map<String, dynamic> settings) {
    final now = DateTime.now();
    final activeMealTypes = _getActiveMealTypes(settings);
    final messTimings = settings['messTimings'] ?? {};

    bool isWithinWindow(String mealKey) {
      if (!activeMealTypes.contains(mealKey)) return false;
      final Map<String, dynamic> mealTime = messTimings[mealKey] ?? {};
      final start = _getMealStartTime(now, _stringToMealType(mealKey), mealTime);
      final end = _getMealEndTime(now, _stringToMealType(mealKey), mealTime);
      return !now.isBefore(start) && !now.isAfter(end);
    }

    if (isWithinWindow('breakfast')) return MealType.breakfast;
    if (isWithinWindow('lunch')) return MealType.lunch;
    if (isWithinWindow('dinner')) return MealType.dinner;

    return null;
  }

  static List<String> _getActiveMealTypes(Map<String, dynamic> settings) {
    final stored = settings['messActiveMealTypes'];
    if (stored is List) {
      final meals = stored.map((e) => e.toString().toLowerCase()).toList();
      if (meals.isNotEmpty) return meals;
    }
    return ['breakfast', 'lunch', 'dinner'];
  }

  static MealType _stringToMealType(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return MealType.breakfast;
      case 'dinner':
        return MealType.dinner;
      case 'lunch':
      default:
        return MealType.lunch;
    }
  }

  static DateTime _getMealStartTime(
    DateTime now,
    MealType mealType,
    Map<String, dynamic> mealTime,
  ) {
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

  static DateTime _getMealEndTime(
    DateTime now,
    MealType mealType,
    Map<String, dynamic> mealTime,
  ) {
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

  static String _getDefaultStartTime(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return '07:00';
      case MealType.lunch:
        return '12:00';
      case MealType.dinner:
        return '19:00';
    }
  }

  static String _getDefaultEndTime(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return '09:00';
      case MealType.lunch:
        return '14:00';
      case MealType.dinner:
        return '21:00';
    }
  }

  static Future<bool> _checkMealTaken(
    String studentId,
    MealType mealType,
    Timestamp mealDate,
  ) async {
    try {
      DateTime date = mealDate.toDate();
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));
      
      var records = await _firestore
          .collection('mealRecords')
          .where('studentId', isEqualTo: studentId)
          .where('mealType', isEqualTo: mealType.toString().split('.').last)
          .where('mealDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('mealDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      
      return records.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking meal taken: $e');
      return false;
    }
  }

  static Future<void> _recordMeal(
    MessTokenModel token,
    String staffId,
    String location,
  ) async {
    try {
      await _firestore.collection('mealRecords').add({
        'studentId': token.studentId,
        'studentName': token.studentName,
        'mealType': token.mealTypeString,
        'mealDate': token.mealDate,
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': staffId,
        'messCounter': location,
        'tokenId': token.id,
        'status': 'taken',
      });
    } catch (e) {
      debugPrint('Error recording meal: $e');
    }
  }

  static String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
  }

  static String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('hh:mm a').format(timestamp.toDate());
  }
}