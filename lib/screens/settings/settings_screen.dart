import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _autoAttendance = false;
  String _reminderTime = '30 minutes before';
  
  final List<String> _reminderTimes = [
    '15 minutes before',
    '30 minutes before',
    '1 hour before',
    '2 hours before',
    'At meal time'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _autoAttendance = prefs.getBool('auto_attendance') ?? false;
        _reminderTime = prefs.getString('reminder_time') ?? '30 minutes before';
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('auto_attendance', _autoAttendance);
    await prefs.setString('reminder_time', _reminderTime);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearCache() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Clear Cache'),
          ],
        ),
        content: const Text('Are you sure you want to clear all cached data? This will not delete your account data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Clear shared preferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully'), backgroundColor: Colors.green),
              );
              _loadSettings(); // Reload settings
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String? errorMessage;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    helperText: 'Password must be at least 6 characters',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (oldPasswordController.text.isEmpty) {
                          setDialogState(() => errorMessage = 'Please enter current password');
                          return;
                        }
                        if (newPasswordController.text.length < 6) {
                          setDialogState(() => errorMessage = 'New password must be at least 6 characters');
                          return;
                        }
                        if (newPasswordController.text != confirmPasswordController.text) {
                          setDialogState(() => errorMessage = 'New passwords do not match');
                          return;
                        }
                        
                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });
                        
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final success = await authProvider.changePassword(
                          currentPassword: oldPasswordController.text,
                          newPassword: newPasswordController.text,
                        );
                        
                        if (success && mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green),
                          );
                        } else {
                          setDialogState(() {
                            isLoading = false;
                            errorMessage = authProvider.errorMessage ?? 'Failed to change password';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Change'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showReminderDialog() async {
    String tempSelected = _reminderTime;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Reminder Time'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: _reminderTimes.map((time) {
                return RadioListTile<String>(
                  title: Text(time),
                  value: time,
                  groupValue: tempSelected,
                  onChanged: (value) {
                    setState(() => tempSelected = value!);
                  },
                  activeColor: AppColors.primary,
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(dialogContext, tempSelected),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() => _reminderTime = result);
      _saveSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder set to "$_reminderTime"'), backgroundColor: AppColors.primary),
      );
    }
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Email'),
              subtitle: const Text('support@hostelmanagement.com'),
              onTap: () => _launchURL('mailto:support@hostelmanagement.com'),
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('Phone'),
              subtitle: const Text('+91 9876543210'),
              onTap: () => _launchURL('tel:+919876543210'),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.orange),
              title: const Text('Live Chat'),
              subtitle: const Text('24/7 Support'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.chatbot);
              },
            ),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: AppColors.grey600, fontSize: 11)),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: AppColors.grey400, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: AppColors.grey600, fontSize: 11)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.user?.roleString == 'Admin';
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Info Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Icon(Icons.person, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'User',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.roleString ?? 'Role',
                          style: TextStyle(color: AppColors.grey600, fontSize: 12),
                        ),
                        Text(
                          user?.email ?? 'No email',
                          style: TextStyle(color: AppColors.grey500, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: AppColors.grey600),
                    onPressed: () => themeProvider.toggleTheme(),
                    tooltip: 'Toggle theme',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            'Push Notifications',
            'Receive notifications about attendance and announcements',
            Icons.notifications,
            _notificationsEnabled,
            (value) => setState(() => _notificationsEnabled = value),
          ),
          _buildListTile(
            'Reminder Time',
            _reminderTime,
            Icons.access_time,
            () => _showReminderDialog(),
          ),
          
          const SizedBox(height: 8),
          
          // Security Section
          _buildSectionHeader('Security'),
          _buildListTile(
            'Change Password',
            'Update your password',
            Icons.lock,
            () => _showChangePasswordDialog(context),
          ),
          
          const SizedBox(height: 8),
          
          // Admin Section
          if (isAdmin) ...[
            _buildSectionHeader('Administration'),
            _buildListTile(
              'Hostel Settings',
              'Configure hostel details and rules',
              Icons.apartment,
              () => Navigator.pushNamed(context, AppRoutes.hostelSettings),
            ),
            _buildListTile(
              'User Management',
              'Manage users and permissions',
              Icons.people,
              () => Navigator.pushNamed(context, AppRoutes.userManagement),
            ),
            _buildListTile(
              'Mess Management',
              'Generate and manage meal tokens',
              Icons.restaurant_menu,
              () => Navigator.pushNamed(context, AppRoutes.messManagement),
            ),
            _buildListTile(
              'Fee Management',
              'Add fees, view collections',
              Icons.payment,
              () => Navigator.pushNamed(context, AppRoutes.feeDashboard),
            ),
            StreamBuilder<int>(
              stream: FirebaseFirestore.instance
                  .collection('feeRequests')
                  .where('status', isEqualTo: 'pending')
                  .snapshots()
                  .map((snapshot) => snapshot.size),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return _buildListTile(
                  'Fee Requests',
                  count > 0 ? '$count pending request${count > 1 ? 's' : ''}' : 'Approve or reject payment requests',
                  Icons.request_page,
                  () => Navigator.pushNamed(context, AppRoutes.feeRequests),
                );
              },
            ),
            _buildListTile(
              'Announcements',
              'Create and manage announcements',
              Icons.campaign,
              () => Navigator.pushNamed(context, AppRoutes.announcements),
            ),
            _buildListTile(
              'Room Management',
              'View and manage hostel rooms',
              Icons.meeting_room,
              () => Navigator.pushNamed(context, AppRoutes.rooms),
            ),
          ],
          
          const SizedBox(height: 8),
          
          // Data Management
          _buildSectionHeader('Data Management'),
          _buildListTile(
            'Clear Cache',
            'Free up storage space',
            Icons.cleaning_services,
            _clearCache,
          ),
          _buildListTile(
            'Report Generator',
            'Generate detailed reports with charts and export options',
            Icons.analytics,
            () => Navigator.pushNamed(context, AppRoutes.reportGenerator),
          ),
          
          const SizedBox(height: 8),
          
          // About Section
          _buildSectionHeader('About'),
          _buildListTile(
            'App Version',
            '1.0.0',
            Icons.info,
            null,
          ),
          _buildListTile(
            'Terms & Conditions',
            'Read our terms',
            Icons.description,
            () => _launchURL('https://example.com/terms'),
          ),
          _buildListTile(
            'Privacy Policy',
            'Read our privacy policy',
            Icons.privacy_tip,
            () => _launchURL('https://example.com/privacy'),
          ),
          _buildListTile(
            'Contact Support',
            'Get help',
            Icons.support_agent,
            _showContactDialog,
          ),
          _buildListTile(
            'Chat with Assistant',
            'Get instant help from our AI assistant',
            Icons.smart_toy,
            () => Navigator.pushNamed(context, AppRoutes.chatbot),
          ),
          
          const SizedBox(height: 24),
          
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.logout();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Save Button
          CustomButton(
            text: 'Save Settings',
            onPressed: _saveSettings,
            icon: Icons.save,
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}