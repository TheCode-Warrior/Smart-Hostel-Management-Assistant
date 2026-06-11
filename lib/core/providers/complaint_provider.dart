import 'package:flutter/material.dart';
import '../models/complaint_model.dart';
import '../services/complaint_service.dart';

class ComplaintProvider extends ChangeNotifier {
  List<ComplaintModel> _complaints = [];
  List<ComplaintModel> _recentComplaints = [];
  List<ComplaintModel> _activeComplaints = [];
  ComplaintModel? _currentComplaint;
  Map<String, dynamic> _complaintStats = {};
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  List<ComplaintModel> get complaints => _complaints;
  List<ComplaintModel> get recentComplaints => _recentComplaints;
  List<ComplaintModel> get activeComplaints => _activeComplaints;
  ComplaintModel? get currentComplaint => _currentComplaint;
  Map<String, dynamic> get complaintStats => _complaintStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Raise new complaint
  Future<Map<String, dynamic>> raiseComplaint({
    required String studentId,
    required String studentName,
    required String category,
    required String priority,
    required String title,
    required String description,
    required String location,
    List<String>? attachments,
  }) async {
    _setLoading(true);
    try {
      final result = await ComplaintService.createComplaint(
        studentId: studentId,
        studentName: studentName,
        category: category,
        priority: priority,
        title: title,
        description: description,
        location: location,
        attachments: attachments,
      );

      if (result['success'] == true) {
        await loadStudentComplaints(studentId);
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Load complaints for a student
  Future<void> loadStudentComplaints(String studentId) async {
    if (_isDisposed) return;
    
    _setLoading(true);
    try {
      _complaints = await ComplaintService.getStudentComplaints(studentId);
      _filterComplaints();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load all complaints (for admin/staff)
  Future<void> loadAllComplaints({
    ComplaintStatus? status,
    String? assignedTo,
  }) async {
    if (_isDisposed) return;
    
    _setLoading(true);
    try {
      _complaints = await ComplaintService.getAllComplaints(
        status: status,
        assignedTo: assignedTo,
      );
      _filterComplaints();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load complaint details
  Future<void> loadComplaintDetails(String complaintId) async {
    if (_isDisposed) return;
    
    _setLoading(true);
    try {
      // Try to find in local list first
      _currentComplaint = _complaints.firstWhere(
        (c) => c.id == complaintId,
        orElse: () => null as ComplaintModel,
      );
      
      // If not found in local list, fetch from service
      _currentComplaint ??= await ComplaintService.getComplaintById(complaintId);
      
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Update complaint status
  Future<Map<String, dynamic>> updateComplaintStatus({
    required String complaintId,
    required ComplaintStatus newStatus,
    required String updatedBy,
    String? comment,
    String? resolvedBy,
    String? resolutionNotes,
    List<String>? attachments,
  }) async {
    _setLoading(true);
    try {
      final result = await ComplaintService.updateComplaintStatus(
        complaintId: complaintId,
        newStatus: newStatus,
        updatedBy: updatedBy,
        comment: comment,
        resolvedBy: resolvedBy,
        resolutionNotes: resolutionNotes,
        attachments: attachments,
      );

      if (result['success'] == true) {
        await loadAllComplaints();
        if (_currentComplaint != null) {
          await loadComplaintDetails(complaintId);
        }
      }

      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Assign complaint to staff
 // Update assignComplaint method in complaint_provider.dart
Future<Map<String, dynamic>> assignComplaint({
  required String complaintId,
  required String staffId,
  required String staffName,
  required String assignedBy,
}) async {
  _setLoading(true);
  try {
    final result = await ComplaintService.assignComplaint(
      complaintId: complaintId,
      staffId: staffId,
      staffName: staffName,
      assignedBy: assignedBy,
    );

    if (result['success'] == true) {
      // ✅ Refresh both lists
      await loadAllComplaints();
      
      // ✅ Also refresh the current complaint if it's the same
      if (_currentComplaint?.id == complaintId) {
        await loadComplaintDetails(complaintId);
      }
      
      // ✅ Notify listeners immediately
      _safeNotify();
    }

    _setLoading(false);
    return result;
  } catch (e) {
    _setLoading(false);
    return {
      'success': false,
      'message': 'Error: $e',
    };
  }
}
  // Rate complaint
  Future<Map<String, dynamic>> rateComplaint({
    required String complaintId,
    required int rating,
    String? feedback,
  }) async {
    _setLoading(true);
    try {
      final result = await ComplaintService.rateComplaint(
        complaintId: complaintId,
        rating: rating,
        feedback: feedback,
      );

      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Load complaint statistics
  Future<void> loadComplaintStats() async {
    _setLoading(true);
    try {
      _complaintStats = await ComplaintService.getComplaintStats();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Add comment to complaint
  Future<void> addComment({
    required String complaintId,
    required String comment,
    required String userId,
    required String userName,
  }) async {
    try {
      await ComplaintService.addComment(
        complaintId: complaintId,
        comment: comment,
        userId: userId,
        userName: userName,
      );
      
      await loadComplaintDetails(complaintId);
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Filter complaints
  void _filterComplaints() {
    _recentComplaints = _complaints.take(5).toList();
    _activeComplaints = _complaints
        .where((c) => 
            c.status == ComplaintStatus.pending || 
            c.status == ComplaintStatus.assigned)
        .toList();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    _safeNotify();
  }

  // Set loading state with safe notification
  void _setLoading(bool loading) {
    _isLoading = loading;
    _safeNotify();
  }

  // Safe notify to prevent calling during build
  void _safeNotify() {
    if (_isDisposed) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}