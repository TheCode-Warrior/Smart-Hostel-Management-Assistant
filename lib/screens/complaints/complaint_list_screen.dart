import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/complaint_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/complaint_model.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';

class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({Key? key}) : super(key: key);

  @override
  _ComplaintListScreenState createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> {
  String _selectedFilter = 'All';
final List<String> _filters = ['All', 'Pending', 'Assigned', 'Resolved', 'Rejected'];
  bool _isInitialLoad = true;
  
  @override
  void initState() {
    super.initState();
    // ✅ Use addPostFrameCallback to load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }


// In ComplaintListScreen, add this to refresh when coming back
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  // Refresh when returning from detail screen
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && !_isInitialLoad) {
      _loadData();
    }
  });
}
  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final complaintProvider = Provider.of<ComplaintProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      if (authProvider.user!.roleString == 'Student') {
        await complaintProvider.loadStudentComplaints(authProvider.user!.uid!);
      } else {
        await complaintProvider.loadAllComplaints();
      }
    }
    
    if (mounted) {
      setState(() {
        _isInitialLoad = false;
      });
    }
  }

  List<ComplaintModel> _getFilteredComplaints() {
    final complaintProvider = Provider.of<ComplaintProvider>(context, listen: false);
    
    if (_selectedFilter == 'All') {
      return complaintProvider.complaints;
    }
    
    return complaintProvider.complaints.where((c) {
      return c.statusString == _selectedFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final complaintProvider = Provider.of<ComplaintProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    final bool isStudent = authProvider.user?.roleString == 'Student';
    final filteredComplaints = _getFilteredComplaints();

    // Show loading only on initial load
    if (_isInitialLoad && complaintProvider.isLoading) {
      return const Scaffold(
        body: LoadingIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final bool isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = selected ? filter : 'All';
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: _getFilterColor(filter).withOpacity(0.2),
                      checkmarkColor: _getFilterColor(filter),
                      labelStyle: TextStyle(
                        color: isSelected ? _getFilterColor(filter) : AppColors.grey700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      body: complaintProvider.complaints.isEmpty && !complaintProvider.isLoading
          ? _buildEmptyState(isStudent)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredComplaints.length,
                itemBuilder: (context, index) {
                  final complaint = filteredComplaints[index];
                  return _buildComplaintCard(complaint, isStudent);
                },
              ),
            ),
      floatingActionButton: isStudent
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.raiseComplaint);
              },
              icon: const Icon(Icons.add),
              label: const Text('Raise'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Widget _buildComplaintCard(ComplaintModel complaint, bool isStudent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.complaintDetail,
            arguments: complaint.id,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: complaint.priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.priority_high,
                      color: complaint.priorityColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${complaint.complaintNumber ?? ''}',
                          style: TextStyle(
                            color: AppColors.grey600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          complaint.title ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: complaint.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          complaint.statusIcon,
                          size: 12,
                          color: complaint.statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          complaint.statusString,
                          style: TextStyle(
                            color: complaint.statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                complaint.description ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.grey700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),

              // Meta Info
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildMetaChip(Icons.category, complaint.categoryString),
                  _buildMetaChip(Icons.location_on, complaint.location ?? 'N/A'),
                  _buildMetaChip(
                    Icons.access_time,
                    DateFormat('dd MMM yyyy').format(complaint.createdAt!.toDate()),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Assigned To (for students) or Student Name (for staff)
              if (!isStudent && complaint.studentName != null) ...[
                const Divider(),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: AppColors.grey600),
                    const SizedBox(width: 4),
                    Text(
                      'By: ${complaint.studentName}',
                      style: TextStyle(
                        color: AppColors.grey600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              
              if (isStudent && complaint.assignedToName != null) ...[
                const Divider(),
                Row(
                  children: [
                    Icon(Icons.support_agent, size: 14, color: AppColors.grey600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Assigned to: ${complaint.assignedToName}',
                        style: TextStyle(
                          color: AppColors.grey600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Resolution Info
              if (complaint.status == ComplaintStatus.resolved && complaint.resolvedAt != null) ...[
                const Divider(),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Resolved on ${DateFormat('dd MMM yyyy, hh:mm a').format(complaint.resolvedAt!.toDate())}',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.grey600),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.grey600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isStudent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_problem,
            size: 80,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Complaints',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isStudent
                ? 'You haven\'t raised any complaints yet.\nTap the + button to raise your first complaint.'
                : 'No complaints found',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
          if (isStudent) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.raiseComplaint);
              },
              icon: const Icon(Icons.add),
              label: const Text('Raise Complaint'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

 // Update the filter color method:
Color _getFilterColor(String filter) {
  switch (filter) {
    case 'Pending':
      return Colors.orange;
    case 'Assigned':
      return Colors.blue;
    case 'Resolved':
      return Colors.green;
    case 'Rejected':
      return Colors.red;
    default:
      return AppColors.primary;
  }
}

}