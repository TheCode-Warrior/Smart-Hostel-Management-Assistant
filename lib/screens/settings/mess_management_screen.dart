import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/mess_provider.dart';
import '../../routes/app_routes.dart';

class MessManagementScreen extends StatefulWidget {
  const MessManagementScreen({Key? key}) : super(key: key);

  @override
  _MessManagementScreenState createState() => _MessManagementScreenState();
}

class _MessManagementScreenState extends State<MessManagementScreen> {
  bool _isRefreshingTokens = false;
  String? _successMessage;
  String? _errorMessage;


  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshTokens() async {
    setState(() {
      _isRefreshingTokens = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      final messProvider = Provider.of<MessProvider>(context, listen: false);
      await messProvider.generateTokensForCurrentMealTime();

      if (!mounted) return;
      _showMessage('Tokens refreshed successfully ✓', isError: false);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to refresh tokens: $e', isError: true);
    } finally {
      setState(() => _isRefreshingTokens = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    setState(() {
      if (isError) {
        _errorMessage = message;
        _successMessage = null;
      } else {
        _successMessage = message;
        _errorMessage = null;
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _successMessage = null;
          _errorMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Token Generation'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh any data if needed
        },
        color: Colors.white,
        backgroundColor: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Messages
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_successMessage!)),
                    ],
                  ),
                ),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!)),
                    ],
                  ),
                ),
              if (_successMessage != null || _errorMessage != null)
                const SizedBox(height: 16),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.1), AppColors.secondary.withOpacity(0.1)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('How it Works', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                'Tokens are automatically generated for all students who have paid fees for the current month during active meal times.',
                                style: TextStyle(fontSize: 12, color: AppColors.grey700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Refresh Tokens Section
              Text(
                'Generate Tokens',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Click to generate meal tokens for the currently active flexible meal time from Hostel Settings',
                      style: TextStyle(color: AppColors.grey700, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRefreshingTokens ? null : _refreshTokens,
                        icon: _isRefreshingTokens
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_isRefreshingTokens ? 'Generating...' : 'Generate Tokens Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ✅ FIXED: Consumption Reports - Now navigates to ReportGeneratorScreen
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text('Consumption Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'View daily, weekly, and monthly meal usage reports with charts and export options.',
                      style: TextStyle(fontSize: 13, color: AppColors.grey700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.reportGenerator), // ✅ FIXED
                        icon: const Icon(Icons.pie_chart_outline),
                        label: const Text('Open Reports'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Fee Management Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_outlined, color: Colors.amber[800], size: 20),
                        const SizedBox(width: 8),
                        const Text('Monthly Fee Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'To manage which students have paid fees each month:',
                      style: TextStyle(fontSize: 13, color: AppColors.grey700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.grey200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(child: Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Go to Hostel Settings', style: TextStyle(fontSize: 12, color: AppColors.grey800))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(child: Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Scroll to Monthly Fee Management', style: TextStyle(fontSize: 12, color: AppColors.grey800))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(child: Text('3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Toggle student fees by month', style: TextStyle(fontSize: 12, color: AppColors.grey800))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/hostel-settings');
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Go to Hostel Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Mess Menu Management
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text('Mess Menu Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create and update today\'s menu or the weekly breakfast, lunch, and dinner template.',
                      style: TextStyle(fontSize: 13, color: AppColors.grey700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.messMenuManagement),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Manage Mess Menu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Current Status
              _buildCurrentStatusCard(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('hostelSettings').doc('settings').snapshots(),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final messTimings = Map<String, dynamic>.from(data['messTimings'] ?? {});
        final activeMealsRaw = data['messActiveMealTypes'];
        final activeMeals = activeMealsRaw is List
            ? activeMealsRaw.map((e) => e.toString().toLowerCase()).toList()
            : messTimings.keys.map((e) => e.toString().toLowerCase()).toList();

        String mealStatus = 'No active meal';
        String statusDetail = 'Outside all configured meal windows';
        Color mealColor = Colors.grey;

        bool applyWindowStatus({
          required String key,
          required String label,
          required Color color,
          required String icon,
        }) {
          if (!activeMeals.contains(key)) return false;
          final mealTime = Map<String, dynamic>.from(messTimings[key] ?? {});
          final start = _parseTimeForToday(mealTime['start']?.toString());
          final end = _parseTimeForToday(mealTime['end']?.toString());
          if (start == null || end == null) return false;
          final isActive = !now.isBefore(start) && !now.isAfter(end);
          if (isActive) {
            mealStatus = '$icon $label time';
            statusDetail = 'Window: ${mealTime['start'] ?? '--:--'} to ${mealTime['end'] ?? '--:--'}';
            mealColor = color;
            return true;
          }
          return false;
        }

        final hasActive =
            applyWindowStatus(key: 'breakfast', label: 'Breakfast', color: Colors.orange, icon: '🥞') ||
            applyWindowStatus(key: 'lunch', label: 'Lunch', color: Colors.green, icon: '🍽️') ||
            applyWindowStatus(key: 'dinner', label: 'Dinner', color: Colors.blue, icon: '🍴');

        if (!hasActive && activeMeals.isNotEmpty) {
          statusDetail = 'Configured meals: ${activeMeals.join(', ')}';
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: mealColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: mealColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: mealColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mealStatus, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: mealColor)),
                        const SizedBox(height: 2),
                        Text(statusDetail, style: TextStyle(fontSize: 12, color: AppColors.grey700)),
                        const SizedBox(height: 2),
                        Text('Month: $currentMonth', style: TextStyle(fontSize: 12, color: AppColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime? _parseTimeForToday(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}