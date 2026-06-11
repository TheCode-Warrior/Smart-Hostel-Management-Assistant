import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/colors.dart';
import '../../../routes/app_routes.dart';

class MessStaffDashboardWidgets {
  // Today's Overview Card
  static Widget buildTodayOverviewCard(Map<String, dynamic> stats) {
    // Safely extract consumption data
    final consumption = stats['mealConsumption'];
    final breakfastCount = _getSafeInt(consumption, 'breakfast');
    final lunchCount = _getSafeInt(consumption, 'lunch');
    final dinnerCount = _getSafeInt(consumption, 'dinner');
    
    // Safely extract active meals data
    final activeMeals = stats['activeMealTimings'];
    
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
              _buildOverviewStat('Breakfast', breakfastCount.toString(), Colors.orange),
              _buildOverviewStat('Lunch', lunchCount.toString(), Colors.green),
              _buildOverviewStat('Dinner', dinnerCount.toString(), Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getActiveMealText(activeMeals),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
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

  static String _getActiveMealText(dynamic activeMeals) {
    try {
      if (activeMeals == null) return 'No active meal at this time';
      
      Map<String, dynamic> mealsMap;
      if (activeMeals is Map) {
        mealsMap = Map<String, dynamic>.from(activeMeals);
      } else {
        return 'No active meal at this time';
      }
      
      for (var entry in mealsMap.entries) {
        final mealData = entry.value;
        if (mealData is Map) {
          final isActive = mealData['isActive'] == true;
          if (isActive) {
            final start = mealData['start'] ?? '--:--';
            final end = mealData['end'] ?? '--:--';
            return '${entry.key.toUpperCase()} active now ($start - $end)';
          }
        }
      }
      return 'No active meal at this time';
    } catch (e) {
      debugPrint('Error getting active meal text: $e');
      return 'No active meal at this time';
    }
  }

  static int _getSafeInt(dynamic map, String key) {
    try {
      if (map == null) return 0;
      if (map is Map) {
        final value = map[key];
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        if (value is num) return value.toInt();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Mess Staff Quick Actions
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
                child: const Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mess Operations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionChip(context, 'Scan QR', Icons.qr_code_scanner, AppRoutes.scanMess),
              _buildActionChip(context, 'Mess Menu', Icons.menu_book, AppRoutes.messMenuManagement),
              _buildActionChip(context, 'Consumption Reports', Icons.analytics, AppRoutes.consumptionReports),
              _buildActionChip(context, 'Mess Status', Icons.info, AppRoutes.messManagement),
              _buildActionChip(context, 'Meal History', Icons.history, AppRoutes.mealHistory),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildActionChip(BuildContext context, String label, IconData icon, String route) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () => Navigator.pushNamed(context, route),
      backgroundColor: AppColors.primary.withOpacity(0.1),
      labelStyle: TextStyle(color: AppColors.primary),
    );
  }

  // Recent Scans Card
  static Widget buildRecentScansCard(List<Map<String, dynamic>> scans) {
    if (scans.isEmpty) return const SizedBox();

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
                child: const Icon(Icons.history, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Recent Scans',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...scans.map((scan) => _buildScanTile(scan)).toList(),
        ],
      ),
    );
  }

  static Widget _buildScanTile(Map<String, dynamic> scan) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.withOpacity(0.1),
        child: const Icon(Icons.check_circle, color: Colors.green, size: 18),
      ),
      title: Text(
        scan['studentName'] ?? '',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${scan['mealType'] ?? 'Meal'} • ${scan['counter'] ?? 'Counter'}',
        style: TextStyle(fontSize: 11, color: AppColors.grey600),
      ),
      trailing: Text(
        scan['time'] ?? '',
        style: TextStyle(color: AppColors.grey500, fontSize: 11),
      ),
    );
  }

  // ==================== NEW: Student List Section ====================
  
  static Widget buildStudentListSection() {
    return const _StudentListWidget();
  }
}

// ==================== Student List Widget ====================

class _StudentListWidget extends StatefulWidget {
  const _StudentListWidget();

  @override
  State<_StudentListWidget> createState() => _StudentListWidgetState();
}

class _StudentListWidgetState extends State<_StudentListWidget> {
  String _selectedMeal = 'breakfast';
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _error;

  final Map<String, dynamic> _mealInfo = {
    'breakfast': {'label': 'Breakfast', 'color': Colors.orange},
    'lunch': {'label': 'Lunch', 'color': Colors.green},
    'dinner': {'label': 'Dinner', 'color': Colors.blue},
  };

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      
      final studentsSnapshot = await FirebaseFirestore.instance.collection('students').get();
      List<Map<String, dynamic>> studentList = [];

      for (var doc in studentsSnapshot.docs) {
        final data = doc.data();
        
        // Check if fee paid for current month
        final fees = Map<String, bool>.from(data['messMonthlyFees'] ?? {});
        if (fees[currentMonth] != true) continue;
        
        // Check if subscribed to this meal
        final subDoc = await FirebaseFirestore.instance
            .collection('mealSubscriptions')
            .doc('${doc.id}_$currentMonth')
            .get();
        
        bool isSubscribed = false;
        if (subDoc.exists) {
          final meals = List<String>.from(subDoc.data()?['subscribedMeals'] ?? []);
          isSubscribed = meals.contains(_selectedMeal);
        }
        
        if (!isSubscribed) continue;
        
        // Check if served already
        final mealCycle = '$today-${_selectedMeal}';
        final tokenQuery = await FirebaseFirestore.instance
            .collection('messTokens')
            .where('studentId', isEqualTo: doc.id)
            .where('mealCycle', isEqualTo: mealCycle)
            .get();
        
        bool isServed = false;
        if (tokenQuery.docs.isNotEmpty) {
          isServed = tokenQuery.docs.first.data()['isUsed'] == true;
        }
        
        studentList.add({
          'name': data['fullName'] ?? 'Unknown',
          'room': data['roomNumber'] ?? 'N/A',
          'enrollment': data['enrollmentNo'] ?? 'N/A',
          'status': isServed ? 'Served' : 'Pending',
        });
      }
      
      // Sort by room number
      studentList.sort((a, b) => a['room'].toString().compareTo(b['room'].toString()));
      
      setState(() {
        _students = studentList;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int get _totalCount => _students.length;
  int get _servedCount => _students.where((s) => s['status'] == 'Served').length;
  int get _pendingCount => _students.where((s) => s['status'] == 'Pending').length;

 @override
Widget build(BuildContext context) {
  final meal = _mealInfo[_selectedMeal]!;
  
  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(12),
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
        // Header with Meal Selection - FIXED
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant_menu, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Student Meal Status',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: meal['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: meal['color'].withOpacity(0.3)),
              ),
              child: DropdownButton<String>(
                value: _selectedMeal,
                underline: const SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: meal['color'], size: 20),
                isDense: true,
                style: TextStyle(color: meal['color'], fontSize: 11),
                items: _mealInfo.keys.map((key) {
                  return DropdownMenuItem(
                    value: key,
                    child: Text(
                      _mealInfo[key]['label'],
                      style: TextStyle(color: meal['color'], fontSize: 11),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedMeal = value;
                      _loadStudentData();
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Stats Cards Row
        Row(
          children: [
            Expanded(child: _buildStatCard('Total', '$_totalCount', Icons.people, AppColors.primary)),
            const SizedBox(width: 6),
            Expanded(child: _buildStatCard('Served', '$_servedCount', Icons.check_circle, Colors.green)),
            const SizedBox(width: 6),
            Expanded(child: _buildStatCard('Pending', '$_pendingCount', Icons.pending, Colors.orange)),
          ],
        ),
        const SizedBox(height: 10),
        
      
        // Student List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Student List (${_students.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (_pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_pendingCount pending',
                  style: const TextStyle(color: Colors.orange, fontSize: 10),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Student List
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(
            child: Column(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 40),
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _loadStudentData,
                  child: const Text('Retry', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          )
        else if (_students.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.restaurant, size: 32, color: AppColors.grey300),
                  const SizedBox(height: 4),
                  Text(
                    'No students for ${meal['label']}',
                    style: TextStyle(color: AppColors.grey600, fontSize: 11),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _students.length,
            itemBuilder: (context, index) {
              final s = _students[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: s['status'] == 'Served'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    child: Icon(
                      s['status'] == 'Served' ? Icons.check : Icons.pending,
                      size: 12,
                      color: s['status'] == 'Served' ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(
                    s['name'],
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Room: ${s['room']} | Enroll: ${s['enrollment']}',
                    style: const TextStyle(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: s['status'] == 'Served'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      s['status'],
                      style: TextStyle(
                        color: s['status'] == 'Served' ? Colors.green : Colors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: AppColors.grey600),
            ),
          ],
        ),
      ),
    );
  }
}