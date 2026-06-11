import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/complaint_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';

class AssignComplaintScreen extends StatefulWidget {
  final String complaintId;

  const AssignComplaintScreen({
    Key? key,
    required this.complaintId,
  }) : super(key: key);

  @override
  _AssignComplaintScreenState createState() => _AssignComplaintScreenState();
}

class _AssignComplaintScreenState extends State<AssignComplaintScreen> {
  List<Map<String, dynamic>> _staffMembers = [];
  Map<String, dynamic>? _selectedStaff;
  bool _isLoading = false;
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);

    try {
      // Load caretakers and mess staff
      var caretakers = await FirestoreService.queryDocuments(
        collection: 'users',
        field: 'role',
        isEqualTo: 'caretaker',
      );

      var messStaff = await FirestoreService.queryDocuments(
        collection: 'users',
        field: 'role',
        isEqualTo: 'messStaff',
      );

      // Also load admins (they can also be assigned)
      var admins = await FirestoreService.queryDocuments(
        collection: 'users',
        field: 'role',
        isEqualTo: 'admin',
      );

      setState(() {
        _staffMembers = [...caretakers, ...messStaff, ...admins];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading staff: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredStaff() {
    if (_searchQuery == null || _searchQuery!.isEmpty) {
      return _staffMembers;
    }
    
    return _staffMembers.where((staff) {
      return staff['fullName']?.toLowerCase().contains(_searchQuery!.toLowerCase()) ??
          false ||
          staff['email']?.toLowerCase().contains(_searchQuery!.toLowerCase()) ??
          false;
    }).toList();
  }

  Future<void> _assignComplaint() async {
    if (_selectedStaff == null) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final complaintProvider = Provider.of<ComplaintProvider>(context, listen: false);

    final result = await complaintProvider.assignComplaint(
      complaintId: widget.complaintId,
      staffId: _selectedStaff!['id'],
      staffName: _selectedStaff!['fullName'],
      assignedBy: authProvider.user!.uid!,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complaint assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredStaff = _getFilteredStaff();

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Assign Complaint'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : Column(
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search staff by name...',
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
                ),

                // Staff List
                Expanded(
                  child: filteredStaff.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 60,
                                color: AppColors.grey400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No staff members found',
                                style: TextStyle(
                                  color: AppColors.grey600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredStaff.length,
                          itemBuilder: (context, index) {
                            final staff = filteredStaff[index];
                            final isSelected = _selectedStaff?['id'] == staff['id'];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                onTap: () {
                                  setState(() {
                                    _selectedStaff = isSelected ? null : staff;
                                  });
                                },
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? AppColors.primary
                                      : AppColors.grey200,
                                  backgroundImage: staff['profileImage'] != null
                                      ? NetworkImage(staff['profileImage'])
                                      : null,
                                  child: staff['profileImage'] == null
                                      ? Text(
                                          staff['fullName']?[0] ?? '?',
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.grey700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                title: Text(
                                  staff['fullName'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  _getRoleDisplay(staff['role']),
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.grey600,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                selected: isSelected,
                                selectedTileColor: AppColors.primary.withOpacity(0.1),
                              ),
                            );
                          },
                        ),
                ),

                // Assign Button
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
                  child: CustomButton(
                    text: 'Assign Complaint',
                    onPressed: _selectedStaff != null ? _assignComplaint : null,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
    );
  }

  String _getRoleDisplay(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'Admin';
      case 'caretaker':
        return 'Caretaker';
      case 'messstaff':
        return 'Mess Staff';
      default:
        return role ?? 'Staff';
    }
  }
}