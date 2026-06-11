import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/fee_model.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'package:intl/intl.dart';

class FeeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Process payment and send notification - ✅ AUTO UPDATES STUDENT FEE RECORD
  static Future<Map<String, dynamic>> processPayment({
    required String feeId,
    required String studentId,
    required double amount,
    required String paymentMode,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      final feeDoc = await _firestore.collection('fees').doc(feeId).get();
      if (!feeDoc.exists) {
        return {'success': false, 'message': 'Fee record not found'};
      }

      final feeData = feeDoc.data() as Map<String, dynamic>;
      final currentPaid = (feeData['paidAmount'] ?? 0.0).toDouble();
      final totalAmount = (feeData['amount'] ?? 0.0).toDouble();
      final feeType = feeData['feeType']?.toString().toLowerCase();
      final academicYear = feeData['academicYear'] ?? DateTime.now().year.toString();
      final newPaidAmount = currentPaid + amount;
      
      String status;
      if (newPaidAmount >= totalAmount) {
        status = 'paid';
      } else if (newPaidAmount > 0) {
        status = 'partial';
      } else {
        status = 'pending';
      }

      final receiptNumber = 'RCP${DateTime.now().millisecondsSinceEpoch}';

      await feeDoc.reference.update({
        'paidAmount': newPaidAmount,
        'paidDate': FieldValue.serverTimestamp(),
        'status': status,
        'paymentMode': paymentMode,
        'paymentDetails': paymentDetails ?? {},
        'receiptNumber': receiptNumber,
        'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
      });

      // ✅ AUTO-UPDATE STUDENT FEE RECORD if fully paid
      if (status == 'paid') {
        await _updateStudentFeeRecord(studentId, feeType, totalAmount, academicYear);
      }

      // Send payment confirmation notification
      await NotificationService.sendNotification(
        title: '💰 Payment Received',
        body: 'Your payment of ₹${amount.toStringAsFixed(2)} has been received. Receipt #$receiptNumber',
        userId: studentId,
        type: 'fee',
        data: {
          'amount': amount,
          'receiptNumber': receiptNumber,
          'feeType': feeData['feeType'],
          'status': status,
        },
      );

      return {
        'success': true,
        'message': 'Payment successful',
        'receiptNumber': receiptNumber,
        'status': status,
      };
    } catch (e) {
      debugPrint('Error processing payment: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ✅ Helper method to update student's fee record
  static Future<void> _updateStudentFeeRecord(String studentId, String? feeType, double amount, String academicYear) async {
    try {
      final studentRef = _firestore.collection('students').doc(studentId);
      final studentDoc = await studentRef.get();
      
      if (!studentDoc.exists) return;
      
      final studentData = studentDoc.data() as Map<String, dynamic>;
      final now = DateTime.now();
      final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      final Map<String, dynamic> updates = {};
      
      if (feeType == 'mess') {
        final currentMonthlyFees = Map<String, bool>.from(studentData['messMonthlyFees'] ?? {});
        currentMonthlyFees[currentMonth] = true;
        updates['messMonthlyFees'] = currentMonthlyFees;
        updates['messMonthlyFeeSelected'] = true;
        updates['lastMessFeePaid'] = FieldValue.serverTimestamp();
      }
      
      if (feeType == 'hostel') {
        updates['hostelSemesterFeeSelected'] = true;
        updates['lastHostelFeePaid'] = FieldValue.serverTimestamp();
        updates['academicYear'] = academicYear;
        final semester = studentData['semester']?.toString();
        if (semester != null) {
          updates['paidSemester'] = semester;
        }
      }
      
      if (updates.isNotEmpty) {
        await studentRef.update(updates);
        debugPrint('✅ Auto-updated student fee record via direct payment');
      }
      
      await _updateFeePlanIfNeeded(studentId);
      
    } catch (e) {
      debugPrint('Error updating student fee record: $e');
    }
  }

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
    } catch (e) {
      debugPrint('Error updating fee plan: $e');
    }
  }

  // Send fee reminder notifications for overdue/pending fees
  static Future<void> sendFeeReminders() async {
    try {
      final overdueFees = await _firestore
          .collection('fees')
          .where('status', whereIn: ['pending', 'overdue'])
          .get();

      for (var doc in overdueFees.docs) {
        final fee = doc.data();
        final dueDate = (fee['dueDate'] as Timestamp).toDate();
        final studentId = fee['studentId'];
        final amount = (fee['amount'] ?? 0.0).toDouble();
        final paidAmount = (fee['paidAmount'] ?? 0.0).toDouble();
        final dueAmount = amount - paidAmount;

        await NotificationService.sendNotification(
          title: '⚠️ Fee Payment Reminder',
          body: 'Your ${fee['feeType']} fee of ₹${dueAmount.toStringAsFixed(2)} is due on ${DateFormat('dd MMM yyyy').format(dueDate)}',
          userId: studentId,
          type: 'fee',
          data: {'feeId': doc.id, 'dueAmount': dueAmount, 'dueDate': dueDate.toIso8601String()},
        );
      }
    } catch (e) {
      debugPrint('Error sending fee reminders: $e');
    }
  }
}