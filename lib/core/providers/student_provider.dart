import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_2026/core/services/notification_service.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';

class StudentProvider extends ChangeNotifier {
  List<StudentModel> _students = [];
  StudentModel? _currentStudent;
  Map<String, dynamic> _studentStats = {};
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  List<StudentModel> get students => _students;
  StudentModel? get currentStudent => _currentStudent;
  Map<String, dynamic> get studentStats => _studentStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load all students
  Future<void> loadAllStudents() async {
    if (_isDisposed) return;
    _setLoading(true);
    try {
      final studentsData = await FirestoreService.queryDocuments(
        collection: 'students',
        orderBy: ['fullName'],
        descending: false,
      );
      
      _students = studentsData
          .map((s) => StudentModel.fromMap(s, s['id']))
          .toList();
      
      calculateStats();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load student by ID
  Future<void> loadStudentById(String studentId) async {
    if (_isDisposed) return;
    _setLoading(true);
    try {
      final studentData = await FirestoreService.readDocument(
        collection: 'students',
        documentId: studentId,
      );
      
      if (studentData != null) {
        _currentStudent = StudentModel.fromMap(studentData, studentId);
      }
      
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load students by room
  Future<void> loadStudentsByRoom(String roomId) async {
    if (_isDisposed) return;
    _setLoading(true);
    try {
      final studentsData = await FirestoreService.queryDocuments(
        collection: 'students',
        field: 'roomId',
        isEqualTo: roomId,
      );
      
      _students = studentsData
          .map((s) => StudentModel.fromMap(s, s['id']))
          .toList();
      
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Add new student
  Future<bool> addStudent(StudentModel student) async {
    if (_isDisposed) return false;
    _setLoading(true);
    try {
      await FirestoreService.createDocument(
        collection: 'students',
        data: student.toMap(),
        documentId: student.userId,
      );
      
      await loadAllStudents();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Update student
  Future<bool> updateStudent(String studentId, Map<String, dynamic> updates) async {
    if (_isDisposed) return false;
    _setLoading(true);
    try {
      await FirestoreService.updateDocument(
        collection: 'students',
        documentId: studentId,
        updates: updates,
      );
      
      await loadStudentById(studentId);
      await loadAllStudents();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Delete student
  Future<bool> deleteStudent(String studentId) async {
    if (_isDisposed) return false;
    _setLoading(true);
    try {
      await FirestoreService.deleteDocument(
        collection: 'students',
        documentId: studentId,
      );
      
      await loadAllStudents();
      if (_currentStudent?.id == studentId) {
        _currentStudent = null;
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Verify student
  Future<bool> verifyStudent(String studentId, String verifiedBy) async {
    if (_isDisposed) return false;
    _setLoading(true);
    try {
      final success = await updateStudent(studentId, {
        'isVerified': true,
        'verifiedBy': verifiedBy,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      
      if (success) {
        await NotificationService.sendNotification(
          title: '✅ Profile Verified',
          body: 'Your student profile has been verified by admin.',
          userId: studentId,
          type: 'student_verification',
          data: {'status': 'verified', 'verifiedBy': verifiedBy},
        );
      }
      
      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Search students
  List<StudentModel> searchStudents(String query) {
    if (query.isEmpty) return _students;
    final lowerQuery = query.toLowerCase();
    
    return _students.where((student) {
      return (student.fullName?.toLowerCase().contains(lowerQuery) ?? false) ||
          (student.enrollmentNo?.toLowerCase().contains(lowerQuery) ?? false) ||
          (student.course?.toLowerCase().contains(lowerQuery) ?? false) ||
          (student.email?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }


// Add this method to StudentProvider class
void updateStudentLocally(StudentModel student) {
  if (_currentStudent?.id == student.id) {
    _currentStudent = student;
    _safeNotify();
  }
  
  // Also update in the list if present
  final index = _students.indexWhere((s) => s.id == student.id);
  if (index != -1) {
    _students[index] = student;
  }
}

  // Get student statistics
  void calculateStats() {
    int total = _students.length;
    int verified = _students.where((s) => s.isVerified == true).length;
    int unverified = total - verified;
    int withRoom = _students.where((s) => s.roomId != null && s.roomId!.isNotEmpty).length;
    int withoutRoom = total - withRoom;
    
    _studentStats = {
      'total': total,
      'verified': verified,
      'unverified': unverified,
      'withRoom': withRoom,
      'withoutRoom': withoutRoom,
    };
    
    _safeNotify();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    _safeNotify();
  }

  // Safe set loading state
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