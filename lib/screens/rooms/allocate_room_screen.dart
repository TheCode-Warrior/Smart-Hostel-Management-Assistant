import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/room_provider.dart';
import '../../core/providers/student_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/room_model.dart';
import '../../core/models/student_model.dart';

class AllocateRoomScreen extends StatefulWidget {
  final String? roomId;
  final String? studentId;

  const AllocateRoomScreen({
    Key? key,
    this.roomId,
    this.studentId,
  }) : super(key: key);

  @override
  _AllocateRoomScreenState createState() => _AllocateRoomScreenState();
}

class _AllocateRoomScreenState extends State<AllocateRoomScreen> {
  RoomModel? _selectedRoom;
  StudentModel? _selectedStudent;
  String? _selectedBedNumber;
  
  List<RoomModel> _availableRooms = [];
  List<StudentModel> _availableStudents = [];
  
  bool _isLoading = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);

    // Load available rooms (with vacancy)
    await roomProvider.loadAllRooms();
    _availableRooms = roomProvider.rooms.where((r) => 
      r.isAvailable == true && r.hasVacancy && r.status != RoomStatus.maintenance
    ).toList();

    // Load students without rooms
    await studentProvider.loadAllStudents();
    _availableStudents = studentProvider.students.where((s) => 
      s.roomId == null && s.isVerified == true
    ).toList();

    // Pre-select if IDs provided
    if (widget.roomId != null) {
      _selectedRoom = _availableRooms.firstWhere(
        (r) => r.id == widget.roomId,
        orElse: () => null as RoomModel,
      );
    }

    if (widget.studentId != null) {
      _selectedStudent = _availableStudents.firstWhere(
        (s) => s.id == widget.studentId,
        orElse: () => null as StudentModel,
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _allocateRoom() async {
    if (_selectedRoom == null || _selectedStudent == null) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    final success = await roomProvider.allocateRoom(
      roomId: _selectedRoom!.id!,
      studentId: _selectedStudent!.id!,
      allocatedBy: authProvider.user!.uid!,
      bedNumber: _selectedBedNumber,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room allocated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(roomProvider.errorMessage ?? 'Failed to allocate room'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedRoom != null) {
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1 && _selectedStudent != null) {
      setState(() => _currentStep = 2);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allocate Room'),
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
          : Column(
              children: [
                // Step Indicator
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _buildStepIndicator(0, 'Select Room'),
                      Expanded(child: Divider(color: AppColors.grey300, thickness: 2)),
                      _buildStepIndicator(1, 'Select Student'),
                      Expanded(child: Divider(color: AppColors.grey300, thickness: 2)),
                      _buildStepIndicator(2, 'Confirm'),
                    ],
                  ),
                ),

                // Step Content
                Expanded(
                  child: _buildStepContent(),
                ),

                // Navigation Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousStep,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Previous'),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: _currentStep == 2 ? 'Allocate Room' : 'Next',
                          onPressed: _currentStep == 2 ? _allocateRoom : _nextStep,
                          isLoading: _isLoading,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isCompleted = step < _currentStep;
    final isCurrent = step == _currentStep;
    
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green
                : (isCurrent ? AppColors.primary : AppColors.grey300),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : AppColors.grey700,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isCurrent ? AppColors.primary : AppColors.grey600,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildRoomSelection();
      case 1:
        return _buildStudentSelection();
      case 2:
        return _buildConfirmation();
      default:
        return Container();
    }
  }

  Widget _buildRoomSelection() {
    if (_availableRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.meeting_room, size: 60, color: AppColors.grey400),
            const SizedBox(height: 16),
            Text(
              'No Available Rooms',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'There are no rooms with vacancy available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableRooms.length,
      itemBuilder: (context, index) {
        final room = _availableRooms[index];
        final isSelected = _selectedRoom?.id == room.id;
        final occupancyText = '${room.currentOccupancy}/${room.capacity}';
        final vacancyCount = room.availableBeds;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: AppColors.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedRoom = isSelected ? null : room;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.meeting_room, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room ${room.roomNumber}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Block ${room.hostelBlock} | Floor ${room.floor} | ${room.roomTypeString}',
                          style: TextStyle(color: AppColors.grey600, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          children: [
                            _buildInfoChip(
                              Icons.people,
                              occupancyText,
                              isFull: room.currentOccupancy == room.capacity,
                            ),
                            _buildInfoChip(
                              Icons.bed,
                              '$vacancyCount bed${vacancyCount > 1 ? 's' : ''} left',
                            ),
                            _buildInfoChip(
                              Icons.currency_rupee,
                              '₹${room.monthlyRent}/month',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: AppColors.primary, size: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {bool isFull = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFull ? Colors.red.withOpacity(0.1) : AppColors.grey100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isFull ? Colors.red : AppColors.grey600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isFull ? Colors.red : AppColors.grey700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSelection() {
    if (_availableStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 60, color: AppColors.grey400),
            const SizedBox(height: 16),
            Text(
              'No Students Available',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'All verified students already have rooms allocated.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableStudents.length,
      itemBuilder: (context, index) {
        final student = _availableStudents[index];
        final isSelected = _selectedStudent?.id == student.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? BorderSide(color: AppColors.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedStudent = isSelected ? null : student;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      student.fullName?[0] ?? '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enroll: ${student.enrollmentNo ?? 'N/A'}',
                          style: TextStyle(color: AppColors.grey600, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${student.course ?? 'N/A'} - Semester ${student.semester ?? 'N/A'}',
                          style: TextStyle(color: AppColors.grey600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: AppColors.primary, size: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmation() {
    if (_selectedRoom == null || _selectedStudent == null) {
      return const Center(
        child: Text('Please complete previous steps'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Room Details Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grey200),
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
                    Icon(Icons.meeting_room, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Selected Room',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildConfirmRow('Room Number', _selectedRoom!.roomNumber ?? ''),
                _buildConfirmRow('Block', 'Block ${_selectedRoom!.hostelBlock}'),
                _buildConfirmRow('Floor', 'Floor ${_selectedRoom!.floor}'),
                _buildConfirmRow('Type', _selectedRoom!.roomTypeString),
                _buildConfirmRow('Rent', '₹${_selectedRoom!.monthlyRent}/month'),
                _buildConfirmRow('Bed', '${_selectedRoom!.availableBeds} available'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Student Details Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grey200),
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
                    Icon(Icons.person, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Selected Student',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildConfirmRow('Name', _selectedStudent!.fullName ?? ''),
                _buildConfirmRow('Enrollment', _selectedStudent!.enrollmentNo ?? ''),
                _buildConfirmRow('Course', _selectedStudent!.course ?? ''),
                _buildConfirmRow('Semester', 'Semester ${_selectedStudent!.semester ?? 'N/A'}'),
                _buildConfirmRow('Email', _selectedStudent!.email ?? 'N/A'),
                _buildConfirmRow('Phone', _selectedStudent!.phoneNumber ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bed Number (Optional)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grey200),
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
                    Icon(Icons.bed, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Bed Number (Optional)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter bed number (e.g., Bed 1, Bed A)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.grey100,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedBedNumber = value.isNotEmpty ? value : null;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'If not specified, bed number will be auto-assigned.',
                  style: TextStyle(color: AppColors.grey600, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.grey600, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}