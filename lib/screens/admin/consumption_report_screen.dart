import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/colors.dart';
import '../../core/services/mess_menu_service.dart';

class ConsumptionReportScreen extends StatefulWidget {
  const ConsumptionReportScreen({Key? key}) : super(key: key);

  @override
  State<ConsumptionReportScreen> createState() => _ConsumptionReportScreenState();
}

class _ConsumptionReportScreenState extends State<ConsumptionReportScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, int> _dailyReport = {'breakfast': 0, 'lunch': 0, 'dinner': 0};
  Map<String, Map<String, int>> _weeklyReport = {};
  Map<String, int> _subscriptionCounts = {'breakfast': 0, 'lunch': 0, 'dinner': 0};
  int _paidSubscriptions = 0;
  int _totalSubscriptions = 0;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  String _monthKey(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }

  DateTime _startOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final weekStart = _startOfWeek(_selectedDate);
      final monthKey = _monthKey(_selectedDate);

      final daily = await MessMenuService.getDailyConsumptionReport(
        DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
      final weekly = await MessMenuService.getWeeklyConsumptionReport(weekStart);
      final subscriptionSummary = await _loadSubscriptionSummary(monthKey);

      if (!mounted) return;
      setState(() {
        _dailyReport = daily;
        _weeklyReport = weekly;
        _subscriptionCounts = subscriptionSummary['mealCounts'] as Map<String, int>;
        _paidSubscriptions = subscriptionSummary['paidCount'] as int;
        _totalSubscriptions = subscriptionSummary['totalCount'] as int;
      });
    } catch (e) {
      if (mounted) {
        // Fallback to empty reports on error (e.g., permission denied)
        setState(() {
          _dailyReport = {'breakfast': 0, 'lunch': 0, 'dinner': 0};
          _weeklyReport = {};
          _subscriptionCounts = {'breakfast': 0, 'lunch': 0, 'dinner': 0};
          _paidSubscriptions = 0;
          _totalSubscriptions = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reports: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadSubscriptionSummary(String month) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('mealSubscriptions')
        .where('month', isEqualTo: month)
        .get();

    final mealCounts = <String, int>{
      'breakfast': 0,
      'lunch': 0,
      'dinner': 0,
    };

    int paidCount = 0;
    int totalCount = snapshot.docs.length;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['isPaid'] == true) {
        paidCount++;
      }

      final meals = List<String>.from(data['subscribedMeals'] ?? []);
      for (final meal in meals) {
        final key = meal.toLowerCase();
        mealCounts[key] = (mealCounts[key] ?? 0) + 1;
      }
    }

    return {
      'mealCounts': mealCounts,
      'paidCount': paidCount,
      'totalCount': totalCount,
    };
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadReports();
    }
  }

  double _ratio(int consumed, int subscribed) {
    if (subscribed <= 0) return 0;
    return consumed / subscribed;
  }

  int _weeklyTotalForMeal(String mealType) {
    return _weeklyReport.values.fold<int>(0, (sum, daily) => sum + (daily[mealType] ?? 0));
  }

  int _weeklyGrandTotal() {
    return _weeklyReport.values.fold<int>(0, (sum, daily) {
      return sum + (daily['breakfast'] ?? 0) + (daily['lunch'] ?? 0) + (daily['dinner'] ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedDate);
    final selectedDayLabel = DateFormat('dd MMM yyyy').format(_selectedDate);
    final weekStart = _startOfWeek(_selectedDate);
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consumption Reports'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadReports,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateHeader(monthLabel, selectedDayLabel, weekStart, weekEnd),
                    const SizedBox(height: 16),
                    _buildSubscriptionSummaryCard(monthLabel),
                    const SizedBox(height: 16),
                    _buildMealSummaryCard(
                      title: 'Daily Consumption',
                      counts: _dailyReport,
                      subtitle: 'Consumed on $selectedDayLabel',
                    ),
                    const SizedBox(height: 16),
                    _buildMealSummaryCard(
                      title: 'Weekly Consumption',
                      counts: {
                        'breakfast': _weeklyTotalForMeal('breakfast'),
                        'lunch': _weeklyTotalForMeal('lunch'),
                        'dinner': _weeklyTotalForMeal('dinner'),
                      },
                      subtitle: 'From ${DateFormat('dd MMM').format(weekStart)} to ${DateFormat('dd MMM').format(weekEnd)}',
                    ),
                    const SizedBox(height: 16),
                    _buildDailyBreakdownCard(),
                    const SizedBox(height: 16),
                    _buildWeeklyBreakdownCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateHeader(String monthLabel, String dayLabel, DateTime weekStart, DateTime weekEnd) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mess Consumption Dashboard',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Month: $monthLabel',
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          Text(
            'Selected day: $dayLabel',
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          Text(
            'Week: ${DateFormat('dd MMM').format(weekStart)} - ${DateFormat('dd MMM').format(weekEnd)}',
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.date_range, color: Colors.white),
            label: const Text('Change Date', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSummaryCard(String monthLabel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
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
          Text(
            'Subscription vs Attendance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Paid subscriptions for $monthLabel',
            style: TextStyle(color: AppColors.grey600, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Paid',
                  _paidSubscriptions.toString(),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total',
                  _totalSubscriptions.toString(),
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Consumed Today',
                  ((_dailyReport['breakfast'] ?? 0) + (_dailyReport['lunch'] ?? 0) + (_dailyReport['dinner'] ?? 0)).toString(),
                  AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...['breakfast', 'lunch', 'dinner'].map((meal) {
            final consumed = _dailyReport[meal] ?? 0;
            final subscribed = _subscriptionCounts[meal] ?? 0;
            final pct = _ratio(consumed, subscribed);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_label(meal), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('$consumed / $subscribed'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: AppColors.grey200,
                      valueColor: AlwaysStoppedAnimation<Color>(_mealColor(meal)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${(pct * 100).toStringAsFixed(0)}% of subscribed meals consumed today', style: TextStyle(fontSize: 12, color: AppColors.grey600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMealSummaryCard({
    required String title,
    required Map<String, int> counts,
    required String subtitle,
  }) {
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: AppColors.grey600, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Breakfast', (counts['breakfast'] ?? 0).toString(), Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Lunch', (counts['lunch'] ?? 0).toString(), Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Dinner', (counts['dinner'] ?? 0).toString(), Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total meals', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(total.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daily Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...['breakfast', 'lunch', 'dinner'].map((meal) {
            final count = _dailyReport[meal] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: _mealColor(meal), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_label(meal))),
                  Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeeklyBreakdownCard() {
    final entries = _weeklyReport.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text('No weekly records found.', style: TextStyle(color: AppColors.grey600))
          else
            ...entries.map((entry) {
              final dayLabel = DateFormat('EEE, dd MMM').format(DateTime.parse(entry.key));
              final total = (entry.value['breakfast'] ?? 0) + (entry.value['lunch'] ?? 0) + (entry.value['dinner'] ?? 0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Total: $total', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Breakfast: ${entry.value['breakfast'] ?? 0}  |  Lunch: ${entry.value['lunch'] ?? 0}  |  Dinner: ${entry.value['dinner'] ?? 0}', style: TextStyle(fontSize: 12, color: AppColors.grey600)),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Weekly total', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(_weeklyGrandTotal().toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color.withOpacity(0.85))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _label(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return mealType;
    }
  }

  Color _mealColor(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }
}
