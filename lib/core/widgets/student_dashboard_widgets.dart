import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/mess_provider.dart';
import '../../../routes/app_routes.dart';

class StudentDashboardWidgets {
  // Smart Status Card - Combines Attendance + Meal Status
  static Widget buildSmartStatusCard({
    required BuildContext context,
    required Map<String, dynamic> attendance,
    required Map<String, dynamic> mealStatus,
    required List<Map<String, dynamic>> upcomingMeals,
  }) {
    final isCheckedIn = attendance['checkedIn'] == true;
    final checkInTime = attendance['checkInTime'] ?? '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isCheckedIn ? Colors.green.shade700 : AppColors.primary,
            isCheckedIn ? Colors.green.shade500 : AppColors.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isCheckedIn ? Colors.green : AppColors.primary).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Attendance Status Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCheckedIn ? Icons.check_circle : Icons.login,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCheckedIn ? 'Checked In' : 'Not Checked In',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isCheckedIn)
                        Text(
                          'Since $checkInTime',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.markAttendance);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: isCheckedIn ? Colors.green : AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isCheckedIn ? 'Check Out' : 'Check In'),
                ),
              ],
            ),
          ),
          
          // Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.2),
          ),
          
          // Meal Status Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Meals",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMealStatusIndicator(
                      'Breakfast',
                      mealStatus['breakfast']?['taken'] ?? false,
                      mealStatus['breakfast']?['valid'] ?? false,
                      Icons.free_breakfast,
                    ),
                    _buildMealStatusIndicator(
                      'Lunch',
                      mealStatus['lunch']?['taken'] ?? false,
                      mealStatus['lunch']?['valid'] ?? false,
                      Icons.lunch_dining,
                    ),
                    _buildMealStatusIndicator(
                      'Dinner',
                      mealStatus['dinner']?['taken'] ?? false,
                      mealStatus['dinner']?['valid'] ?? false,
                      Icons.dinner_dining,
                    ),
                  ],
                ),
                if (upcomingMeals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getNextMealText(upcomingMeals),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
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
        ],
      ),
    );
  }

  static Widget _buildMealStatusIndicator(String label, bool taken, bool valid, IconData icon) {
    Color color;
    if (taken) {
      color = Colors.green;
    } else if (valid) {
      color = Colors.orange;
    } else {
      color = Colors.white.withOpacity(0.5);
    }

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: taken ? 0 : 2),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: taken ? Colors.green : (valid ? Colors.orange : Colors.white70),
            fontSize: 10,
            fontWeight: taken ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (taken)
          const Icon(Icons.check_circle, size: 12, color: Colors.white)
        else if (valid)
          Text('Active', style: TextStyle(color: Colors.orange, fontSize: 8))
        else
          Text('Inactive', style: TextStyle(color: Colors.white54, fontSize: 8)),
      ],
    );
  }

  static String _getNextMealText(List<Map<String, dynamic>> upcomingMeals) {
    for (var meal in upcomingMeals) {
      if (meal['status'] == 'active') {
        return '${meal['name']} ends in ${meal['timeRemaining']}';
      }
    }
    for (var meal in upcomingMeals) {
      if (meal['status'] == 'upcoming') {
        return '${meal['name']} starts in ${meal['timeRemaining']}';
      }
    }
    return 'No upcoming meals';
  }

  // ✅ FIXED: Quick Stats Card with proper spacing
  static Widget buildQuickStatsCard({
    required double attendancePercentage,
    required int mealsTaken,
    required int activeComplaints,
    required Map<String, dynamic> feeStatus,
  }) {
    final displayPercentage = attendancePercentage > 0 
        ? '${attendancePercentage.toStringAsFixed(1)}%' 
        : '0.0%';
    
    String feeText = feeStatus['status'] ?? 'N/A';
    Color feeColor = feeStatus['hasPending'] == true ? Colors.red : Colors.green;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Stats',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ FIXED: Use Row with flexible children
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildStatColumn('Attendance', displayPercentage, _getAttendanceColor(attendancePercentage)),
              ),
              Expanded(
                child: _buildStatColumn('Meals', mealsTaken.toString(), Colors.orange),
              ),
              Expanded(
                child: _buildStatColumn('Complaints', activeComplaints.toString(), Colors.red),
              ),
              Expanded(
                child: _buildStatColumn('Fee', feeText, feeColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _getAttendanceColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  // ✅ FIXED: Simplified _buildStatColumn without width parameter
  static Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: AppColors.grey600, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Quick Actions Grid
  static Widget buildQuickActionsGrid(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flash_on, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickActionChip(context, 'Mark Attendance', Icons.fingerprint, AppRoutes.attendance),
              _buildQuickActionChip(context, 'Mess Token', Icons.qr_code_scanner, AppRoutes.messToken),
              _buildQuickActionChip(context, 'My Room', Icons.meeting_room, AppRoutes.myRoom),
              _buildQuickActionChip(context, 'Raise Complaint', Icons.add_alert, AppRoutes.raiseComplaint),
              _buildQuickActionChip(context, 'Pay Fees', Icons.payment, AppRoutes.feePayment),
              _buildQuickActionChip(context, 'Chat Assistant', Icons.smart_toy, AppRoutes.chatbot),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildQuickActionChip(BuildContext context, String label, IconData icon, String route) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => Navigator.pushNamed(context, route),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      labelStyle: TextStyle(color: AppColors.primary),
    );
  }
}