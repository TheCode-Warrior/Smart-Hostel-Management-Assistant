import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class RoomProvider extends ChangeNotifier {
  List<RoomModel> _rooms = [];
  RoomModel? _currentRoom;
  Map<String, dynamic> _roomStats = {};
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  List<RoomModel> get rooms => _rooms;
  RoomModel? get currentRoom => _currentRoom;
  Map<String, dynamic> get roomStats => _roomStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Load all rooms
  Future<void> loadAllRooms() async {
    if (_isDisposed) return;
    _setLoading(true);
    try {
      final roomsData = await FirestoreService.queryDocuments(
        collection: 'rooms',
        orderBy: ['roomNumber'],
        descending: false,
      );
      
      _rooms = roomsData
          .map((r) => RoomModel.fromMap(r, r['id']))
          .toList();
      
      calculateStats();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load rooms by block
  Future<void> loadRoomsByBlock(String block) async {
    if (_isDisposed) return;
    _setLoading(true);
    try {
      final roomsData = await FirestoreService.queryDocuments(
        collection: 'rooms',
        field: 'hostelBlock',
        isEqualTo: block,
      );
      
      _rooms = roomsData
          .map((r) => RoomModel.fromMap(r, r['id']))
          .toList();
      
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load available rooms
  Future<void> loadAvailableRooms() async {
    if (_isDisposed) return;
    _setLoading(true);
    try {
      final roomsData = await FirestoreService.queryDocuments(
        collection: 'rooms',
        field: 'isAvailable',
        isEqualTo: true,
      );
      
      _rooms = roomsData
          .map((r) => RoomModel.fromMap(r, r['id']))
          .toList();
      
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load room by ID
  Future<void> loadRoomById(String roomId) async {
    if (_isDisposed) return;
    _setLoading(true);
    try {
      final roomData = await FirestoreService.readDocument(
        collection: 'rooms',
        documentId: roomId,
      );
      
      if (roomData != null) {
        _currentRoom = RoomModel.fromMap(roomData, roomId);
      }
      
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Add new room
  Future<bool> addRoom(RoomModel room) async {
    if (_isDisposed) return false;
    _setLoading(true);
    try {
      await FirestoreService.createDocument(
        collection: 'rooms',
        data: room.toMap(),
      );
      
      await loadAllRooms();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Update room
  Future<bool> updateRoom(String roomId, Map<String, dynamic> updates) async {
    if (_isDisposed) return false;
    _setLoading(true);
    try {
      await FirestoreService.updateDocument(
        collection: 'rooms',
        documentId: roomId,
        updates: updates,
      );
      
      await loadRoomById(roomId);
      await loadAllRooms();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Delete room
  Future<bool> deleteRoom(String roomId) async {
    if (_isDisposed) return false;
    _setLoading(true);
    try {
      await FirestoreService.deleteDocument(
        collection: 'rooms',
        documentId: roomId,
      );
      
      await loadAllRooms();
      if (_currentRoom?.id == roomId) {
        _currentRoom = null;
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Allocate room to student
  Future<bool> allocateRoom({
    required String roomId,
    required String studentId,
    required String allocatedBy,
    String? bedNumber,
  }) async {
    if (_isDisposed) return false;
    _setLoading(true);
    try {
      final room = _rooms.firstWhere((r) => r.id == roomId);
      
      if (room.currentOccupancy! >= room.capacity!) {
        _errorMessage = 'Room is full';
        _setLoading(false);
        return false;
      }

      // Add occupant
      List<Map<String, dynamic>> updatedOccupants = List.from(room.occupants ?? []);
      updatedOccupants.add({
        'studentId': studentId,
        'allocatedAt': Timestamp.now(),
        'allocatedBy': allocatedBy,
        'bedNumber': bedNumber ?? 'Bed ${room.currentOccupancy! + 1}',
        'isPrimary': updatedOccupants.isEmpty,
      });

      final newOccupancy = room.currentOccupancy! + 1;
      final isStillAvailable = newOccupancy < room.capacity!;

      await updateRoom(roomId, {
        'occupants': updatedOccupants,
        'currentOccupancy': newOccupancy,
        'isAvailable': isStillAvailable,
        'status': newOccupancy == room.capacity! ? 'occupied' : 'available',
      });

      // Update student's room
      await FirestoreService.updateDocument(
        collection: 'students',
        documentId: studentId,
        updates: {
          'roomId': roomId,
          'roomNumber': room.roomNumber,
          'allocatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Send notification to student
      await NotificationService.sendNotification(
        title: '🏠 Room Allocated',
        body: 'You have been allocated Room ${room.roomNumber} (Block ${room.hostelBlock})',
        userId: studentId,
        type: 'room_allocation',
        data: {
          'roomId': roomId,
          'roomNumber': room.roomNumber,
          'block': room.hostelBlock,
        },
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Deallocate room from student
  Future<bool> deallocateRoom(String roomId, String studentId) async {
    if (_isDisposed) return false;
    _setLoading(true);
    try {
      final room = _rooms.firstWhere((r) => r.id == roomId);
      
      List<Map<String, dynamic>> updatedOccupants = List.from(room.occupants ?? []);
      updatedOccupants.removeWhere((o) => o['studentId'] == studentId);

      final newOccupancy = (room.currentOccupancy ?? 0) - 1;
      final isAvailable = newOccupancy < (room.capacity ?? 0);

      await updateRoom(roomId, {
        'occupants': updatedOccupants,
        'currentOccupancy': newOccupancy,
        'isAvailable': isAvailable,
        'status': newOccupancy == 0 ? 'available' : 'occupied',
      });

      // Remove room from student
      await FirestoreService.updateDocument(
        collection: 'students',
        documentId: studentId,
        updates: {
          'roomId': null,
          'roomNumber': null,
          'deallocatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Send notification to student
      await NotificationService.sendNotification(
        title: '🏠 Room Deallocated',
        body: 'You have been deallocated from Room ${room.roomNumber}',
        userId: studentId,
        type: 'room_deallocation',
        data: {
          'roomId': roomId,
          'roomNumber': room.roomNumber,
        },
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Get available rooms count
  int getAvailableRoomsCount() {
    return _rooms.where((r) => r.isAvailable == true).length;
  }

  // Calculate room statistics
  void calculateStats() {
    int total = _rooms.length;
    int available = _rooms.where((r) => r.isAvailable == true).length;
    int occupied = _rooms.where((r) => r.status == RoomStatus.occupied).length;
    int maintenance = _rooms.where((r) => r.status == RoomStatus.maintenance).length;
    
    int totalCapacity = _rooms.fold(0, (sum, room) => sum + (room.capacity ?? 0));
    int totalOccupancy = _rooms.fold(0, (sum, room) => sum + (room.currentOccupancy ?? 0));
    
    _roomStats = {
      'total': total,
      'available': available,
      'occupied': occupied,
      'maintenance': maintenance,
      'totalCapacity': totalCapacity,
      'totalOccupancy': totalOccupancy,
      'occupancyRate': totalCapacity > 0 
          ? (totalOccupancy / totalCapacity * 100) 
          : 0,
    };
    
    _safeNotify();
  }

  // Search rooms
  List<RoomModel> searchRooms(String query) {
    if (query.isEmpty) return _rooms;
    
    final lowerQuery = query.toLowerCase();
    return _rooms.where((room) {
      return (room.roomNumber?.toLowerCase().contains(lowerQuery) ?? false) ||
          (room.hostelBlock?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
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