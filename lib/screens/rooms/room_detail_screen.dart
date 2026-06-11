import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/room_provider.dart';
import '../../core/providers/student_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/models/room_model.dart';
import '../../core/models/student_model.dart';
import '../../routes/app_routes.dart';

class RoomDetailScreen extends StatefulWidget {
  final String roomId;

  const RoomDetailScreen({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  _RoomDetailScreenState createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  Map<String, StudentModel> _occupantsMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    await roomProvider.loadRoomById(widget.roomId);
    
    // Load students in this room
    if (roomProvider.currentRoom?.occupants != null) {
      final studentProvider = Provider.of<StudentProvider>(context, listen: false);
      _occupantsMap.clear();
      for (var occupant in roomProvider.currentRoom!.occupants!) {
        await studentProvider.loadStudentById(occupant['studentId']);
        if (studentProvider.currentStudent != null) {
          _occupantsMap[occupant['studentId']] = studentProvider.currentStudent!;
        }
      }
      setState(() {});
    }
  }

  Future<void> _deallocateRoom(String studentId, String studentName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deallocate Room'),
        content: Text('Are you sure you want to remove $studentName from this room?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final roomProvider = Provider.of<RoomProvider>(context, listen: false);
              final success = await roomProvider.deallocateRoom(widget.roomId, studentId);
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Room deallocated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadData();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(roomProvider.errorMessage ?? 'Failed to deallocate'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deallocate'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRoomStatus(RoomStatus newStatus) async {
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    
    final updates = {
      'status': newStatus.toString().split('.').last,
      'isAvailable': newStatus == RoomStatus.available,
    };
    
    final success = await roomProvider.updateRoom(widget.roomId, updates);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Room status updated to ${newStatus.toString().split('.').last}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final room = roomProvider.currentRoom;
    
    if (roomProvider.isLoading) {
      return const Scaffold(body: LoadingIndicator());
    }
    
    if (room == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Room Details'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Room not found')),
      );
    }

    final canEdit = authProvider.user?.roleString == 'Admin' || 
                    authProvider.user?.roleString == 'Mess Staff';
    final isAvailable = room.isAvailable == true;
    final hasVacancy = room.hasVacancy;

    return Scaffold(
      appBar: AppBar(
        title: Text('Room ${room.roomNumber}'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        actions: [
          if (canEdit)
            PopupMenuButton<RoomStatus>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: _changeRoomStatus,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: RoomStatus.available,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Mark as Available'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: RoomStatus.occupied,
                  child: Row(
                    children: [
                      Icon(Icons.meeting_room, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Mark as Occupied'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: RoomStatus.maintenance,
                  child: Row(
                    children: [
                      Icon(Icons.build, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Mark for Maintenance'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: RoomStatus.cleaning,
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text('Mark for Cleaning'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(room),
            const SizedBox(height: 20),

            // Room Details
            _buildDetailsCard(room),
            const SizedBox(height: 20),

            // Occupants List
            _buildOccupantsCard(room),
            const SizedBox(height: 20),

            // Amenities
            _buildAmenitiesCard(room),
            const SizedBox(height: 20),

            // Action Buttons
            if (canEdit && isAvailable && hasVacancy)
              CustomButton(
                text: 'Allocate Room',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.allocateRoom,
                    arguments: {'roomId': room.id, 'studentId': null},
                  ).then((_) => _loadData());
                },
                icon: Icons.person_add,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(RoomModel room) {
    final statusColor = room.isAvailable == true
        ? Colors.green
        : (room.status == RoomStatus.maintenance ? Colors.orange : Colors.red);
    final occupancyText = '${room.currentOccupancy}/${room.capacity}';
    final isFull = room.currentOccupancy == room.capacity;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room ${room.roomNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Block ${room.hostelBlock} | Floor ${room.floor}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    room.statusString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                occupancyText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isFull ? 'Full' : 'Vacancy',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(RoomModel room) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Room Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.meeting_room, 'Room Type', room.roomTypeString),
          _buildDetailRow(Icons.currency_rupee, 'Monthly Rent', '₹${room.monthlyRent}'),
          _buildDetailRow(Icons.bed, 'Capacity', '${room.capacity} persons'),
          _buildDetailRow(Icons.people, 'Current Occupancy', '${room.currentOccupancy}'),
          if (room.lastMaintained != null)
            _buildDetailRow(
              Icons.build,
              'Last Maintained',
              _formatDate(room.lastMaintained!),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.grey600),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(color: AppColors.grey600)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupantsCard(RoomModel room) {
    final occupants = room.occupants ?? [];
    final hasOccupants = occupants.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.people, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Current Occupants',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (hasOccupants)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${occupants.length} Student${occupants.length > 1 ? 's' : ''}',
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!hasOccupants)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: AppColors.grey400),
                    const SizedBox(height: 8),
                    Text(
                      'No occupants',
                      style: TextStyle(color: AppColors.grey600),
                    ),
                    if (room.isAvailable == true)
                      const SizedBox(height: 4),
                    if (room.isAvailable == true)
                      Text(
                        'This room is available for allocation',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: occupants.length,
              itemBuilder: (context, index) {
                final occupant = occupants[index];
                final studentId = occupant['studentId'];
                final student = _occupantsMap[studentId];
                final isPrimary = occupant['isPrimary'] == true;
                final bedNumber = occupant['bedNumber'] ?? 'Bed ${index + 1}';
                final allocatedAt = occupant['allocatedAt'] as Timestamp?;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        student?.fullName?[0] ?? studentId[0].toUpperCase(),
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      student?.fullName ?? 'Loading...',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enroll: ${student?.enrollmentNo ?? 'N/A'}',
                          style: TextStyle(color: AppColors.grey600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                bedNumber,
                                style: TextStyle(color: Colors.blue, fontSize: 10),
                              ),
                            ),
                            if (isPrimary)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Primary',
                                  style: TextStyle(color: Colors.green, fontSize: 10),
                                ),
                              ),
                            if (allocatedAt != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Since ${_formatDateShort(allocatedAt)}',
                                  style: TextStyle(color: AppColors.primary, fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('View Details'),
                        ),
                        const PopupMenuItem(
                          value: 'deallocate',
                          child: Text('Deallocate', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'deallocate') {
                          _deallocateRoom(studentId, student?.fullName ?? 'Student');
                        } else if (value == 'view') {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.studentDetail,
                            arguments: studentId,
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesCard(RoomModel room) {
    final features = room.features ?? {};
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.cleaning_services, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Amenities & Features',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildAmenityChip('Attached Washroom', features['attachedWashroom'] ?? false),
              _buildAmenityChip('Balcony', features['balcony'] ?? false),
              _buildAmenityChip(
                'Furnishing',
                features['furnishing'] != 'none',
                customLabel: features['furnishing'] ?? 'None',
              ),
              _buildAmenityChip('AC', features['acAvailable'] ?? false),
              _buildAmenityChip('Fan', features['fanAvailable'] ?? false),
              _buildAmenityChip('Geyser', features['geyserAvailable'] ?? false),
              _buildAmenityChip('WiFi', features['wifiAvailable'] ?? false),
            ],
          ),
          if (room.amenities != null && room.amenities!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...room.amenities!.map((amenity) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(amenity, style: TextStyle(color: AppColors.grey700)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildAmenityChip(String label, bool available, {String? customLabel}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: available ? Colors.green.withOpacity(0.1) : AppColors.grey100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: available ? Colors.green : AppColors.grey300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: available ? Colors.green : AppColors.grey500,
          ),
          const SizedBox(width: 6),
          Text(
            customLabel ?? label,
            style: TextStyle(
              color: available ? Colors.green : AppColors.grey600,
              fontSize: 12,
              fontWeight: available ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateShort(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}