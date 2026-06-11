import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/custom_button.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final String announcementId;

  const AnnouncementDetailScreen({
    Key? key,
    required this.announcementId,
  }) : super(key: key);

  @override
  _AnnouncementDetailScreenState createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  Map<String, dynamic>? _announcement;
  bool _isLoading = false;
  bool _hasAcknowledged = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    setState(() => _isLoading = true);

    try {
      final data = await FirestoreService.readDocument(
        collection: 'announcements',
        documentId: widget.announcementId,
      );

      if (data != null) {
        // Increment view count
        await FirestoreService.updateDocument(
          collection: 'announcements',
          documentId: widget.announcementId,
          updates: {
            'viewCount': (data['viewCount'] ?? 0) + 1,
          },
        );

        // Check if current user has acknowledged
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final acknowledgedBy = List<String>.from(data['acknowledgedBy'] ?? []);
        
        setState(() {
          _announcement = {...data, 'id': widget.announcementId};
          _hasAcknowledged = authProvider.user != null && 
              acknowledgedBy.contains(authProvider.user!.uid);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading announcement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acknowledge() async {
    if (_hasAcknowledged) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() => _isLoading = true);

    try {
      final acknowledgedBy = List<String>.from(_announcement!['acknowledgedBy'] ?? []);
      acknowledgedBy.add(authProvider.user!.uid!);

      await FirestoreService.updateDocument(
        collection: 'announcements',
        documentId: widget.announcementId,
        updates: {
          'acknowledgedBy': acknowledgedBy,
        },
      );

      setState(() {
        _announcement!['acknowledgedBy'] = acknowledgedBy;
        _hasAcknowledged = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for acknowledging'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadAttachment(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(url);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open attachment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.user?.roleString == 'Admin' || 
                    authProvider.user?.roleString == 'Warden';

    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(),
      );
    }

    if (_announcement == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Announcement'),
        ),
        body: const Center(
          child: Text('Announcement not found'),
        ),
      );
    }

    final category = _announcement!['category'] ?? 'general';
    final priority = _announcement!['priority'] ?? 'medium';
    final isEmergency = priority == 'urgent';
    final isPinned = _announcement!['isPinned'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement'),
        actions: [
          if (isAdmin)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
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
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: isEmergency
                    ? LinearGradient(
                        colors: [Colors.red.shade800, Colors.red.shade600],
                      )
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and Priority
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isPinned) ...[
                        const Icon(Icons.push_pin, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                      ],
                      if (isEmergency) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'URGENT',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    _announcement!['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Date and Author
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _getFormattedDate(_announcement!['createdAt']),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.person, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _announcement!['createdBy'] ?? 'Admin',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _announcement!['content'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.grey800,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Date Range (if applicable)
            if (_announcement!['startDate'] != null || _announcement!['endDate'] != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Valid Period',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getDateRangeText(),
                            style: TextStyle(color: AppColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Attachments (if any)
            if (_announcement!['attachments'] != null && 
                (_announcement!['attachments'] as List).isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attachments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(_announcement!['attachments'] as List).map((url) {
                      return ListTile(
                        leading: Icon(Icons.attach_file, color: AppColors.primary),
                        title: Text(url.split('/').last),
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _downloadAttachment(url),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Statistics
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Views',
                        '${_announcement!['viewCount'] ?? 0}',
                        Icons.remove_red_eye,
                      ),
                      _buildStatItem(
                        'Acknowledged',
                        '${_announcement!['acknowledgedBy']?.length ?? 0}',
                        Icons.thumb_up,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Acknowledge Button
            CustomButton(
              text: _hasAcknowledged ? 'Acknowledged ✓' : 'Acknowledge',
              onPressed: _hasAcknowledged ? null : _acknowledge,
              icon: _hasAcknowledged ? Icons.check_circle : Icons.thumb_up,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.grey600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _getFormattedDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      if (timestamp is Timestamp) {
        return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
      }
    } catch (e) {
      return 'Unknown';
    }
    return 'Unknown';
  }

  String _getDateRangeText() {
    List<String> parts = [];
    
    if (_announcement!['startDate'] != null) {
      final start = (_announcement!['startDate'] as Timestamp).toDate();
      parts.add('From: ${DateFormat('dd MMM yyyy').format(start)}');
    }
    
    if (_announcement!['endDate'] != null) {
      final end = (_announcement!['endDate'] as Timestamp).toDate();
      parts.add('To: ${DateFormat('dd MMM yyyy').format(end)}');
    }
    
    return parts.isNotEmpty ? parts.join(' • ') : 'No date restrictions';
  }
}