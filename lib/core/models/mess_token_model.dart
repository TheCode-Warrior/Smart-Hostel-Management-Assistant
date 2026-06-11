import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType { breakfast, lunch, dinner }
enum TokenStatus { active, used, expired, skipped }

class MessTokenModel {
  String? id;
  String? studentId;
  String? studentName;
  String? tokenCode;
  MealType? mealType;
  Timestamp? mealDate;
  Timestamp? validFrom;
  Timestamp? validUntil;
  bool? isUsed;
  Timestamp? usedAt;
  String? usedBy; // staffId
  String? scannedAtLocation;
  String? qrData;
  String? generatedBy;
  TokenStatus? status;
  String? mealCycle;

  MessTokenModel({
    this.id,
    this.studentId,
    this.studentName,
    this.tokenCode,
    this.mealType,
    this.mealDate,
    this.validFrom,
    this.validUntil,
    this.isUsed,
    this.usedAt,
    this.usedBy,
    this.scannedAtLocation,
    this.qrData,
    this.generatedBy,
    this.status,
    this.mealCycle,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'tokenCode': tokenCode,
      'mealType': mealType?.toString().split('.').last,
      'mealDate': mealDate,
      'validFrom': validFrom,
      'validUntil': validUntil,
      'isUsed': isUsed ?? false,
      'usedAt': usedAt,
      'usedBy': usedBy,
      'scannedAtLocation': scannedAtLocation,
      'qrData': qrData,
      'generatedBy': generatedBy,
      'status': status?.toString().split('.').last ?? 'active',
      'mealCycle': mealCycle,
    };
  }

  factory MessTokenModel.fromMap(Map<String, dynamic> map, String id) {
    return MessTokenModel(
      id: id,
      studentId: map['studentId'],
      studentName: map['studentName'],
      tokenCode: map['tokenCode'],
      mealType: _stringToMealType(map['mealType']),
      mealDate: map['mealDate'],
      validFrom: map['validFrom'],
      validUntil: map['validUntil'],
      isUsed: map['isUsed'],
      usedAt: map['usedAt'],
      usedBy: map['usedBy'],
      scannedAtLocation: map['scannedAtLocation'],
      qrData: map['qrData'],
      generatedBy: map['generatedBy'],
      status: _stringToTokenStatus(map['status']),
      mealCycle: map['mealCycle'],
    );
  }

  static MealType _stringToMealType(String? type) {
    switch (type) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      default:
        return MealType.lunch;
    }
  }

  static TokenStatus _stringToTokenStatus(String? status) {
    switch (status) {
      case 'active':
        return TokenStatus.active;
      case 'used':
        return TokenStatus.used;
      case 'expired':
        return TokenStatus.expired;
      case 'skipped':
        return TokenStatus.skipped;
      default:
        return TokenStatus.active;
    }
  }

  String get mealTypeString {
    switch (mealType) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      default:
        return 'Unknown';
    }
  }

  String get statusString {
    switch (status) {
      case TokenStatus.active:
        return 'Active';
      case TokenStatus.used:
        return 'Used';
      case TokenStatus.expired:
        return 'Expired';
      case TokenStatus.skipped:
        return 'Skipped';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case TokenStatus.active:
        return Colors.green;
      case TokenStatus.used:
        return Colors.blue;
      case TokenStatus.expired:
        return Colors.red;
      case TokenStatus.skipped:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  bool get isValid {
    if (isUsed == true) return false;
    if (status != TokenStatus.active) return false;
    
    DateTime now = DateTime.now();
    DateTime from = validFrom?.toDate() ?? DateTime.now();
    DateTime until = validUntil?.toDate() ?? DateTime.now();
    
    return now.isAfter(from) && now.isBefore(until);
  }
}