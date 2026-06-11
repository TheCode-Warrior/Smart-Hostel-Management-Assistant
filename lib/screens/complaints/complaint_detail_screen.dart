import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/complaint_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/models/complaint_model.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final String complaintId;

  const ComplaintDetailScreen({
    Key? key,
    required this.complaintId,
  }) : super(key: key);

  @override
  _ComplaintDetailScreenState createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final complaintProvider = Provider.of<ComplaintProvider>(context, listen: false);
    await complaintProvider.loadComplaintDetails(widget.complaintId);
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final complaintProvider = Provider.of<ComplaintProvider>(context, listen: false);

    await complaintProvider.addComment(
      complaintId: widget.complaintId,
      comment: _commentController.text,
      userId: authProvider.user!.uid!,
      userName: authProvider.user!.fullName!,
    );

    setState(() {
      _isLoading = false;
      _commentController.clear();
    });
  }

 // Update the _updateStatus method in complaint_detail_screen.dart
Future<void> _updateStatus(ComplaintStatus newStatus) async {
  setState(() => _isLoading = true);

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final complaintProvider = Provider.of<ComplaintProvider>(context, listen: false);

  String? resolutionNotes;
  
  if (newStatus == ComplaintStatus.resolved) {
    resolutionNotes = await _showResolutionDialog();
    if (resolutionNotes == null) {
      setState(() => _isLoading = false);
      return;
    }
  }

  final result = await complaintProvider.updateComplaintStatus(
    complaintId: widget.complaintId,
    newStatus: newStatus,
    updatedBy: authProvider.user!.uid!,
    comment: 'Status updated to ${newStatus.toString().split('.').last}',
    resolvedBy: newStatus == ComplaintStatus.resolved ? authProvider.user!.uid! : null,
    resolutionNotes: resolutionNotes,
  );

  setState(() => _isLoading = false);

  if (result['success'] == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${result['message']}'),
        backgroundColor: Colors.green,
      ),
    );
    
    // ✅ Force refresh the complaint details
    await complaintProvider.loadComplaintDetails(widget.complaintId);
    
    // ✅ Also refresh the list if coming back
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true); // Return true to indicate changes
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ ${result['message']}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  Future<String?> _showResolutionDialog() {
    TextEditingController notesController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Resolution Notes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  hintText: 'Enter resolution details...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, notesController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageGallery(List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: PhotoViewGallery.builder(
            itemCount: images.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(images[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: PageController(initialPage: initialIndex),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final complaintProvider = Provider.of<ComplaintProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final complaint = complaintProvider.currentComplaint;
    
    if (complaint == null) {
      return const Scaffold(
        body: Center(
          child: Text('Complaint not found'),
        ),
      );
    }

    final bool isStudent = authProvider.user?.roleString == 'Student';
    final bool canUpdateStatus = !isStudent && complaint.status != ComplaintStatus.resolved && complaint.status != ComplaintStatus.rejected;
    final bool canAssign = !isStudent && complaint.status == ComplaintStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: Text('#${complaint.complaintNumber ?? ''}'),
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
          if (canAssign)
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.assignComplaint,
                  arguments: complaint.id,
                );
              },
            ),
          PopupMenuButton<ComplaintStatus>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: canUpdateStatus ? _updateStatus : null,
            itemBuilder: (context) => [
              if (complaint.status == ComplaintStatus.pending)
                const PopupMenuItem(
                  value: ComplaintStatus.assigned,
                  child: Text('Assign & Start Work'),
                ),
              if (complaint.status == ComplaintStatus.assigned)
                const PopupMenuItem(
                  value: ComplaintStatus.resolved,
                  child: Text('Mark as Resolved'),
                ),
              if (complaint.status != ComplaintStatus.rejected &&
                  complaint.status != ComplaintStatus.resolved)
                const PopupMenuItem(
                  value: ComplaintStatus.rejected,
                  child: Text('Reject Complaint'),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Timeline
                  _buildStatusTimeline(complaint),
                  const SizedBox(height: 20),

                  // Complaint Details Card
                  _buildDetailsCard(complaint),
                  const SizedBox(height: 16),

                  // Attachments
                  if (complaint.attachments != null && complaint.attachments!.isNotEmpty)
                    _buildAttachments(complaint.attachments!),
                  if (complaint.resolutionAttachments != null && 
                      complaint.resolutionAttachments!.isNotEmpty)
                    _buildResolutionAttachments(complaint.resolutionAttachments!),
                  const SizedBox(height: 16),

                  // Updates Timeline
                  _buildUpdatesTimeline(complaint),
                  const SizedBox(height: 16),

                  // Add Comment Section
                  _buildAddCommentSection(complaint),
                  const SizedBox(height: 20),

                  // Rating Section (for resolved complaints)
                  if (complaint.status == ComplaintStatus.resolved && isStudent && complaint.studentRating == null)
                    _buildRatingSection(complaint),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusTimeline(ComplaintModel complaint) {
    List<Map<String, dynamic>> steps = [
      {'status': 'Pending', 'time': complaint.createdAt, 'icon': Icons.pending, 'color': Colors.orange},
      {'status': 'Assigned', 'time': complaint.assignedAt, 'icon': Icons.person, 'color': Colors.blue},
    ];

    if (complaint.status == ComplaintStatus.resolved) {
      steps.add({'status': 'Resolved', 'time': complaint.resolvedAt, 'icon': Icons.check_circle, 'color': Colors.green});
    } else if (complaint.status == ComplaintStatus.rejected) {
      steps.add({'status': 'Rejected', 'time': complaint.resolvedAt, 'icon': Icons.cancel, 'color': Colors.red});
    }

    int currentStep = 0;
    switch (complaint.status) {
      case ComplaintStatus.pending:
        currentStep = 0;
        break;
      case ComplaintStatus.assigned:
        currentStep = 1;
        break;
      case ComplaintStatus.resolved:
      case ComplaintStatus.rejected:
        currentStep = 2;
        break;
      default:
        currentStep = 0;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
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
                child: Icon(Icons.timeline, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Status Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(steps.length, (index) {
              return Expanded(
                child: _buildTimelineStep(
                  icon: steps[index]['icon'],
                  label: steps[index]['status'],
                  color: steps[index]['color'],
                  isCompleted: index <= currentStep,
                  isLast: index == steps.length - 1,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String label,
    required Color color,
    required bool isCompleted,
    required bool isLast,
  }) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: isCompleted
                ? LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                  )
                : null,
            color: isCompleted ? null : AppColors.grey200,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted ? color : AppColors.grey300,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isCompleted ? Colors.white : AppColors.grey500,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isCompleted ? color : AppColors.grey500,
            fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(ComplaintModel complaint) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          // Title and Priority
          Row(
            children: [
              Expanded(
                child: Text(
                  complaint.title ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: complaint.priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: complaint.priorityColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag, size: 14, color: complaint.priorityColor),
                    const SizedBox(width: 4),
                    Text(
                      complaint.priorityString,
                      style: TextStyle(
                        color: complaint.priorityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Complaint Info Grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildInfoChip(Icons.category, 'Category', complaint.categoryString),
              _buildInfoChip(Icons.location_on, 'Location', complaint.location ?? 'N/A'),
              _buildInfoChip(
                Icons.access_time,
                'Submitted on',
                DateFormat('dd MMM yyyy, hh:mm a').format(complaint.createdAt!.toDate()),
              ),
              if (complaint.assignedToName != null)
                _buildInfoChip(Icons.person, 'Assigned to', complaint.assignedToName!),
              if (complaint.resolvedByName != null)
                _buildInfoChip(Icons.check_circle, 'Resolved by', complaint.resolvedByName!),
              if (complaint.resolvedAt != null)
                _buildInfoChip(
                  Icons.access_time,
                  'Resolved on',
                  DateFormat('dd MMM yyyy, hh:mm a').format(complaint.resolvedAt!.toDate()),
                ),
            ],
          ),

          const Divider(height: 24),

          // Description
          const Text(
            'Description',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              complaint.description ?? '',
              style: TextStyle(color: AppColors.grey800, height: 1.5),
            ),
          ),

          if (complaint.resolutionNotes != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Resolution Notes',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      complaint.resolutionNotes!,
                      style: TextStyle(color: AppColors.grey800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppColors.grey600,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(List<String> attachments) {
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
                child: Icon(Icons.attach_file, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Attachments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showImageGallery(attachments, index),
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.grey300),
                      image: DecorationImage(
                        image: NetworkImage(attachments[index]),
                        fit: BoxFit.cover,
                      ),
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

  Widget _buildResolutionAttachments(List<String> attachments) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Resolution Attachments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showImageGallery(attachments, index),
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                      image: DecorationImage(
                        image: NetworkImage(attachments[index]),
                        fit: BoxFit.cover,
                      ),
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

Widget _buildUpdatesTimeline(ComplaintModel complaint) {
  if (complaint.updates == null || complaint.updates!.isEmpty) {
    return const SizedBox();
  }

  return Container(
    padding: const EdgeInsets.all(20),
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
              child: Icon(Icons.history, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Activity Timeline',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...complaint.updates!.map((update) {
          // ✅ Use the helper method to get DateTime
          DateTime? updateTime = update.updatedAtDateTime;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getUpdateStatusColor(update.status).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getUpdateStatusIcon(update.status),
                    color: _getUpdateStatusColor(update.status),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update.comment ?? 'Status updated',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline, size: 12, color: AppColors.grey500),
                              const SizedBox(width: 4),
                              Text(
                                'by ${update.updatedBy ?? 'System'}',
                                style: TextStyle(
                                  color: AppColors.grey600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (updateTime != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 12, color: AppColors.grey500),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd MMM, hh:mm a').format(updateTime),
                                  style: TextStyle(
                                    color: AppColors.grey600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  );
}
 
  Widget _buildAddCommentSection(ComplaintModel complaint) {
    if (complaint.status == ComplaintStatus.resolved || 
        complaint.status == ComplaintStatus.rejected) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
                child: Icon(Icons.comment, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add Comment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Type your comment here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.grey100,
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: CustomButton(
              text: 'Post Comment',
              onPressed: _addComment,
              isLoading: _isLoading,
              isSmall: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection(ComplaintModel complaint) {
    int _rating = 0;
    TextEditingController _feedbackController = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(20),
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
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rate Resolution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'How satisfied are you with the resolution?',
            style: TextStyle(color: AppColors.grey600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [1, 2, 3, 4, 5].map((rating) {
              return IconButton(
                icon: Icon(
                  Icons.star,
                  color: rating <= _rating ? Colors.amber : AppColors.grey400,
                  size: 36,
                ),
                onPressed: () {
                  setState(() {
                    _rating = rating;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _feedbackController,
            decoration: InputDecoration(
              hintText: 'Any additional feedback? (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.grey100,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {});
                },
                child: const Text('Skip'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  final complaintProvider = Provider.of<ComplaintProvider>(
                    context,
                    listen: false,
                  );
                  
                  await complaintProvider.rateComplaint(
                    complaintId: widget.complaintId,
                    rating: _rating,
                    feedback: _feedbackController.text,
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for your feedback!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  await _loadData();
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Submit Rating'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getUpdateStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  IconData _getUpdateStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'assigned':
        return Icons.person;
      case 'resolved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.update;
    }
  }
}