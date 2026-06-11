import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/student_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/room_model.dart';

class StudentRoomScreen extends StatefulWidget {
  const StudentRoomScreen({Key? key}) : super(key: key);

  @override
  _StudentRoomScreenState createState() => _StudentRoomScreenState();
}

class _StudentRoomScreenState extends State<StudentRoomScreen> {
  RoomModel? _myRoom;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMyRoom();
  }

  Future<void> _loadMyRoom() async {
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    
    final studentId = authProvider.user?.uid;
    if (studentId == null) {
      setState(() {
        _errorMessage = 'User not found';
        _isLoading = false;
      });
      return;
    }

    try {
      // Load student details
      await studentProvider.loadStudentById(studentId);
      final student = studentProvider.currentStudent;
      
      if (student?.roomId != null && student?.roomId!.isNotEmpty == true) {
        // Load room details
        final roomDoc = await FirebaseFirestore.instance
            .collection('rooms')
            .doc(student!.roomId)
            .get();
        
        if (roomDoc.exists) {
          _myRoom = RoomModel.fromMap(
            roomDoc.data() as Map<String, dynamic>,
            roomDoc.id,
          );
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error loading room: $e');
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final studentProvider = Provider.of<StudentProvider>(context);
    final student = studentProvider.currentStudent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Room'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _myRoom == null
              ? _buildNoRoomState()
              : _buildRoomDetails(),
    );
  }

  Widget _buildNoRoomState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room, size: 80, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text(
            'No Room Allocated',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.grey700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have not been allocated a room yet.\nPlease contact the hostel administration.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomDetails() {
    final room = _myRoom!;
    final features = room.features ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Room ${room.roomNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    room.roomTypeString,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Room Details Card
          _buildInfoCard(
            'Room Details',
            Icons.info_outline,
            [
              _buildDetailRow('Room Number', room.roomNumber ?? 'N/A'),
              _buildDetailRow('Block', 'Block ${room.hostelBlock}'),
              _buildDetailRow('Floor', 'Floor ${room.floor}'),
              _buildDetailRow('Room Type', room.roomTypeString),
              _buildDetailRow('Monthly Rent', '₹${room.monthlyRent}'),
            ],
          ),
          const SizedBox(height: 16),

          // Features Card
          _buildInfoCard(
            'Room Features',
            Icons.cleaning_services,
            [
              _buildFeatureRow('Attached Washroom', features['attachedWashroom'] ?? false),
              _buildFeatureRow('Balcony', features['balcony'] ?? false),
              _buildFeatureRow('Air Conditioner', features['acAvailable'] ?? false),
              _buildFeatureRow('Ceiling Fan', features['fanAvailable'] ?? true),
              _buildFeatureRow('Water Geyser', features['geyserAvailable'] ?? false),
              _buildFeatureRow('WiFi', features['wifiAvailable'] ?? false),
              _buildDetailRow('Furnishing', _getFurnishingText(features['furnishing'] ?? 'none')),
            ],
          ),
          const SizedBox(height: 16),

          // Amenities Card
          if (room.amenities != null && room.amenities!.isNotEmpty)
            _buildInfoCard(
              'Amenities',
              Icons.star_outline,
              room.amenities!.map((amenity) => _buildDetailRow(amenity, '✓')).toList(),
            ),
          const SizedBox(height: 16),

          // Roommates Card (if any)
          if (room.occupants != null && room.occupants!.length > 1)
            _buildRoommatesCard(room),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
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
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.grey600)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String label, bool available) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.grey600)),
          Row(
            children: [
              Icon(
                available ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: available ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                available ? 'Available' : 'Not Available',
                style: TextStyle(
                  color: available ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoommatesCard(RoomModel room) {
    final occupants = room.occupants ?? [];
    // Filter out current user
    final authProvider = Provider.of<AuthProvider>(context);
    final roommates = occupants.where((o) => o['studentId'] != authProvider.user?.uid).toList();
    
    if (roommates.isEmpty) return const SizedBox();

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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.people, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Roommates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...roommates.map((roommate) {
            return FutureBuilder(
              future: _getStudentName(roommate['studentId']),
              builder: (context, snapshot) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      snapshot.data?.substring(0, 1).toUpperCase() ?? '?',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                  title: Text(snapshot.data ?? 'Loading...'),
                  subtitle: Text(roommate['bedNumber'] ?? 'Roommate'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      roommate['isPrimary'] == true ? 'Primary' : 'Secondary',
                      style: TextStyle(color: Colors.green, fontSize: 10),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<String> _getStudentName(String studentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();
      
      if (doc.exists) {
        return doc.data()?['fullName'] ?? 'Unknown Student';
      }
      return 'Unknown Student';
    } catch (e) {
      return 'Unknown Student';
    }
  }

  String _getFurnishingText(String furnishing) {
    switch (furnishing) {
      case 'none': return 'No Furnishing';
      case 'basic': return 'Basic Furnishing';
      case 'semi-furnished': return 'Semi-Furnished';
      case 'fully-furnished': return 'Fully Furnished';
      default: return 'Not Specified';
    }
  }
}
