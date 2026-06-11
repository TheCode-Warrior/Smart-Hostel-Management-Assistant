import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FeeModel {
  String? id;
  String? studentId;
  String? feeType; // 'hostel', 'mess', 'caution', 'electricity', 'fine', 'other'
  double? amount;
  Timestamp? dueDate;
  double? paidAmount;
  Timestamp? paidDate;
  String? status; // 'pending', 'partial', 'paid', 'overdue', 'waived'
  String? paymentMode; // 'cash', 'card', 'online', 'cheque', 'upi', 'bank_transfer'
  String? transactionId;
  Map<String, dynamic>? paymentDetails;
  String? receiptNumber;
  String? receiptUrl;
  List<Map<String, dynamic>>? fines;
  String? semester;
  String? academicYear;
  String? remarks;
  String? createdBy;
  String? verifiedBy;
  
  // Payment Request Fields
  String? paymentRequestStatus; // 'none', 'pending', 'approved', 'rejected'
  String? paymentRequestMethod; // 'cash', 'bank_transfer', 'cheque'
  String? paymentRequestNote;
  Timestamp? paymentRequestDate;
  String? paymentApprovedBy;
  Timestamp? paymentApprovedAt;
  String? paymentRejectedReason;
  
  Timestamp? verifiedAt;
  Timestamp? createdAt;

  FeeModel({
    this.id,
    this.studentId,
    this.feeType,
    this.amount,
    this.dueDate,
    this.paidAmount,
    this.paidDate,
    this.status,
    this.paymentMode,
    this.transactionId,
    this.paymentDetails,
    this.receiptNumber,
    this.receiptUrl,
    this.fines,
    this.semester,
    this.academicYear,
    this.remarks,
    this.createdBy,
    this.verifiedBy,
    this.paymentRequestStatus,
    this.paymentRequestMethod,
    this.paymentRequestNote,
    this.paymentRequestDate,
    this.paymentApprovedBy,
    this.paymentApprovedAt,
    this.paymentRejectedReason,
    this.verifiedAt,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'feeType': feeType,
      'amount': amount ?? 0.0,
      'dueDate': dueDate,
      'paidAmount': paidAmount ?? 0.0,
      'paidDate': paidDate,
      'status': status ?? 'pending',
      'paymentMode': paymentMode,
      'transactionId': transactionId,
      'paymentDetails': paymentDetails ?? {},
      'receiptNumber': receiptNumber,
      'receiptUrl': receiptUrl,
      'fines': fines ?? [],
      'semester': semester,
      'academicYear': academicYear,
      'remarks': remarks,
      'createdBy': createdBy,
      'verifiedBy': verifiedBy,
      'paymentRequestStatus': paymentRequestStatus ?? 'none',
      'paymentRequestMethod': paymentRequestMethod,
      'paymentRequestNote': paymentRequestNote,
      'paymentRequestDate': paymentRequestDate,
      'paymentApprovedBy': paymentApprovedBy,
      'paymentApprovedAt': paymentApprovedAt,
      'paymentRejectedReason': paymentRejectedReason,
      'verifiedAt': verifiedAt,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory FeeModel.fromMap(Map<String, dynamic> map, String id) {
    return FeeModel(
      id: id,
      studentId: map['studentId'],
      feeType: map['feeType'],
      amount: (map['amount'] ?? 0.0).toDouble(),
      dueDate: map['dueDate'],
      paidAmount: (map['paidAmount'] ?? 0.0).toDouble(),
      paidDate: map['paidDate'],
      status: map['status'],
      paymentMode: map['paymentMode'],
      transactionId: map['transactionId'],
      paymentDetails: map['paymentDetails'],
      receiptNumber: map['receiptNumber'],
      receiptUrl: map['receiptUrl'],
      fines: List<Map<String, dynamic>>.from(map['fines'] ?? []),
      semester: map['semester'],
      academicYear: map['academicYear'],
      remarks: map['remarks'],
      createdBy: map['createdBy'],
      verifiedBy: map['verifiedBy'],
      paymentRequestStatus: map['paymentRequestStatus'] ?? 'none',
      paymentRequestMethod: map['paymentRequestMethod'],
      paymentRequestNote: map['paymentRequestNote'],
      paymentRequestDate: map['paymentRequestDate'],
      paymentApprovedBy: map['paymentApprovedBy'],
      paymentApprovedAt: map['paymentApprovedAt'],
      paymentRejectedReason: map['paymentRejectedReason'],
      verifiedAt: map['verifiedAt'],
      createdAt: map['createdAt'],
    );
  }

  // Helper methods
  double get dueAmount {
    return (amount ?? 0) - (paidAmount ?? 0);
  }

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isOverdue => status == 'overdue';
  bool get isPartial => status == 'partial';
  bool get hasPendingRequest => paymentRequestStatus == 'pending';
  bool get isRequestApproved => paymentRequestStatus == 'approved';
  bool get isRequestRejected => paymentRequestStatus == 'rejected';

  Color get statusColor {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'partial':
        return Colors.blue;
      case 'waived':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'overdue':
        return Icons.warning;
      case 'partial':
        return Icons.payment;
      case 'waived':
        return Icons.offline_bolt;
      default:
        return Icons.help;
    }
  }

  String get formattedDueDate {
    if (dueDate == null) return 'N/A';
    final date = dueDate!.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String get formattedPaidDate {
    if (paidDate == null) return 'N/A';
    final date = paidDate!.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  bool get hasFines {
    return fines != null && fines!.isNotEmpty;
  }

  double get totalFines {
    if (!hasFines) return 0.0;
    return fines!.fold(0.0, (sum, fine) => sum + (fine['amount'] ?? 0.0));
  }

  int get unpaidFinesCount {
    if (!hasFines) return 0;
    return fines!.where((f) => f['paid'] == false).length;
  }
}