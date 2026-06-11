import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AttendanceStatus { present, absent, late, halfDay, holiday }

class AttendanceModel {
  String? id;
  String? studentId;
  Timestamp? date;
  Timestamp? checkInTime;
  Timestamp? checkOutTime;
  GeoPoint? checkInLocation;
  GeoPoint? checkOutLocation;
  String? checkInAddress;
  String? checkOutAddress;
  String? checkInMethod; // 'qr' or 'gps' or 'manual'
  String? checkOutMethod; // 'qr' or 'gps' or 'manual'
  String? qrCodeUsed;
  String? verifiedBy;
  AttendanceStatus? status;
  String? markedBy; // for manual marking
  bool? isAutomatic;
  double? workingHours;
  double? overtimeHours;
  String? notes;
  Map<String, dynamic>? metadata;

  AttendanceModel({
    this.id,
    this.studentId,
    this.date,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.checkInAddress,
    this.checkOutAddress,
    this.checkInMethod,
    this.checkOutMethod,
    this.qrCodeUsed,
    this.verifiedBy,
    this.status,
    this.markedBy,
    this.isAutomatic,
    this.workingHours,
    this.overtimeHours,
    this.notes,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'date': date ?? FieldValue.serverTimestamp(),
      'checkInTime': checkInTime,
      'checkOutTime': checkOutTime,
      'checkInLocation': checkInLocation,
      'checkOutLocation': checkOutLocation,
      'checkInAddress': checkInAddress,
      'checkOutAddress': checkOutAddress,
      'checkInMethod': checkInMethod,
      'checkOutMethod': checkOutMethod,
      'qrCodeUsed': qrCodeUsed,
      'verifiedBy': verifiedBy,
      'status': status?.toString().split('.').last ?? 'absent',
      'markedBy': markedBy,
      'isAutomatic': isAutomatic ?? false,
      'workingHours': workingHours ?? 0.0,
      'overtimeHours': overtimeHours ?? 0.0,
      'notes': notes,
      'metadata': metadata ?? {},
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String id) {
    return AttendanceModel(
      id: id,
      studentId: map['studentId'],
      date: map['date'],
      checkInTime: map['checkInTime'],
      checkOutTime: map['checkOutTime'],
      checkInLocation: map['checkInLocation'],
      checkOutLocation: map['checkOutLocation'],
      checkInAddress: map['checkInAddress'],
      checkOutAddress: map['checkOutAddress'],
      checkInMethod: map['checkInMethod'],
      checkOutMethod: map['checkOutMethod'],
      qrCodeUsed: map['qrCodeUsed'],
      verifiedBy: map['verifiedBy'],
      status: _stringToStatus(map['status']),
      markedBy: map['markedBy'],
      isAutomatic: map['isAutomatic'],
      workingHours: (map['workingHours'] ?? 0.0).toDouble(),
      overtimeHours: (map['overtimeHours'] ?? 0.0).toDouble(),
      notes: map['notes'],
      metadata: map['metadata'],
    );
  }

  static AttendanceStatus _stringToStatus(String? status) {
    switch (status) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      case 'halfDay':
        return AttendanceStatus.halfDay;
      case 'holiday':
        return AttendanceStatus.holiday;
      default:
        return AttendanceStatus.absent;
    }
  }

  String get statusString {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.holiday:
        return 'Holiday';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.late:
        return Colors.orange;
      case AttendanceStatus.halfDay:
        return Colors.blue;
      case AttendanceStatus.holiday:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle;
      case AttendanceStatus.absent:
        return Icons.cancel;
      case AttendanceStatus.late:
        return Icons.access_time;
      case AttendanceStatus.halfDay:
        return Icons.wb_sunny;
      case AttendanceStatus.holiday:
        return Icons.celebration;
      default:
        return Icons.help;
    }
  }

  // Check if student is currently checked in (not checked out)
  bool get isCurrentlyCheckedIn {
    if (checkInTime == null) return false;
    if (checkOutTime != null) return false;
    return true;
  }

  // Calculate duration between check-in and check-out
  Duration? get duration {
    if (checkInTime == null || checkOutTime == null) return null;
    return checkOutTime!.toDate().difference(checkInTime!.toDate());
  }

  // Format check-in time
  String get formattedCheckInTime {
    if (checkInTime == null) return '--:--';
    final date = checkInTime!.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Format check-out time
  String get formattedCheckOutTime {
    if (checkOutTime == null) return '--:--';
    final date = checkOutTime!.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Get full date string
  String get formattedDate {
    if (date == null) return 'Unknown';
    final dateTime = date!.toDate();
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // Get day of week
  String get dayOfWeek {
    if (date == null) return 'Unknown';
    final dateTime = date!.toDate();
    switch (dateTime.weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  // Check if attendance is for today
  bool get isToday {
    if (date == null) return false;
    final now = DateTime.now();
    final attendanceDate = date!.toDate();
    return attendanceDate.year == now.year &&
        attendanceDate.month == now.month &&
        attendanceDate.day == now.day;
  }

  // Get location string
  String get locationString {
    if (checkInLocation == null) return 'Location not available';
    return '${checkInLocation!.latitude.toStringAsFixed(4)}, ${checkInLocation!.longitude.toStringAsFixed(4)}';
  }

  // Check if within working hours (assuming 9-5)
  bool get isWithinWorkingHours {
    if (checkInTime == null) return false;
    final hour = checkInTime!.toDate().hour;
    return hour >= 9 && hour <= 17;
  }

  // Calculate late minutes (if check-in after 9:30 AM)
  int get lateMinutes {
    if (checkInTime == null) return 0;
    final checkIn = checkInTime!.toDate();
    final nineThirty = DateTime(checkIn.year, checkIn.month, checkIn.day, 9, 30);
    
    if (checkIn.isAfter(nineThirty)) {
      return checkIn.difference(nineThirty).inMinutes;
    }
    return 0;
  }

  // Check if marked as late
  bool get isLate {
    return status == AttendanceStatus.late || lateMinutes > 0;
  }

  // Get working hours as formatted string
  String get workingHoursString {
    if (workingHours == null) return '0.0 hrs';
    return '${workingHours!.toStringAsFixed(1)} hrs';
  }

  // Get overtime hours as formatted string
  String get overtimeHoursString {
    if (overtimeHours == null || overtimeHours == 0) return 'No overtime';
    return '${overtimeHours!.toStringAsFixed(1)} hrs overtime';
  }

  // Get method icon
  IconData get methodIcon {
    if (checkInMethod == 'qr') return Icons.qr_code;
    if (checkInMethod == 'gps') return Icons.gps_fixed;
    return Icons.person;
  }

  // Get method color
  Color get methodColor {
    if (checkInMethod == 'qr') return Colors.purple;
    if (checkInMethod == 'gps') return Colors.blue;
    return Colors.orange;
  }
}