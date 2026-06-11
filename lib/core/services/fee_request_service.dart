import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class FeeRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Student requests payment
  static Future<Map<String, dynamic>> requestPayment({
    required String feeId,
    required String studentId,
    required String studentName,
    required double amount,
    required String paymentMethod,
    String? note,
  }) async {
    try {
      final requestId = 'req_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create payment request document
      await _firestore.collection('feeRequests').doc(requestId).set({
        'feeId': feeId,
        'studentId': studentId,
        'studentName': studentName,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'note': note ?? '',
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // Update fee document with request status
      await _firestore.collection('fees').doc(feeId).update({
        'paymentRequestStatus': 'pending',
        'paymentRequestMethod': paymentMethod,
        'paymentRequestNote': note,
        'paymentRequestDate': FieldValue.serverTimestamp(),
      });

      // Send notification to all admins
      await _notifyAdminsAboutRequest(studentName, amount, paymentMethod, requestId);

      return {
        'success': true,
        'message': 'Payment request submitted successfully. Admin will review it.',
        'requestId': requestId,
      };
    } catch (e) {
      debugPrint('Error requesting payment: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Admin approves payment - ✅ AUTO UPDATES STUDENT FEE RECORD
  static Future<Map<String, dynamic>> approvePayment({
    required String feeId,
    required String requestId,
    required String adminId,
    required String adminName,
    String? receiptNumber,
  }) async {
    try {
      final receiptNum = receiptNumber ?? 'RCP${DateTime.now().millisecondsSinceEpoch}';
      
      // Get current fee data
      final feeDoc = await _firestore.collection('fees').doc(feeId).get();
      if (!feeDoc.exists) {
        return {'success': false, 'message': 'Fee record not found'};
      }
      
      final feeData = feeDoc.data() as Map<String, dynamic>;
      final studentId = feeData['studentId'];
      final totalAmount = (feeData['amount'] ?? 0.0).toDouble();
      final feeType = feeData['feeType']?.toString().toLowerCase();
      final academicYear = feeData['academicYear'] ?? DateTime.now().year.toString();
      
      // Update fee document
      await _firestore.collection('fees').doc(feeId).update({
        'status': 'paid',
        'paidAmount': totalAmount,
        'paidDate': FieldValue.serverTimestamp(),
        'paymentMode': feeData['paymentRequestMethod'] ?? 'cash',
        'receiptNumber': receiptNum,
        'paymentRequestStatus': 'approved',
        'paymentApprovedBy': adminId,
        'paymentApprovedAt': FieldValue.serverTimestamp(),
      });

      // Update request status
      await _firestore.collection('feeRequests').doc(requestId).update({
        'status': 'approved',
        'approvedBy': adminId,
        'approvedByName': adminName,
        'approvedAt': FieldValue.serverTimestamp(),
        'receiptNumber': receiptNum,
      });

      // ✅ AUTO-UPDATE STUDENT FEE RECORD
      await _updateStudentFeeRecord(studentId, feeType, totalAmount, academicYear);

      // Send notification to student
      if (studentId != null) {
        await NotificationService.sendNotification(
          title: '✅ Payment Approved',
          body: 'Your payment of ₹${totalAmount.toStringAsFixed(2)} has been approved. Receipt #$receiptNum',
          userId: studentId,
          type: 'fee',
          data: {'feeId': feeId, 'receiptNumber': receiptNum, 'feeType': feeType},
        );
      }

      return {
        'success': true,
        'message': 'Payment approved successfully',
        'receiptNumber': receiptNum,
      };
    } catch (e) {
      debugPrint('Error approving payment: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ✅ Helper method to update student's fee record automatically
  static Future<void> _updateStudentFeeRecord(String studentId, String? feeType, double amount, String academicYear) async {
    try {
      final studentRef = _firestore.collection('students').doc(studentId);
      final studentDoc = await studentRef.get();
      
      if (!studentDoc.exists) {
        debugPrint('Student document not found for ID: $studentId');
        return;
      }
      
      final studentData = studentDoc.data() as Map<String, dynamic>;
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      final Map<String, dynamic> updates = {};
      
      // Handle Mess Fee
      if (feeType == 'mess' || feeType == 'mess monthly') {
        final currentMonthlyFees = Map<String, bool>.from(studentData['messMonthlyFees'] ?? {});
        currentMonthlyFees[currentMonth] = true;
        
        updates['messMonthlyFees'] = currentMonthlyFees;
        updates['messMonthlyFeeSelected'] = true;
        updates['lastMessFeePaid'] = FieldValue.serverTimestamp();
        updates['lastMessFeeMonth'] = currentMonth;
        
        debugPrint('✅ Auto-updated mess fee for $studentId for month: $currentMonth');
      }
      
      // Handle Hostel Semester Fee
      if (feeType == 'hostel' || feeType == 'hostel semester') {
        updates['hostelSemesterFeeSelected'] = true;
        updates['lastHostelFeePaid'] = FieldValue.serverTimestamp();
        updates['academicYear'] = academicYear;
        
        // Get semester from student data or fee data
        final semester = studentData['semester']?.toString();
        if (semester != null) {
          updates['paidSemester'] = semester;
        }
        
        debugPrint('✅ Auto-updated hostel semester fee for $studentId');
      }
      
      // Handle Caution Deposit
      if (feeType == 'caution' || feeType == 'caution deposit') {
        updates['cautionDepositPaid'] = true;
        updates['cautionDepositAmount'] = amount;
        updates['cautionDepositPaidAt'] = FieldValue.serverTimestamp();
        
        debugPrint('✅ Auto-updated caution deposit for $studentId');
      }
      
      // Handle Fine
      if (feeType == 'fine') {
        final currentFines = List<Map<String, dynamic>>.from(studentData['fines'] ?? []);
        currentFines.add({
          'amount': amount,
          'paidAt': FieldValue.serverTimestamp(),
          'status': 'paid',
        });
        updates['fines'] = currentFines;
        updates['totalFinePaid'] = (studentData['totalFinePaid'] ?? 0.0) + amount;
        
        debugPrint('✅ Auto-updated fine record for $studentId');
      }
      
      // Apply all updates
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await studentRef.update(updates);
        debugPrint('✅ Student fee record updated successfully: ${updates.keys}');
      }
      
      // ✅ Update fee plan based on selections
      await _updateFeePlanIfNeeded(studentId);
      
    } catch (e) {
      debugPrint('Error updating student fee record: $e');
    }
  }

  // ✅ Update fee plan automatically
  static Future<void> _updateFeePlanIfNeeded(String studentId) async {
    try {
      final studentDoc = await _firestore.collection('students').doc(studentId).get();
      if (!studentDoc.exists) return;
      
      final data = studentDoc.data() as Map<String, dynamic>;
      final hostelSelected = data['hostelSemesterFeeSelected'] == true;
      final messSelected = data['messMonthlyFeeSelected'] == true;
      
      String feePlan;
      if (hostelSelected && messSelected) {
        feePlan = 'hostelSemester+messMonthly';
      } else if (hostelSelected) {
        feePlan = 'hostelSemester';
      } else if (messSelected) {
        feePlan = 'messMonthly';
      } else {
        feePlan = 'none';
      }
      
      await _firestore.collection('students').doc(studentId).update({
        'feePlan': feePlan,
      });
      
      debugPrint('✅ Auto-updated fee plan for $studentId: $feePlan');
    } catch (e) {
      debugPrint('Error updating fee plan: $e');
    }
  }

  // Admin rejects payment request
  static Future<Map<String, dynamic>> rejectPayment({
    required String feeId,
    required String requestId,
    required String adminId,
    required String reason,
  }) async {
    try {
      await _firestore.collection('fees').doc(feeId).update({
        'paymentRequestStatus': 'rejected',
        'paymentRejectedReason': reason,
      });

      await _firestore.collection('feeRequests').doc(requestId).update({
        'status': 'rejected',
        'rejectedBy': adminId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason,
      });

      // Get student ID for notification
      final feeDoc = await _firestore.collection('fees').doc(feeId).get();
      final feeData = feeDoc.data() as Map<String, dynamic>;
      final studentId = feeData['studentId'];

      if (studentId != null) {
        await NotificationService.sendNotification(
          title: '⚠️ Payment Request Rejected',
          body: 'Your payment request was rejected. Reason: $reason',
          userId: studentId,
          type: 'fee',
          data: {'feeId': feeId, 'reason': reason},
        );
      }

      return {
        'success': true,
        'message': 'Payment request rejected',
      };
    } catch (e) {
      debugPrint('Error rejecting payment: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Get all pending fee requests (for admin)
  static Stream<List<Map<String, dynamic>>> getPendingRequests() {
    return _firestore
        .collection('feeRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  // Get request by fee ID
  static Future<Map<String, dynamic>?> getRequestByFeeId(String feeId) async {
    try {
      final query = await _firestore
          .collection('feeRequests')
          .where('feeId', isEqualTo: feeId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return {...query.docs.first.data(), 'id': query.docs.first.id};
      }
      return null;
    } catch (e) {
      debugPrint('Error getting request: $e');
      return null;
    }
  }

  // Notify all admins
  static Future<void> _notifyAdminsAboutRequest(
    String studentName,
    double amount,
    String method,
    String requestId,
  ) async {
    final admins = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    for (var admin in admins.docs) {
      await NotificationService.sendNotification(
        title: '💰 New Payment Request',
        body: '$studentName requested ₹${amount.toStringAsFixed(2)} via $method',
        userId: admin.id,
        type: 'fee_request',
        data: {'requestId': requestId, 'amount': amount, 'student': studentName},
      );
    }
  }
}