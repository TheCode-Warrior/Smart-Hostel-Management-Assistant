import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_2026/core/models/complaint_model.dart';
import 'package:fyp_2026/core/providers/complaint_provider.dart';
import 'package:fyp_2026/core/providers/complaint_provider.dart';
import 'package:fyp_2026/core/widgets/admin_dashboard_widgets.dart';
import 'package:fyp_2026/core/widgets/mess_staff_dashboard_widgets.dart';
import 'package:fyp_2026/core/widgets/student_dashboard_widgets.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/mess_provider.dart'; // Add this import
import '../../core/services/dashboard_service.dart';
import '../../routes/app_routes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    
  }

  Future<void> _loadInitialData() async {
    await _loadDashboardData();
    await _loadTodayMenu(); // Load menu from MessProvider
    await _loadComplaints();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role = authProvider.user?.roleString;

    try {
      Map<String, dynamic> data = {};

      if (role == 'Student' && authProvider.user?.uid != null) {
        data = await DashboardService.getStudentDashboardData(authProvider.user!.uid!);
      } else if (role == 'Admin') {
        data = await DashboardService.getAdminDashboardData();
      } else if (role == 'Mess Staff') {
        data = await DashboardService.getMessStaffDashboardData();
      }

      if (mounted) {
        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load dashboard data. Pull down to refresh.';
        });
      }
    }
  }

  // Add this method to load today's menu from MessProvider
  Future<void> _loadTodayMenu() async {
    final messProvider = Provider.of<MessProvider>(context, listen: false);
    await messProvider.loadTodayMenu();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final role = user?.roleString;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        actions: [
          if (role == 'Admin')
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'Hostel Settings',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.hostelSettings),
            ),
          IconButton(
            icon: const Icon(Icons.campaign_outlined, color: Colors.white),
            tooltip: 'Announcements',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.announcements),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            tooltip: 'Notifications',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            tooltip: 'Profile',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDashboardData();
          await _loadTodayMenu(); // Refresh menu on pull
          await _loadComplaints();
        },
        child: _buildBody(role),
      ),
    );
  }

  Widget _buildBody(String? role) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await _loadDashboardData();
                await _loadTodayMenu();
                 await _loadComplaints(); // Add this line
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(_dashboardData),
          const SizedBox(height: 16),

          // Role-Specific Dashboard Content
          if (role == 'Student') ...[
            _buildStudentDashboard(),
          ] else if (role == 'Admin') ...[
            _buildAdminDashboard(),
          ] else if (role == 'Mess Staff') ...[
            _buildMessStaffDashboard(),
          ],
          // In your _buildBody method, add this before Consumer<MessProvider>

 // ==================== RECENT COMPLAINTS ====================
        Consumer<ComplaintProvider>(
          builder: (context, complaintProvider, child) {
            if (complaintProvider.recentComplaints.isEmpty) {
              return const SizedBox();
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Complaints',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.complaints);
                      },
                      child: const Text('View All',),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...complaintProvider.recentComplaints.take(3).map(
                  (complaint) => _buildComplaintTile(complaint),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),


          // Today's Mess Menu - Now using Consumer to listen to MessProvider
          Consumer<MessProvider>(
            builder: (context, messProvider, child) {
              return _buildTodayMenuSection(messProvider);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==================== WELCOME SECTION ====================

  Widget _buildWelcomeSection(Map<String, dynamic> data) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.fullName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user?.roleString ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    data['currentDate'] ?? '',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['currentTime'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== STUDENT DASHBOARD ====================

  Widget _buildStudentDashboard() {
    return Column(
      children: [
        StudentDashboardWidgets.buildSmartStatusCard(
          context: context,
          attendance: _dashboardData['attendance'] ?? {},
          mealStatus: _dashboardData['mealStatus'] ?? {},
          upcomingMeals: List<Map<String, dynamic>>.from(_dashboardData['upcomingMeals'] ?? []),
        ),
        const SizedBox(height: 16),
        StudentDashboardWidgets.buildQuickStatsCard(
          attendancePercentage: _getAttendancePercentage(),
          mealsTaken: _getMealsTakenCount(),
          activeComplaints: _dashboardData['activeComplaints'] ?? 0,
          feeStatus: _dashboardData['feeStatus'] ?? {},
        ),
        const SizedBox(height: 16),
        StudentDashboardWidgets.buildQuickActionsGrid(context),
      ],
    );
  }

  // ==================== ADMIN DASHBOARD ====================

  Widget _buildAdminDashboard() {
    return Column(
      children: [
        AdminDashboardWidgets.buildOverviewStatsCard(_dashboardData),
        const SizedBox(height: 16),
        AdminDashboardWidgets.buildMealConsumptionCard(_dashboardData),
        const SizedBox(height: 16),
        AdminDashboardWidgets.buildQuickActionsGrid(context),
      ],
    );
  }

 // ==================== MESS STAFF DASHBOARD ====================

Widget _buildMessStaffDashboard() {
  return Column(
    children: [
      MessStaffDashboardWidgets.buildTodayOverviewCard(_dashboardData),
      const SizedBox(height: 16),
      MessStaffDashboardWidgets.buildQuickActionsGrid(context),
      const SizedBox(height: 16),
      MessStaffDashboardWidgets.buildRecentScansCard(
        List<Map<String, dynamic>>.from(_dashboardData['recentScans'] ?? []),
      ),
      const SizedBox(height: 16),
      // ✅ NEW: Student List Section
      MessStaffDashboardWidgets.buildStudentListSection(),
    ],
  );
}

  // ==================== TODAY'S MENU SECTION (UPDATED) ====================

  Widget _buildTodayMenuSection(MessProvider messProvider) {
    final menu = messProvider.todayMenu;
    
    // Show loading indicator while menu is being fetched
    if (messProvider.isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_menu, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  const Text(
                    "Today's Mess Menu",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    // Show error message if any
    if (messProvider.errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_menu, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  const Text(
                    "Today's Mess Menu",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      messProvider.errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => messProvider.loadTodayMenu(),
                icon: Icon(Icons.refresh, size: 16),
                label: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // No menu available
    if (menu == null) {
      return const SizedBox();
    }

    // Get meal items from the menu structure
    final breakfastItems = _toStringList(menu['breakfast']?['items']);
    final lunchItems = _toStringList(menu['lunch']?['items']);
    final dinnerItems = _toStringList(menu['dinner']?['items']);
    
    // Check if meals are enabled
    final breakfastEnabled = menu['breakfast']?['enabled'] ?? false;
    final lunchEnabled = menu['lunch']?['enabled'] ?? false;
    final dinnerEnabled = menu['dinner']?['enabled'] ?? false;
    
    // Filter only enabled meals with items
    final hasBreakfast = breakfastEnabled && breakfastItems.isNotEmpty;
    final hasLunch = lunchEnabled && lunchItems.isNotEmpty;
    final hasDinner = dinnerEnabled && dinnerItems.isNotEmpty;
    
    if (!hasBreakfast && !hasLunch && !hasDinner) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_menu, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  const Text(
                    "Today's Mess Menu",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'No meals scheduled for today',
                style: TextStyle(color: AppColors.grey600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: AppColors.secondary),
                const SizedBox(width: 8),
                const Text(
                  "Today's Mess Menu",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Optional: Show menu date
                if (menu['date'] != null)
                  Text(
                    menu['date'],
                    style: TextStyle(fontSize: 12, color: AppColors.grey600),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasBreakfast)
              _buildMenuSection('Breakfast', breakfastItems, Icons.free_breakfast, Colors.orange),
            if (hasLunch)
              _buildMenuSection('Lunch', lunchItems, Icons.lunch_dining, Colors.green),
            if (hasDinner)
              _buildMenuSection('Dinner', dinnerItems, Icons.dinner_dining, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(String title, List<String> items, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} items',
                  style: TextStyle(fontSize: 10, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(item, style: TextStyle(fontSize: 12, color: color)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER METHODS ====================

  List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  double _getAttendancePercentage() {
    try {
      final directPercentage = _dashboardData['attendancePercentage'];
      if (directPercentage is double) return directPercentage;
      if (directPercentage is int) return directPercentage.toDouble();
      if (directPercentage is num) return directPercentage.toDouble();
      
      final attendance = _dashboardData['attendance'];
      if (attendance != null && attendance is Map) {
        final percentage = attendance['percentage'];
        if (percentage is double) return percentage;
        if (percentage is int) return percentage.toDouble();
        if (percentage is num) return percentage.toDouble();
      }
      
      return 0.0;
    } catch (e) {
      debugPrint('Error getting attendance percentage: $e');
      return 0.0;
    }
  }
  
  int _getMealsTakenCount() {
    int count = 0;
    try {
      final mealStatus = _dashboardData['mealStatus'];
      if (mealStatus == null) return 0;
      if (mealStatus is! Map) return 0;
      
      final breakfast = mealStatus['breakfast'];
      if (breakfast != null && breakfast is Map && breakfast['taken'] == true) count++;
      
      final lunch = mealStatus['lunch'];
      if (lunch != null && lunch is Map && lunch['taken'] == true) count++;
      
      final dinner = mealStatus['dinner'];
      if (dinner != null && dinner is Map && dinner['taken'] == true) count++;
    } catch (e) {
      return 0;
    }
    return count;
  }

Widget _buildComplaintTile(ComplaintModel complaint) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
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
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Leading Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: complaint.statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                complaint.statusIcon,
                color: complaint.statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            
            // Content (Title and subtitle)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint.title ?? 'Untitled Complaint',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Complaint number and date in a wrap
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '#${complaint.complaintNumber ?? complaint.id?.substring(0, 8) ?? ''}',
                        style: TextStyle(color: AppColors.grey600, fontSize: 11),
                      ),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.grey400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        _formatDate(complaint.createdAt),
                        style: TextStyle(color: AppColors.grey500, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: complaint.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                complaint.statusString,
                style: TextStyle(
                  color: complaint.statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
String _formatDate(Timestamp? timestamp) {
  if (timestamp == null) return 'Recently';
  final date = timestamp.toDate();
  final now = DateTime.now();
  final difference = now.difference(date);
  
  if (difference.inDays > 7) {
    return '${difference.inDays} days ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  } else {
    return 'Just now';
  }
}
Future<void> _loadComplaints() async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final complaintProvider = Provider.of<ComplaintProvider>(context, listen: false);
  final userId = authProvider.user?.uid;
  final role = authProvider.user?.roleString;
  
  if (userId == null) return;
  
  try {
    if (role == 'Student') {
      await complaintProvider.loadStudentComplaints(userId);
    } else if (role == 'Admin' || role == 'Mess Staff') {
      await complaintProvider.loadAllComplaints();
    }
    debugPrint('Complaints loaded: ${complaintProvider.complaints.length}');
  } catch (e) {
    debugPrint('Error loading complaints: $e');
  }
}
}