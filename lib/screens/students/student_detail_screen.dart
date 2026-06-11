import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/student_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/room_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/models/student_model.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;

  const StudentDetailScreen({
    Key? key,
    required this.studentId,
  }) : super(key: key);

  @override
  _StudentDetailScreenState createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    await studentProvider.loadStudentById(widget.studentId);
  }

  Future<void> _verifyStudent() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);

    bool success = await studentProvider.verifyStudent(
      widget.studentId,
      authProvider.user!.uid!,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student verified successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = Provider.of<StudentProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final student = studentProvider.currentStudent;
    
    if (student == null) {
      return const Scaffold(
        body: Center(child: Text('Student not found')),
      );
    }

    final bool canEdit = authProvider.user?.roleString == 'Admin' || 
                         authProvider.user?.roleString == 'Mess Staff';

    return Scaffold(
      appBar: AppBar(
        title: Text(student.fullName ?? 'Student Details'),
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
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.editStudent,
                  arguments: student.id,
                ).then((_) => _loadData());
              },
            ),
            if (student.isVerified != true)
              IconButton(
                icon: const Icon(Icons.verified, color: Colors.green),
                onPressed: _verifyStudent,
                tooltip: 'Verify Student',
              ),
          ],
        ],
      ),
      body: studentProvider.isLoading
          ? const LoadingIndicator()
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  _buildProfileHeader(student),
                  
                  TabBar(
                    tabs: const [
                      Tab(text: 'Personal Info'),
                      Tab(text: 'Academic Info'),
                      Tab(text: 'Documents'),
                    ],
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.grey600,
                    indicatorColor: AppColors.primary,
                    onTap: (index) {
                      setState(() => _selectedTab = index);
                    },
                  ),
                  
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildPersonalInfo(student),
                        _buildAcademicInfo(student),
                        _buildDocuments(student),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(StudentModel student) {
    final isVerified = student.isVerified == true;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isVerified ? Colors.green : Colors.orange,
                width: 3,
              ),
            ),
            child: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: student.profileImage != null
                  ? NetworkImage(student.profileImage!)
                  : null,
              child: student.profileImage == null
                  ? Text(
                      student.fullName?[0] ?? '?',
                      style: TextStyle(
                        fontSize: 32,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        student.fullName ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerified ? Icons.verified : Icons.pending,
                            size: 14,
                            color: isVerified ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? 'Verified' : 'Pending',
                            style: TextStyle(
                              color: isVerified ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Enrollment: ${student.enrollmentNo ?? 'N/A'}',
                  style: TextStyle(color: AppColors.grey600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.meeting_room, size: 16, color: AppColors.grey500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        student.roomNumber ?? 'Room not allocated',
                        style: TextStyle(
                          color: student.roomId != null && student.roomId!.isNotEmpty
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(StudentModel student) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            'Contact Information',
            [
              _buildInfoRow(Icons.email, 'Email', student.email ?? 'N/A', onTap: () => _sendEmail(student.email ?? '')),
              _buildInfoRow(Icons.phone, 'Phone', student.phoneNumber ?? 'N/A', onTap: () => _makePhoneCall(student.phoneNumber ?? '')),
              _buildInfoRow(Icons.people, 'Parent Name', student.parentName ?? 'N/A'),
              _buildInfoRow(Icons.phone, 'Parent Phone', student.parentPhone ?? 'N/A', onTap: () => _makePhoneCall(student.parentPhone ?? '')),
              _buildInfoRow(Icons.email, 'Parent Email', student.parentEmail ?? 'N/A', onTap: () => _sendEmail(student.parentEmail ?? '')),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Address',
            [
              _buildInfoRow(Icons.location_on, 'Address', student.fullAddress),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Emergency & Medical',
            [
              _buildInfoRow(Icons.emergency, 'Emergency Contact', student.emergencyContact ?? 'N/A', onTap: () => _makePhoneCall(student.emergencyContact ?? '')),
              _buildInfoRow(Icons.bloodtype, 'Blood Group', student.bloodGroup ?? 'N/A'),
              _buildInfoRow(Icons.medical_services, 'Medical Conditions', student.medicalConditions ?? 'None'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicInfo(StudentModel student) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(
            'Academic Details',
            [
              _buildInfoRow(Icons.school, 'Course', student.course ?? 'N/A'),
              _buildInfoRow(Icons.format_list_numbered, 'Semester', '${student.semester ?? 'N/A'}'),
              _buildInfoRow(Icons.group, 'Batch', student.batch ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Hostel Information',
            [
              _buildInfoRow(Icons.meeting_room, 'Room Number', student.roomNumber ?? 'Not allocated'),
              _buildInfoRow(Icons.person, 'Room ID', student.roomId ?? 'N/A'),
              _buildInfoRow(Icons.receipt_long, 'Fee Records', _feeRecordLabel(student)),
              _buildInfoRow(Icons.apartment, 'Hostel Semester',
                  student.hostelSemesterFeeSelected == true ? 'Selected' : 'Not selected',
                  color: student.hostelSemesterFeeSelected == true ? Colors.green : Colors.orange),
              _buildInfoRow(Icons.restaurant, 'Mess Monthly',
                  student.messMonthlyFeeSelected == true ? (student.isMessFeeValid ? 'Selected / Paid' : 'Selected / Pending') : 'Not selected',
                  color: student.messMonthlyFeeSelected == true
                      ? (student.isMessFeeValid ? Colors.green : Colors.orange)
                      : Colors.grey),
              _buildInfoRow(Icons.payment, 'Fine Amount', '₹${student.fineAmount?.toStringAsFixed(2) ?? '0.00'}'),
            ],
          ),
          const SizedBox(height: 16),
          
          // Allocate Room Button (only if no room and can edit)
          if ((student.roomId == null || student.roomId!.isEmpty) && 
              (student.isVerified == true))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CustomButton(
                text: 'Allocate Room',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.allocateRoom,
                    arguments: {
                      'roomId': null,
                      'studentId': student.id,
                    },
                  ).then((_) => _loadData());
                },
                icon: Icons.meeting_room,
              ),
            ),
          
          // Show message if student not verified
          if (student.isVerified != true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Student needs to be verified before room allocation.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocuments(StudentModel student) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDocumentCard(
            'Identity Proof',
            student.documents?['idProof'],
            Icons.badge,
          ),
          const SizedBox(height: 12),
          
          _buildDocumentCard(
            'Fee Receipt',
            student.documents?['feeReceipt'],
            Icons.receipt,
          ),
          const SizedBox(height: 12),
          
          if (student.documents?['photos'] != null)
            _buildPhotoGallery(
              (student.documents!['photos'] ?? '').split(',').where((e) => e.isNotEmpty).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.grey600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: AppColors.grey600, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new, size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  String _feeRecordLabel(StudentModel student) {
    final hostelSemester = student.hostelSemesterFeeSelected == true;
    final messMonthly = student.messMonthlyFeeSelected == true;

    if (hostelSemester && messMonthly) return 'Hostel Semester + Mess Monthly';
    if (hostelSemester) return 'Hostel Semester';
    if (messMonthly) return 'Mess Monthly';
    return 'No fee record';
  }

  Widget _buildDocumentCard(String title, String? url, IconData icon) {
    final hasDocument = url != null && url.isNotEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDocument ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasDocument ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: hasDocument ? Colors.green : Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  hasDocument ? 'Uploaded' : 'Not uploaded',
                  style: TextStyle(
                    color: hasDocument ? Colors.green : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (hasDocument)
            IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                // TODO: Show document viewer
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery(List<dynamic> photos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Student Photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.grey300),
                    image: DecorationImage(
                      image: NetworkImage(photos[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}