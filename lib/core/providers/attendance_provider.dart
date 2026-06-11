import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceProvider extends ChangeNotifier {
  List<AttendanceModel> _attendanceHistory = [];
  Map<String, dynamic>? _todayAttendance;
  Map<String, dynamic> _attendanceStats = {};
  bool _isLoading = false;
  String? _errorMessage;
  double _attendancePercentage = 0.0;
  String? _feeStatus;
  bool _isDisposed = false;

  List<AttendanceModel> get attendanceHistory => _attendanceHistory;
  Map<String, dynamic>? get todayAttendance => _todayAttendance;
  Map<String, dynamic> get attendanceStats => _attendanceStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get attendancePercentage => _attendancePercentage;
  String? get feeStatus => _feeStatus;

  // Mark check-in
  Future<Map<String, dynamic>> markCheckIn({
    required String studentId,
    required Position location,
    required String method,
    String? qrCode,
  }) async {
    _setLoading(true);
    try {
      final result = await AttendanceService.markCheckIn(
        studentId: studentId,
        location: location,
        method: method,
        qrCode: qrCode,
      );

      if (result['success'] == true) {
        await loadTodayAttendance(studentId);
        await loadAttendanceHistory(studentId, days: 30);
        await loadAttendanceStats(studentId, months: 1);
        _calculateAttendancePercentage();
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

  // Mark check-out
  Future<Map<String, dynamic>> markCheckOut(String studentId) async {
    _setLoading(true);
    try {
      final result = await AttendanceService.markCheckOut(studentId);

      if (result['success'] == true) {
        await loadTodayAttendance(studentId);
        await loadAttendanceHistory(studentId, days: 30);
        await loadAttendanceStats(studentId, months: 1);
        _calculateAttendancePercentage();
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

  // Load attendance history
  Future<void> loadAttendanceHistory(String studentId, {int days = 30}) async {
    if (_isDisposed) return;
    _setLoading(true);
    try {
      _attendanceHistory = await AttendanceService.getStudentAttendance(
        studentId,
        days: days,
      );
      _calculateAttendancePercentage();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

 // Update loadAttendanceOverview in attendance_provider.dart

Future<void> loadAttendanceOverview(
  String studentId, {
  int days = 30,
  int months = 1,
}) async {
  if (_isDisposed) return;
  _setLoading(true);
  try {
    final results = await Future.wait([
      AttendanceService.getTodayAttendance(studentId),
      AttendanceService.getStudentAttendance(studentId, days: days),
      AttendanceService.getAttendanceStats(studentId, months: months),
    ]);

    _todayAttendance = results[0] as Map<String, dynamic>;
    _attendanceHistory = results[1] as List<AttendanceModel>;
    _attendanceStats = results[2] as Map<String, dynamic>;
    
    // Get attendance percentage from stats first
    _attendancePercentage = _attendanceStats['attendancePercentage'] ?? 0.0;
    
    // If stats returned 0 but we have history, calculate manually
    if (_attendancePercentage == 0.0 && _attendanceHistory.isNotEmpty) {
      _calculateAttendancePercentage();
    }
    
    _setLoading(false);
  } catch (e) {
    _errorMessage = e.toString();
    _setLoading(false);
  }
}
  // Load today's attendance
  Future<void> loadTodayAttendance(String studentId) async {
    try {
      _todayAttendance = await AttendanceService.getTodayAttendance(studentId);
      _safeNotify();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Load attendance statistics
  Future<void> loadAttendanceStats(String studentId, {int months = 1}) async {
    if (_isDisposed) return;
    _setLoading(true);
    try {
      _attendanceStats = await AttendanceService.getAttendanceStats(
        studentId,
        months: months,
      );
      _attendancePercentage = _attendanceStats['attendancePercentage'] ?? 0.0;
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Generate QR for attendance
  String generateAttendanceQR(String studentId) {
    return AttendanceService.generateAttendanceQR(studentId);
  }

  // Check if location is within geofence
  Future<bool> isWithinGeofence(Position position) async {
    try {
      return await AttendanceService.isWithinGeofence(position);
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

 // Replace the _calculateAttendancePercentage method in attendance_provider.dart

void _calculateAttendancePercentage() {
  if (_attendanceHistory.isEmpty) {
    _attendancePercentage = 0.0;
    return;
  }

  // Count present days (only present and late count as present)
  int presentDays = 0;
  for (var record in _attendanceHistory) {
    // Check if status is present or late (late counts as present)
    if (record.status == AttendanceStatus.present || 
        record.status == AttendanceStatus.late) {
      presentDays++;
    }
    // Half day can be counted as 0.5 if needed, but for percentage, count as 1
    else if (record.status == AttendanceStatus.halfDay) {
      presentDays++;
    }
    // Absent and holiday don't count
  }
  
  // Calculate percentage based on total days in range
  _attendancePercentage = (presentDays / _attendanceHistory.length) * 100;
  
  // Update stats
  _attendanceStats['attendancePercentage'] = _attendancePercentage;
  _attendanceStats['presentDays'] = presentDays;
  _attendanceStats['totalDays'] = _attendanceHistory.length;
  
  debugPrint('Attendance calculation: ${_attendanceHistory.length} total days, $presentDays present = ${_attendancePercentage.toStringAsFixed(1)}%');
}

  // Set fee status (from fee provider)
  void setFeeStatus(String status) {
    _feeStatus = status;
    _safeNotify();
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

  // Safe notify
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