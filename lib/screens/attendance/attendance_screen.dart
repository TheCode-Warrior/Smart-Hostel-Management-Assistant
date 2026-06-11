import 'package:flutter/material.dart';
import 'package:fyp_2026/core/models/attendance_model.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/attendance_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      await attendanceProvider.loadAttendanceOverview(
        authProvider.user!.uid!,
        days: 30,
        months: 1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final todayAttendance = attendanceProvider.todayAttendance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.attendanceHistory);
            },
          ),
        ],
      ),
      body: attendanceProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Overview',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Quick view of today and recent presence',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _buildHeaderMetric(
                                'Attendance',
                                '${attendanceProvider.attendancePercentage.toStringAsFixed(1)}%',
                              ),
                              const SizedBox(width: 10),
                              _buildHeaderMetric(
                                'Today',
                                attendanceProvider.todayAttendance?['checkedIn'] == true ? 'Active' : 'Not in',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Today',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildTodayCard(context, todayAttendance),
                    const SizedBox(height: 20),

                    // Statistics
                    _buildStatistics(context, attendanceProvider.attendanceStats),
                    const SizedBox(height: 20),

                    // Recent Attendance
                    _buildRecentAttendance(context, attendanceProvider.attendanceHistory),
                  ],
                ),
              ),
            ),
    );
  }

  // In attendance_screen.dart, update the _buildTodayCard method

Widget _buildTodayCard(BuildContext context, Map<String, dynamic>? today) {
  bool isCheckedIn = today?['checkedIn'] ?? false;
  bool isCheckedOut = today?['checkedOut'] ?? false;
  
  // Add this to show today's status correctly
  String todayStatus = 'Not Checked In';
  if (isCheckedIn && !isCheckedOut) {
    todayStatus = 'Checked In';
  } else if (isCheckedOut) {
    todayStatus = 'Checked Out';
  }

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Today\'s Attendance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCheckedIn 
                    ? (isCheckedOut ? Colors.grey.withOpacity(0.3) : Colors.green.withOpacity(0.3))
                    : Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                todayStatus,
                style: TextStyle(
                  color: isCheckedIn 
                      ? (isCheckedOut ? Colors.white70 : Colors.white)
                      : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTimeStatus(
              'Check In',
              today?['checkInTime'] != null
                  ? DateFormat('hh:mm a').format(today!['checkInTime'].toDate())
                  : '--:--',
              isCheckedIn ? Colors.green : Colors.white70,
              Icons.login,
            ),
            Container(
              height: 40,
              width: 2,
              color: Colors.white30,
            ),
            _buildTimeStatus(
              'Check Out',
              today?['checkOutTime'] != null
                  ? DateFormat('hh:mm a').format(today!['checkOutTime'].toDate())
                  : '--:--',
              isCheckedOut ? Colors.green : Colors.white70,
              Icons.logout,
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: (!isCheckedOut)
                    ? () {
                        Navigator.pushNamed(context, AppRoutes.markAttendance);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  isCheckedOut ? 'Completed' : (isCheckedIn ? 'Check Out' : 'Check In'),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
  Widget _buildHeaderMetric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeStatus(String label, String time, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics(BuildContext context, Map<String, dynamic> stats) {
    return Container(
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
            'Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Present',
                '${stats['presentDays'] ?? 0}',
                Colors.green,
              ),
              _buildStatItem(
                'Absent',
                '${stats['absentDays'] ?? 0}',
                Colors.red,
              ),
              _buildStatItem(
                'Late',
                '${stats['lateDays'] ?? 0}',
                Colors.orange,
              ),
              _buildStatItem(
                'Half Day',
                '${stats['halfDays'] ?? 0}',
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (stats['attendancePercentage'] ?? 0) / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              (stats['attendancePercentage'] ?? 0) >= 75
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance Rate',
                style: TextStyle(color: AppColors.grey600),
              ),
              Text(
                '${stats['attendancePercentage']?.toStringAsFixed(1) ?? 0}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildRecentAttendance(BuildContext context, List<dynamic> history) {
    if (history.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Attendance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...history.take(4).map((record) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.grey200),
            ),
            elevation: 0,
            color: Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(record.status).withOpacity(0.1),
                child: Icon(
                  _getStatusIcon(record.status),
                  color: _getStatusColor(record.status),
                  size: 20,
                ),
              ),
              title: Text(
                DateFormat('EEEE, dd MMM').format(record.date.toDate()),
              ),
              subtitle: Text(
                'In: ${record.checkInTime != null ? DateFormat('hh:mm a').format(record.checkInTime.toDate()) : '--'} | '
                'Out: ${record.checkOutTime != null ? DateFormat('hh:mm a').format(record.checkOutTime.toDate()) : '--'}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(record.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusLabel(record.status).toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(record.status),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  String _statusKey(dynamic status) {
    if (status is String) {
      return status.toLowerCase();
    }

    if (status is AttendanceStatus) {
      switch (status) {
        case AttendanceStatus.present:
          return 'present';
        case AttendanceStatus.absent:
          return 'absent';
        case AttendanceStatus.late:
          return 'late';
        case AttendanceStatus.halfDay:
          return 'half-day';
        case AttendanceStatus.holiday:
          return 'holiday';
      }
    }

    return 'unknown';
  }

  String _getStatusLabel(dynamic status) {
    switch (_statusKey(status)) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'late':
        return 'Late';
      case 'half-day':
        return 'Half Day';
      case 'holiday':
        return 'Holiday';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(dynamic status) {
    switch (_statusKey(status)) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'half-day':
        return Colors.blue;
      case 'holiday':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(dynamic status) {
    switch (_statusKey(status)) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.access_time;
      case 'half-day':
        return Icons.wb_sunny;
      case 'holiday':
        return Icons.celebration;
      default:
        return Icons.help;
    }
  }
}