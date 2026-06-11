import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../routes/app_routes.dart';

class AdminDashboardWidgets {
  // Overview Stats Card
  static Widget buildOverviewStatsCard(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverviewStat('Present', '${stats['attendanceStats']?['checkedIn'] ?? 0}', Colors.green),
              _buildOverviewStat('Pending', '${stats['pendingComplaints'] ?? 0}', Colors.red),
              _buildOverviewStat('Requests', '${stats['pendingFeeRequests'] ?? 0}', Colors.orange),
              _buildOverviewStat('Rooms', '${stats['availableRooms'] ?? 0}', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildOverviewStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  // Meal Consumption Card
  static Widget buildMealConsumptionCard(Map<String, dynamic> stats) {
    final consumption = stats['mealConsumption'] ?? {};
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
                child: const Icon(Icons.restaurant, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Today's Meal Consumption",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMealStat('Breakfast', '${consumption['breakfast'] ?? 0}', Colors.orange),
              _buildMealStat('Lunch', '${consumption['lunch'] ?? 0}', Colors.green),
              _buildMealStat('Dinner', '${consumption['dinner'] ?? 0}', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildMealStat(String label, String value, Color color) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: AppColors.grey600, fontSize: 11)),
        ],
      ),
    );
  }

  // Admin Quick Actions
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
                child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Admin Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildAdminActionChip(context, 'Fee Requests', Icons.request_page, AppRoutes.feeRequests),
              _buildAdminActionChip(context, 'User Management', Icons.people, AppRoutes.userManagement),
              _buildAdminActionChip(context, 'Room Management', Icons.meeting_room, AppRoutes.rooms),
              _buildAdminActionChip(context, 'Mess Menu', Icons.menu_book, AppRoutes.messMenuManagement),
              _buildAdminActionChip(context, 'Hostel Settings', Icons.settings, AppRoutes.hostelSettings),
              _buildAdminActionChip(context, 'Announcements', Icons.campaign, AppRoutes.announcements),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildAdminActionChip(BuildContext context, String label, IconData icon, String route) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => Navigator.pushNamed(context, route),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      labelStyle: TextStyle(color: AppColors.primary),
    );
  }

 
 
}