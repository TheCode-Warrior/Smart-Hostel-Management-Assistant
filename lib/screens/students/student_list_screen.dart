import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/student_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/student_model.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({Key? key}) : super(key: key);

  @override
  _StudentListScreenState createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Verified', 'Unverified', 'With Room', 'Without Room'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    await studentProvider.loadAllStudents();
    studentProvider.calculateStats();
  }

  List<StudentModel> _getFilteredStudents() {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    
    List<StudentModel> filtered = studentProvider.searchStudents(_searchQuery);
    
    switch (_selectedFilter) {
      case 'Verified':
        filtered = filtered.where((s) => s.isVerified == true).toList();
        break;
      case 'Unverified':
        filtered = filtered.where((s) => s.isVerified == false).toList();
        break;
      case 'With Room':
        filtered = filtered.where((s) => s.roomId != null && s.roomId!.isNotEmpty).toList();
        break;
      case 'Without Room':
        filtered = filtered.where((s) => s.roomId == null || s.roomId!.isEmpty).toList();
        break;
    }
    
    return filtered;
  }

  Future<void> _verifyStudent(StudentModel student) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    
    final success = await studentProvider.verifyStudent(student.id!, authProvider.user!.uid!);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.fullName} verified successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = Provider.of<StudentProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    bool canAddStudent = authProvider.user?.roleString == 'Admin' || 
                         authProvider.user?.roleString == 'Mess Staff';
    final filteredStudents = _getFilteredStudents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, enrollment, course...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              
              // Filter Chips
              Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedFilter = selected ? filter : 'All');
                        },
                        backgroundColor: Colors.white.withOpacity(0.2),
                        selectedColor: Colors.white,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () => _showStatsDialog(studentProvider.studentStats),
            tooltip: 'Statistics',
          ),
        ],
      ),
      body: studentProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: studentProvider.students.isEmpty
                  ? _buildEmptyState()
                  : filteredStudents.isEmpty
                      ? _buildNoResultsState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            return _buildStudentCard(student);
                          },
                        ),
            ),
      floatingActionButton: canAddStudent
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.addStudent).then((_) => _loadData());
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Add Student'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Widget _buildStudentCard(StudentModel student) {
    final isVerified = student.isVerified == true;
    final hasRoom = student.roomId != null && student.roomId!.isNotEmpty;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.studentDetail,
            arguments: student.id,
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Image / Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isVerified ? Colors.green : Colors.orange,
                    width: 2,
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
                            fontSize: 24,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Student Info
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
                              fontSize: 16,
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
                                size: 12,
                                color: isVerified ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isVerified ? 'Verified' : 'Pending',
                                style: TextStyle(
                                  color: isVerified ? Colors.green : Colors.orange,
                                  fontSize: 10,
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
                      'Enroll: ${student.enrollmentNo ?? 'N/A'}',
                      style: TextStyle(color: AppColors.grey600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.school, size: 14, color: AppColors.grey500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${student.course ?? 'N/A'} - Sem ${student.semester ?? 'N/A'}',
                            style: TextStyle(color: AppColors.grey700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(hasRoom ? Icons.meeting_room : Icons.room, size: 14, color: hasRoom ? Colors.green : Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          hasRoom ? student.roomNumber! : 'Room not allocated',
                          style: TextStyle(
                            color: hasRoom ? Colors.green : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isVerified)
                    IconButton(
                      icon: const Icon(Icons.verified, color: Colors.green),
                      onPressed: () => _verifyStudent(student),
                      tooltip: 'Verify Student',
                    ),
                  Icon(Icons.chevron_right, color: AppColors.grey400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text(
            'No Students Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'There are no students registered yet.\nTap the + button to add a new student.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text(
            'No Matching Students',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'No students match your search criteria.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog(Map<String, dynamic> stats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Student Statistics'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Students', '${stats['total'] ?? 0}'),
            const Divider(),
            _buildStatRow('Verified', '${stats['verified'] ?? 0}', color: Colors.green),
            _buildStatRow('Unverified', '${stats['unverified'] ?? 0}', color: Colors.orange),
            const Divider(),
            _buildStatRow('With Room', '${stats['withRoom'] ?? 0}', color: Colors.green),
            _buildStatRow('Without Room', '${stats['withoutRoom'] ?? 0}', color: Colors.red),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.grey700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}