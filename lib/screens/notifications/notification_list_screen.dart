import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({Key? key}) : super(key: key);

  @override
  _NotificationListScreenState createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Unread', 'Read'];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      notificationProvider.loadNotifications(authProvider.user!.uid!);
    }
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    switch (_selectedFilter) {
      case 'Unread':
        return notificationProvider.notifications.where((n) => n['isRead'] == false).toList();
      case 'Read':
        return notificationProvider.notifications.where((n) => n['isRead'] == true).toList();
      default:
        return notificationProvider.notifications;
    }
  }

  Future<void> _markAllAsRead() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    await notificationProvider.markAllAsRead(authProvider.user!.uid!);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _clearAll() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to clear all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement clear all functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications cleared'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final filteredNotifications = _getFilteredNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notificationProvider.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAll,
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: _filters.map((filter) {
                bool isSelected = _selectedFilter == filter;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text('$filter (${_getCountForFilter(filter)})'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = selected ? filter : 'All';
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.grey700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Notifications List
          Expanded(
            child: notificationProvider.isLoading
                ? const LoadingIndicator()
                : filteredNotifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = filteredNotifications[index];
                          return _buildNotificationCard(notification);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    bool isRead = notification['isRead'] ?? false;
    String type = notification['type'] ?? 'general';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRead ? Colors.white : AppColors.primary.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: !isRead
            ? BorderSide(color: AppColors.primary, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () async {
          if (!isRead) {
            final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
            await notificationProvider.markAsRead(notification['id']);
          }
          _showNotificationDetails(notification);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getNotificationColor(type).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getNotificationIcon(type),
                  color: _getNotificationColor(type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['body'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.grey600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppColors.grey500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeAgo(notification['sentAt']),
                          style: TextStyle(
                            color: AppColors.grey500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Menu
              PopupMenuButton(
                icon: Icon(Icons.more_vert, size: 18, color: AppColors.grey600),
                itemBuilder: (context) => [
                  if (!isRead)
                    PopupMenuItem(
                      child: const Text('Mark as Read'),
                      onTap: () async {
                        final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
                        await notificationProvider.markAsRead(notification['id']);
                      },
                    ),
                  PopupMenuItem(
                    child: const Text('Delete'),
                    onTap: () {
                      // Implement delete
                    },
                  ),
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
          Icon(
            Icons.notifications_off,
            size: 80,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'You don\'t have any notifications yet'
                : 'No ${_selectedFilter.toLowerCase()} notifications',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title'] ?? 'Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['body'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              'Received: ${_getFullDateTime(notification['sentAt'])}',
              style: TextStyle(
                color: AppColors.grey600,
                fontSize: 12,
              ),
            ),
            if (notification['data'] != null) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Additional Info',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ..._buildNotificationData(notification['data']),
            ],
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

  List<Widget> _buildNotificationData(Map<String, dynamic>? data) {
    if (data == null) return [];
    
    return data.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(
              '${entry.key}: ',
              style: TextStyle(
                color: AppColors.grey700,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Text(
                entry.value.toString(),
                style: TextStyle(color: AppColors.grey600),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  int _getCountForFilter(String filter) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    switch (filter) {
      case 'Unread':
        return notificationProvider.unreadCount;
      case 'Read':
        return notificationProvider.notifications.length - notificationProvider.unreadCount;
      default:
        return notificationProvider.notifications.length;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'attendance':
        return Colors.blue;
      case 'fee':
        return Colors.green;
      case 'complaint':
        return Colors.orange;
      case 'mess':
        return Colors.purple;
      case 'announcement':
        return Colors.red;
      case 'alert':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'attendance':
        return Icons.fingerprint;
      case 'fee':
        return Icons.payment;
      case 'complaint':
        return Icons.report_problem;
      case 'mess':
        return Icons.restaurant;
      case 'announcement':
        return Icons.campaign;
      case 'alert':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      if (timestamp is Timestamp) {
        return timeago.format(timestamp.toDate());
      }
    } catch (e) {
      return 'Just now';
    }
    return 'Just now';
  }

  String _getFullDateTime(dynamic timestamp) {
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
}