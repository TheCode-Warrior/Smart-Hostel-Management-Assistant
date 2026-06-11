import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_2026/core/services/fee_service.dart';
import 'package:intl/intl.dart';
import '../models/fee_model.dart';
import '../services/firestore_service.dart';

class FeeProvider extends ChangeNotifier {
  List<FeeModel> _fees = [];
  List<FeeModel> _pendingFees = [];
  FeeModel? _currentFee;
  Map<String, dynamic> _feeStats = {};
  bool _isLoading = false;
  String? _errorMessage;
  double _totalDue = 0.0;
  double _totalPaid = 0.0;
  bool _isDisposed = false;

  List<FeeModel> get fees => _fees;
  List<FeeModel> get pendingFees => _pendingFees;
  FeeModel? get currentFee => _currentFee;
  Map<String, dynamic> get feeStats => _feeStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get totalDue => _totalDue;
  double get totalPaid => _totalPaid;

  // Load fees for a student
  // Load fees for a student
Future<void> loadStudentFees(String studentId) async {
  _setLoading(true);
  try {
    // Remove orderBy to avoid needing index
    final feesData = await FirestoreService.queryDocuments(
      collection: 'fees',
      field: 'studentId',
      isEqualTo: studentId,
      // orderBy: ['dueDate'],      // ← COMMENT THIS OUT
      // descending: true,           // ← COMMENT THIS OUT
    );
    
    _fees = feesData
        .map((f) => FeeModel.fromMap(f, f['id']))
        .toList();
    
    _filterFees();
    _calculateTotals();
    _setLoading(false);
  } catch (e) {
    _errorMessage = e.toString();
    _setLoading(false);
  }
}
  // Load all fees (for admin)
  Future<void> loadAllFees() async {
    _setLoading(true);
    try {
      final feesData = await FirestoreService.queryDocuments(
        collection: 'fees',
        orderBy: ['dueDate'],
        descending: true,
      );
      
      _fees = feesData
          .map((f) => FeeModel.fromMap(f, f['id']))
          .toList();
      
      _filterFees();
      _calculateTotals();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Add new fee
  // Future<bool> addFee(FeeModel fee) async {
  //   _setLoading(true);
  //   try {
  //     await FirestoreService.createDocument(
  //       collection: 'fees',
  //       data: fee.toMap(),
  //     );
      
  //     await loadStudentFees(fee.studentId!);
  //     _setLoading(false);
  //     return true;
  //   } catch (e) {
  //     _errorMessage = e.toString();
  //     _setLoading(false);
  //     return false;
  //   }
  // }
// Add this method to check for duplicate fees
Future<bool> _hasDuplicateFee(FeeModel newFee) async {
  // Check if student already has an unpaid fee of same type
  final existing = _fees.any((fee) => 
    fee.studentId == newFee.studentId && 
    fee.feeType == newFee.feeType &&
    fee.status != 'paid'
  );
  
  if (existing) {
    _errorMessage = '${newFee.feeType?.toUpperCase()} fee already exists and is unpaid for this student';
    return true;
  }
  
  // For mess fee, check if already exists for the same month
  if (newFee.feeType == 'mess' && newFee.dueDate != null) {
    final monthKey = DateFormat('yyyy-MM').format(newFee.dueDate!.toDate());
    final existingMonth = _fees.any((fee) => 
      fee.studentId == newFee.studentId &&
      fee.feeType == 'mess' &&
      fee.status != 'paid' &&
      DateFormat('yyyy-MM').format(fee.dueDate!.toDate()) == monthKey
    );
    
    if (existingMonth) {
      _errorMessage = 'Mess fee already exists for this month';
      return true;
    }
  }
  
  // For hostel fee, check if already exists for the same semester
  if (newFee.feeType == 'hostel' && newFee.semester != null) {
    final existingSemester = _fees.any((fee) => 
      fee.studentId == newFee.studentId &&
      fee.feeType == 'hostel' &&
      fee.status != 'paid' &&
      fee.semester == newFee.semester
    );
    
    if (existingSemester) {
      _errorMessage = 'Hostel fee already exists for Semester ${newFee.semester}';
      return true;
    }
  }
  
  return false;
}

Future<void> refreshFees() async {
  await loadAllFees();
  _safeNotify();
}

// Update addFee method
Future<bool> addFee(FeeModel fee) async {
  _setLoading(true);
  try {
    // Check for duplicate before adding
    if (await _hasDuplicateFee(fee)) {
      _setLoading(false);
      return false;
    }
    
    await FirestoreService.createDocument(
      collection: 'fees',
      data: fee.toMap(),
    );
    
    await loadStudentFees(fee.studentId!);
    _setLoading(false);
    return true;
  } catch (e) {
    _errorMessage = e.toString();
    _setLoading(false);
    return false;
  }
}
  // Update fee
  Future<bool> updateFee(String feeId, Map<String, dynamic> updates) async {
    _setLoading(true);
    try {
      await FirestoreService.updateDocument(
        collection: 'fees',
        documentId: feeId,
        updates: updates,
      );
      
      // Refresh
      if (_currentFee?.id == feeId) {
        await loadFeeById(feeId);
      }
      await loadAllFees();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Load fee by ID
  Future<void> loadFeeById(String feeId) async {
    _setLoading(true);
    try {
      final feeData = await FirestoreService.readDocument(
        collection: 'fees',
        documentId: feeId,
      );
      
      if (feeData != null) {
        _currentFee = FeeModel.fromMap(feeData, feeId);
      }
      
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Process payment
  // Future<Map<String, dynamic>> processPayment({
  //   required String feeId,
  //   required double amount,
  //   required String paymentMode,
  //   Map<String, dynamic>? paymentDetails,
  // }) async {
  //   _setLoading(true);
  //   try {
  //     final fee = _fees.firstWhere((f) => f.id == feeId);
      
  //     double newPaidAmount = (fee.paidAmount ?? 0) + amount;
  //     String status;
      
  //     if (newPaidAmount >= (fee.amount ?? 0)) {
  //       status = 'paid';
  //     } else if (newPaidAmount > 0) {
  //       status = 'partial';
  //     } else {
  //       status = 'pending';
  //     }

  //     String receiptNumber = 'RCP${DateTime.now().millisecondsSinceEpoch}';

  //     final updates = {
  //       'paidAmount': newPaidAmount,
  //       'paidDate': Timestamp.now(),
  //       'status': status,
  //       'paymentMode': paymentMode,
  //       'paymentDetails': paymentDetails,
  //       'receiptNumber': receiptNumber,
  //       'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
  //     };

  //     final success = await updateFee(feeId, updates);

  //     _setLoading(false);
      
  //     if (success) {
  //       return {
  //         'success': true,
  //         'message': 'Payment successful',
  //         'receiptNumber': receiptNumber,
  //       };
  //     } else {
  //       return {
  //         'success': false,
  //         'message': 'Payment failed',
  //       };
  //     }
  //   } catch (e) {
  //     _setLoading(false);
  //     return {
  //       'success': false,
  //       'message': 'Error: $e',
  //     };
  //   }
  // }

// Process payment
Future<Map<String, dynamic>> processPayment({
  required String feeId,
  required double amount,
  required String paymentMode,
  Map<String, dynamic>? paymentDetails,
}) async {
  _setLoading(true);
  try {
    final result = await FeeService.processPayment(
      feeId: feeId,
      studentId: _currentFee?.studentId ?? '',
      amount: amount,
      paymentMode: paymentMode,
      paymentDetails: paymentDetails,
    );
    _setLoading(false);
    return result;
  } catch (e) {
    _errorMessage = e.toString();
    _setLoading(false);
    return {'success': false, 'message': 'Error: $e'};
  }
}

// Send fee reminders on app startup
Future<void> sendReminders() async {
  await FeeService.sendFeeReminders();
}

  // Add fine
  Future<bool> addFine({
    required String studentId,
    required String reason,
    required double amount,
    required String imposedBy,
  }) async {
    _setLoading(true);
    try {
      // Create a new fee entry for fine
      final fine = FeeModel(
        studentId: studentId,
        feeType: 'fine',
        amount: amount,
        dueDate: Timestamp.now(),
        paidAmount: 0,
        status: 'pending',
        paymentMode: '',
        fines: [
          {
            'reason': reason,
            'amount': amount,
            'imposedOn': Timestamp.now(),
            'imposedBy': imposedBy,
            'paid': false,
          }
        ],
        semester: '',
        academicYear: '',
        createdBy: imposedBy,
        createdAt: Timestamp.now(),
      );

      await addFee(fine);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Generate receipt
  Future<String?> generateReceipt(String feeId) async {
    try {
      // This would generate a PDF receipt
      // Return URL of generated receipt
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    }
  }

  // Filter fees
  void _filterFees() {
    _pendingFees = _fees
        .where((f) => f.status == 'pending' || f.status == 'overdue' || f.status == 'partial')
        .toList();
  }

  // Calculate totals
  void _calculateTotals() {
    _totalDue = 0;
    _totalPaid = 0;
    
    for (var fee in _fees) {
      _totalDue += (fee.amount ?? 0);
      _totalPaid += (fee.paidAmount ?? 0);
    }
    
    // Calculate statistics
    int total = _fees.length;
    int paid = _fees.where((f) => f.status == 'paid').length;
    int pending = _fees.where((f) => f.status == 'pending').length;
    int overdue = _fees.where((f) => f.status == 'overdue').length;
    int partial = _fees.where((f) => f.status == 'partial').length;
    
    _feeStats = {
      'total': total,
      'paid': paid,
      'pending': pending,
      'overdue': overdue,
      'partial': partial,
      'totalDue': _totalDue,
      'totalPaid': _totalPaid,
      'collectionRate': _totalDue > 0 ? (_totalPaid / _totalDue * 100) : 0,
    };

    _safeNotify();
  }

  // Check if student has pending fees
  bool hasPendingFees(String studentId) {
    return _pendingFees.any((f) => f.studentId == studentId);
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    _safeNotify();
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
    super.dispose();
  }
}