import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/models/user_model.dart';
import 'package:intl/intl.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedRole = 'All';
  String _selectedStatus = 'All';
  
  final List<String> _roles = ['All', 'Admin', 'Mess Staff', 'Student'];
  final List<String> _statuses = ['All', 'Active', 'Inactive'];

  String _roleToStorage(String role) {
    switch (role) {
      case 'Admin':
        return 'admin';
      case 'Mess Staff':
        return 'messStaff';
      case 'Student':
        return 'student';
      default:
        return role.toLowerCase();
    }
  }

  String _roleToDisplay(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'messstaff':
      case 'mess staff':
        return 'Mess Staff';
      case 'student':
        return 'Student';
      default:
        return role ?? 'Unknown';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final users = await FirestoreService.queryDocuments(
        collection: 'users',
        orderBy: ['createdAt'],
        descending: true,
      );
      
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredUsers() {
    return _users.where((user) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final name = user['fullName']?.toLowerCase() ?? '';
        final email = user['email']?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        if (!name.contains(query) && !email.contains(query)) {
          return false;
        }
      }
      
      // Role filter
      if (_selectedRole != 'All') {
        final role = user['role']?.toString() ?? '';
        if (role != _roleToStorage(_selectedRole)) {
          return false;
        }
      }
      
      // Status filter
      if (_selectedStatus != 'All') {
        final isActive = user['isActive'] == true;
        if (_selectedStatus == 'Active' && !isActive) return false;
        if (_selectedStatus == 'Inactive' && isActive) return false;
      }
      
      return true;
    }).toList();
  }

  void _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await FirestoreService.updateDocument(
        collection: 'users',
        documentId: userId,
        updates: {'isActive': !currentStatus},
      );
      
      if (!mounted) return;
      
      await _loadUsers();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    // Save parent context before showing dialog
    final parentContext = context;
    
    showDialog(
      context: parentContext,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_forever, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Delete User',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: const [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Are you sure you want to delete this user? This action cannot be undone.'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        Navigator.pop(dialogContext);

                        try {
                          await FirestoreService.deleteDocument(collection: 'users', documentId: userId);

                          if (!mounted) return;
                          await _loadUsers();
                          if (!mounted) return;

                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(content: Text('User deleted successfully'), backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetUserPassword(Map<String, dynamic> user) async {
    final parentContext = context;
    final email = (user['email'] ?? '').toString().trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(
          content: Text('Selected user does not have a valid email.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send password reset email to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (!mounted) return;
              this.setState(() => _isLoading = true);
              try {
                await AuthService.sendPasswordResetEmail(email);

                if (!mounted) return;
                this.setState(() => _isLoading = false);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text('Reset email sent to $email'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                this.setState(() => _isLoading = false);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send reset email: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

 void _showAddUserDialog() {
  final parentContext = context;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final enrollmentController = TextEditingController();
  final courseController = TextEditingController();
  String selectedRole = 'Student';
  String selectedSemester = '1';

  showDialog(
    context: parentContext,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogBuilderContext, dialogSetState) => AlertDialog(
        title: const Text('Add New User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              
              // ✅ Student-specific fields (only for Student role)
              if (selectedRole == 'Student') ...[
                TextField(
                  controller: enrollmentController,
                  decoration: const InputDecoration(
                    labelText: 'Enrollment Number',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 2024001',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: courseController,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., BCA, B.Tech',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSemester,
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    border: OutlineInputBorder(),
                  ),
                  items: ['1', '2', '3', '4', '5', '6', '7', '8']
                      .map((sem) => DropdownMenuItem(
                            value: sem,
                            child: Text('Semester $sem'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    dialogSetState(() {
                      selectedSemester = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
              ],
              
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: ['Admin', 'Mess Staff', 'Student']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(),
                onChanged: (value) {
                  dialogSetState(() {
                    selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  hintText: 'Enter a password for the user',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validation
              if (nameController.text.isEmpty || 
                  emailController.text.isEmpty || 
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              if (selectedRole == 'Student') {
                if (enrollmentController.text.isEmpty) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter enrollment number for student'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (courseController.text.isEmpty) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter course for student'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
              }

              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext);

              if (!mounted) return;
              setState(() => _isLoading = true);
              
              try {
                // Step 1: Create Firebase Auth User
                final createdUser = await AuthService.createUserByAdmin(
                  email: emailController.text.trim(),
                  password: passwordController.text.trim(),
                  fullName: nameController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                  role: _roleToStorage(selectedRole),
                );

                if (createdUser != null && mounted) {
                  // Step 2: ✅ If role is Student, create student record
                  if (selectedRole == 'Student') {
                    final studentData = {
                      'userId': createdUser.uid,
                      'fullName': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'phoneNumber': phoneController.text.trim(),
                      'enrollmentNo': enrollmentController.text.trim(),
                      'course': courseController.text.trim(),
                      'semester': int.tryParse(selectedSemester) ?? 1,
                      'batch': '${DateTime.now().year}-${DateTime.now().year + 4}',
                      'isVerified': true, // ✅ Auto-verified for room allocation
                      'verifiedBy': createdUser.uid,
                      'verifiedAt': FieldValue.serverTimestamp(),
                      'createdAt': FieldValue.serverTimestamp(),
                      'documents': {},
                      'messMonthlyFees': {},
                      'hostelSemesterFeeSelected': false,
                      'messMonthlyFeeSelected': false,
                      'fineAmount': 0,
                    };
                    
                    await FirebaseFirestore.instance
                        .collection('students')
                        .doc(createdUser.uid)
                        .set(studentData);
                  }
                  
                  setState(() => _isLoading = false);
                  
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text('${_roleToDisplay(createdUser.roleString)} user created successfully'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  await _loadUsers();
                } else {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to create user'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text('Error creating user: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Create User'),
          ),
        ],
      ),
    ),
  );
}
  void _showUserDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.88)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withOpacity(0.16),
                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['fullName'] ?? 'User Details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user['email'] ?? 'N/A',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildStatusChip(
                            user['isActive'] == true ? 'Active' : 'Inactive',
                            user['isActive'] == true ? Colors.green : Colors.red,
                            user['isActive'] == true ? Icons.check_circle : Icons.remove_circle,
                          ),
                          _buildStatusChip(
                            _roleToDisplay(user['role']?.toString()),
                            _getRoleColor(user['role']?.toString() ?? 'unknown'),
                            Icons.badge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDetailCard(
                        'Contact',
                        Icons.contact_mail,
                        [
                          _buildDetailRow('Phone', user['phoneNumber'] ?? 'N/A'),
                          _buildDetailRow('Email', user['email'] ?? 'N/A'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailCard(
                        'Account',
                        Icons.verified_user,
                        [
                          _buildDetailRow('Role', _roleToDisplay(user['role']?.toString())),
                          _buildDetailRow('Status', user['isActive'] == true ? 'Active' : 'Inactive'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailCard(
                        'Activity',
                        Icons.history,
                        [
                          _buildDetailRow(
                            'Member Since',
                            user['createdAt'] != null
                                ? DateFormat('dd MMM yyyy').format((user['createdAt'] as Timestamp).toDate())
                                : 'N/A',
                          ),
                          _buildDetailRow(
                            'Last Login',
                            user['lastLogin'] != null
                                ? DateFormat('dd MMM yyyy, hh:mm a').format((user['lastLogin'] as Timestamp).toDate())
                                : 'Never',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.grey600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();

    return Scaffold(
      appBar: AppBar(
          title: const Text('User Management'),
  centerTitle: true,
  elevation: 0,
  backgroundColor: AppColors.primary,
  titleTextStyle: const TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  ),
  // Custom back button
  leading: IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => Navigator.pop(context),
  ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,color: Colors.white),
            onPressed: _loadUsers,
          ),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: _showAddUserDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.grey100,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                
                // Filter Chips (Roles)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._roles.map((role) {
                        final isSelected = _selectedRole == role;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildCustomFilterChip(
                            label: role,
                            selected: isSelected,
                            onTap: () => setState(() => _selectedRole = isSelected ? 'All' : role),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._statuses.map((status) {
                        final isSelected = _selectedStatus == status;
                        final color = status == 'Active' ? Colors.green : Colors.red;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildCustomFilterChip(
                            label: status,
                            selected: isSelected,
                            color: color,
                            onTap: () => setState(() => _selectedStatus = isSelected ? 'All' : status),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Users: ${filteredUsers.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Active: ${filteredUsers.where((u) => u['isActive'] == true).length}',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading
                ? const LoadingIndicator()
                : filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return _buildUserCard(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    bool isActive = user['isActive'] == true;
    String role = user['role'] ?? 'unknown';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showUserDetails(user),
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(role).withOpacity(0.1),
          backgroundImage: user['profileImage'] != null
              ? NetworkImage(user['profileImage'])
              : null,
          child: user['profileImage'] == null
              ? Text(
                  user['fullName']?[0] ?? '?',
                  style: TextStyle(
                    color: _getRoleColor(role),
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          user['fullName'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? ''),
            Text(
              'Role: ${_roleToDisplay(role)}',
              style: TextStyle(
                color: _getRoleColor(role),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('View Details'),
                  onTap: () => _showUserDetails(user),
                ),
                PopupMenuItem(
                  child: Text(isActive ? 'Deactivate' : 'Activate'),
                  onTap: () => _toggleUserStatus(user['id'], isActive),
                ),
                PopupMenuItem(
                  child: Text('Reset Password'),
                  onTap: () => _resetUserPassword(user),
                ),
                PopupMenuItem(
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () => _deleteUser(user['id']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Users Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'No users match your search criteria',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final baseColor = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? baseColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? baseColor.withOpacity(0.9) : AppColors.grey200),
          boxShadow: selected
              ? [BoxShadow(color: baseColor.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.grey800,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'messstaff':
      case 'mess staff':
        return Colors.green;
      case 'student':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }
}