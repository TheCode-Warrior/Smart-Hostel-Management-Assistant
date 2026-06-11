import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum RoomStatus { available, occupied, maintenance, cleaning }

class RoomModel {
  String? id;
  String? roomNumber;
  String? hostelBlock; // 'A', 'B', 'C', 'D'
  int? floor;
  String? roomType; // 'single', 'double', 'triple', 'dormitory'
  int? capacity;
  int? currentOccupancy;
  bool? isAvailable;
  double? monthlyRent;
  List<String>? amenities;
  RoomStatus? status;
  Timestamp? lastMaintained;
  Timestamp? nextMaintenanceDue;
  List<Map<String, dynamic>>? occupants; // List of student allocations
  Map<String, dynamic>? features;

  RoomModel({
    this.id,
    this.roomNumber,
    this.hostelBlock,
    this.floor,
    this.roomType,
    this.capacity,
    this.currentOccupancy,
    this.isAvailable,
    this.monthlyRent,
    this.amenities,
    this.status,
    this.lastMaintained,
    this.nextMaintenanceDue,
    this.occupants,
    this.features,
  });

  Map<String, dynamic> toMap() {
    return {
      'roomNumber': roomNumber,
      'hostelBlock': hostelBlock,
      'floor': floor ?? 1,
      'roomType': roomType ?? 'double',
      'capacity': capacity ?? 2,
      'currentOccupancy': currentOccupancy ?? 0,
      'isAvailable': isAvailable ?? true,
      'monthlyRent': monthlyRent ?? 0.0,
      'amenities': amenities ?? [],
      'status': status?.toString().split('.').last ?? 'available',
      'lastMaintained': lastMaintained,
      'nextMaintenanceDue': nextMaintenanceDue,
      'occupants': occupants ?? [],
      'features': features ?? {},
    };
  }

  factory RoomModel.fromMap(Map<String, dynamic> map, String id) {
    return RoomModel(
      id: id,
      roomNumber: map['roomNumber'],
      hostelBlock: map['hostelBlock'],
      floor: map['floor'],
      roomType: map['roomType'],
      capacity: map['capacity'],
      currentOccupancy: map['currentOccupancy'],
      isAvailable: map['isAvailable'],
      monthlyRent: (map['monthlyRent'] ?? 0.0).toDouble(),
      amenities: List<String>.from(map['amenities'] ?? []),
      status: _stringToStatus(map['status']),
      lastMaintained: map['lastMaintained'],
      nextMaintenanceDue: map['nextMaintenanceDue'],
      occupants: List<Map<String, dynamic>>.from(map['occupants'] ?? []),
      features: map['features'],
    );
  }

  static RoomStatus _stringToStatus(String? status) {
    switch (status) {
      case 'available':
        return RoomStatus.available;
      case 'occupied':
        return RoomStatus.occupied;
      case 'maintenance':
        return RoomStatus.maintenance;
      case 'cleaning':
        return RoomStatus.cleaning;
      default:
        return RoomStatus.available;
    }
  }

  String get statusString {
    switch (status) {
      case RoomStatus.available:
        return 'Available';
      case RoomStatus.occupied:
        return 'Occupied';
      case RoomStatus.maintenance:
        return 'Maintenance';
      case RoomStatus.cleaning:
        return 'Cleaning';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case RoomStatus.available:
        return Colors.green;
      case RoomStatus.occupied:
        return Colors.red;
      case RoomStatus.maintenance:
        return Colors.orange;
      case RoomStatus.cleaning:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String get roomTypeString {
    switch (roomType) {
      case 'single':
        return 'Single Occupancy';
      case 'double':
        return 'Double Occupancy';
      case 'triple':
        return 'Triple Occupancy';
      case 'dormitory':
        return 'Dormitory';
      default:
        return 'Standard';
    }
  }

  int get availableBeds {
    return (capacity ?? 0) - (currentOccupancy ?? 0);
  }

  bool get hasVacancy {
    return availableBeds > 0;
  }

  double get occupancyRate {
    if (capacity == null || capacity == 0) return 0;
    return (currentOccupancy ?? 0) / capacity!;
  }

  List<String> get occupantIds {
    return occupants?.map((o) => o['studentId'] as String).toList() ?? [];
  }

  bool hasOccupant(String studentId) {
    return occupantIds.contains(studentId);
  }

  Map<String, dynamic>? getOccupantDetails(String studentId) {
    return occupants?.firstWhere(
      (o) => o['studentId'] == studentId,
      orElse: () => null as Map<String, dynamic>,
    );
  }

  String get roomDisplayName {
    return 'Room $roomNumber (Block $hostelBlock)';
  }

  String get location {
    return 'Block $hostelBlock, Floor $floor';
  }

  bool get needsMaintenance {
    if (nextMaintenanceDue == null) return false;
    return nextMaintenanceDue!.toDate().isBefore(DateTime.now());
  }

  int get daysSinceLastMaintenance {
    if (lastMaintained == null) return 0;
    return DateTime.now().difference(lastMaintained!.toDate()).inDays;
  }
}