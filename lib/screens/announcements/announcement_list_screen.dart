import 'package:flutter/material.dart';
import 'package:fyp_2026/core/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({Key? key}) : super(key: key);

  @override
  _AnnouncementListScreenState createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  
  final List<String> _categories = [
    'All',
    'General',
    'Maintenance',
    'Holiday',
    'Event',
    'Emergency'
  ];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);

    try {
      final announcements = await FirestoreService.queryDocuments(
        collection: 'announcements',
        orderBy: ['createdAt'],
        descending: true,
      );
      
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading announcements: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredAnnouncements() {
    if (_selectedCategory == 'All') {
      return _announcements;
    }
    return _announcements.where((a) => 
      a['category']?.toLowerCase() == _selectedCategory.toLowerCase()
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.user?.roleString == 'Admin' || 
                    authProvider.user?.roleString == 'Warden';
    
    final filteredAnnouncements = _getFilteredAnnouncements();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                _showCreateAnnouncementDialog();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : Column(
              children: [
                // Category Filter
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      bool isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : 'All';
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: _getCategoryColor(category).withOpacity(0.2),
                          checkmarkColor: _getCategoryColor(category),
                          labelStyle: TextStyle(
                            color: isSelected ? _getCategoryColor(category) : AppColors.grey700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Announcements List
                Expanded(
                  child: filteredAnnouncements.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredAnnouncements.length,
                          itemBuilder: (context, index) {
                            final announcement = filteredAnnouncements[index];
                            return _buildAnnouncementCard(announcement);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    String category = announcement['category'] ?? 'general';
    Color categoryColor = _getCategoryColor(category);
    bool isPinned = announcement['isPinned'] == true;
    bool isEmergency = announcement['priority'] == 'urgent';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isEmergency
            ? BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.announcementDetail,
            arguments: announcement['id'],
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isPinned) ...[
                    Icon(Icons.push_pin, color: AppColors.primary, size: 14),
                    const SizedBox(width: 4),
                  ],
                  if (isEmergency) ...[
                    Icon(Icons.warning, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'URGENT',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    _getTimeAgo(announcement['createdAt']),
                    style: TextStyle(
                      color: AppColors.grey500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                announcement['title'] ?? '',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isPinned ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Content Preview
              Text(
                announcement['content'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.grey700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),

              // Footer
              Row(
                children: [
                  Icon(Icons.remove_red_eye, size: 14, color: AppColors.grey500),
                  const SizedBox(width: 4),
                  Text(
                    '${announcement['viewCount'] ?? 0} views',
                    style: TextStyle(
                      color: AppColors.grey500,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.thumb_up, size: 14, color: AppColors.grey500),
                  const SizedBox(width: 4),
                  Text(
                    '${announcement['acknowledgedBy']?.length ?? 0} acknowledged',
                    style: TextStyle(
                      color: AppColors.grey500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),

              // Date Range (if applicable)
              if (announcement['startDate'] != null || announcement['endDate'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, size: 14, color: AppColors.grey600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getDateRangeText(announcement),
                          style: TextStyle(
                            color: AppColors.grey700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
          Icon(
            Icons.campaign,
            size: 80,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Announcements',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'There are no announcements to display',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }

  void _showCreateAnnouncementDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCategory = 'General';
    String selectedPriority = 'Medium';
    bool isPinned = false;
    DateTime? startDate;
    DateTime? endDate;
    bool isSending = false;

    final BuildContext mainContext = context;

    showDialog(
      context: mainContext,
      barrierDismissible: !isSending,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.campaign, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Create Announcement',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isSending)
                            GestureDetector(
                              onTap: () => Navigator.pop(dialogContext),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title Field
                            const Text('Title', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: titleController,
                              enabled: !isSending,
                              decoration: InputDecoration(
                                hintText: 'Enter announcement title',
                                prefixIcon: const Icon(Icons.title),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: AppColors.grey100,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Content Field
                            const Text('Content', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: contentController,
                              enabled: !isSending,
                              decoration: InputDecoration(
                                hintText: 'Enter announcement details',
                                prefixIcon: const Icon(Icons.description),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: AppColors.grey100,
                              ),
                              maxLines: 5,
                            ),
                            const SizedBox(height: 16),
                            
                            // Category Dropdown
                            const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.grey100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: selectedCategory,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  prefixIcon: Icon(Icons.category),
                                ),
                                items: ['General', 'Maintenance', 'Holiday', 'Event', 'Emergency']
                                    .map((cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: _getCategoryColor(cat.toLowerCase()),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(cat),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                                onChanged: isSending ? null : (value) => setDialogState(() => selectedCategory = value!),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Priority Dropdown - FIXED: Removed 'enabled' parameter
                            const Text('Priority', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.grey100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: selectedPriority,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  prefixIcon: Icon(Icons.priority_high),
                                ),
                                items: ['Low', 'Medium', 'High', 'Urgent']
                                    .map((pri) => DropdownMenuItem(
                                          value: pri,
                                          child: Row(
                                            children: [
                                              Icon(Icons.flag, size: 16, color: _getPriorityColor(pri)),
                                              const SizedBox(width: 8),
                                              Text(pri),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                                onChanged: isSending ? null : (value) => setDialogState(() => selectedPriority = value!),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Pin Announcement
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.grey100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CheckboxListTile(
                                title: const Text('Pin this announcement'),
                                subtitle: const Text('Pinned announcements appear at the top'),
                                value: isPinned,
                                onChanged: isSending ? null : (value) => setDialogState(() => isPinned = value ?? false),
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Date Range Section
                            const Text('Date Range (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: isSending ? null : () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: startDate ?? DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (date != null) setDialogState(() => startDate = date);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.grey100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.grey300),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              startDate != null
                                                  ? DateFormat('dd MMM yyyy').format(startDate!)
                                                  : 'Start Date',
                                              style: TextStyle(
                                                color: startDate != null ? AppColors.grey800 : AppColors.grey500,
                                              ),
                                            ),
                                          ),
                                          if (startDate != null && !isSending)
                                            GestureDetector(
                                              onTap: () => setDialogState(() => startDate = null),
                                              child: const Icon(Icons.close, size: 16, color: Colors.red),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: isSending ? null : () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: endDate ?? DateTime.now().add(const Duration(days: 7)),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (date != null) setDialogState(() => endDate = date);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: AppColors.grey100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.grey300),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.event, size: 18, color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              endDate != null
                                                  ? DateFormat('dd MMM yyyy').format(endDate!)
                                                  : 'End Date',
                                              style: TextStyle(
                                                color: endDate != null ? AppColors.grey800 : AppColors.grey500,
                                              ),
                                            ),
                                          ),
                                          if (endDate != null && !isSending)
                                            GestureDetector(
                                              onTap: () => setDialogState(() => endDate = null),
                                              child: const Icon(Icons.close, size: 16, color: Colors.red),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.grey200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSending ? null : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSending
                                  ? null
                                  : () async {
                                      if (titleController.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                                          const SnackBar(content: Text('Please enter a title'), backgroundColor: Colors.orange),
                                        );
                                        return;
                                      }
                                      
                                      if (contentController.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                                          const SnackBar(content: Text('Please enter content'), backgroundColor: Colors.orange),
                                        );
                                        return;
                                      }

                                      setDialogState(() => isSending = true);
                                      Navigator.pop(dialogContext);
                                      
                                      if (mounted) setState(() => _isLoading = true);

                                      try {
                                        final authProvider = Provider.of<AuthProvider>(mainContext, listen: false);
                                        
                                        Map<String, dynamic> announcement = {
                                          'title': titleController.text.trim(),
                                          'content': contentController.text.trim(),
                                          'category': selectedCategory.toLowerCase(),
                                          'priority': selectedPriority.toLowerCase(),
                                          'isPinned': isPinned,
                                          'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
                                          'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
                                          'createdBy': authProvider.user!.uid!,
                                          'createdAt': FieldValue.serverTimestamp(),
                                          'viewCount': 0,
                                          'acknowledgedBy': [],
                                        };

                                        final String announcementId = await FirestoreService.createDocument(
                                          collection: 'announcements',
                                          data: announcement,
                                        );

                                        if (announcementId.isNotEmpty && mounted) {
                                          // Send notifications to all students
                                          final notificationSent = await NotificationService.sendToAllStudents(
                                            title: '📢 New Announcement',
                                            body: titleController.text.length > 100 
                                                ? '${titleController.text.substring(0, 100)}...' 
                                                : titleController.text,
                                            type: 'announcement',
                                            data: {'announcementId': announcementId},
                                          );
                                          
                                          if (notificationSent) {
                                            debugPrint('✅ Announcement notifications sent successfully');
                                          } else {
                                            debugPrint('⚠️ Failed to send some announcement notifications');
                                          }
                                        }
                                        
                                        if (mounted) await _loadAnnouncements();

                                        if (mounted) {
                                          ScaffoldMessenger.of(mainContext).showSnackBar(
                                            const SnackBar(content: Text('Announcement created successfully'), backgroundColor: Colors.green),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(mainContext).showSnackBar(
                                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                          );
                                        }
                                      } finally {
                                        if (mounted) setState(() => _isLoading = false);
                                      }
                                      
                                      titleController.dispose();
                                      contentController.dispose();
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: isSending
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Create'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'urgent':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'general':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'holiday':
        return Colors.green;
      case 'event':
        return Colors.purple;
      case 'emergency':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(date);
        
        if (difference.inDays > 7) {
          return DateFormat('dd MMM yyyy').format(date);
        } else if (difference.inDays > 0) {
          return '${difference.inDays}d ago';
        } else if (difference.inHours > 0) {
          return '${difference.inHours}h ago';
        } else if (difference.inMinutes > 0) {
          return '${difference.inMinutes}m ago';
        } else {
          return 'Just now';
        }
      }
    } catch (e) {
      return 'Just now';
    }
    return 'Just now';
  }

  String _getDateRangeText(Map<String, dynamic> announcement) {
    List<String> parts = [];
    
    if (announcement['startDate'] != null) {
      final start = (announcement['startDate'] as Timestamp).toDate();
      parts.add('From: ${DateFormat('dd MMM').format(start)}');
    }
    
    if (announcement['endDate'] != null) {
      final end = (announcement['endDate'] as Timestamp).toDate();
      parts.add('To: ${DateFormat('dd MMM').format(end)}');
    }
    
    return parts.join(' • ');
  }
}