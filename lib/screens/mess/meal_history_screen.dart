import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/mess_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/mess_token_model.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({Key? key}) : super(key: key);

  @override
  _MealHistoryScreenState createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<MessTokenModel>> _events = {};
  String? _selectedMealType;

  final List<String> _mealTypes = ['All', 'Breakfast', 'Lunch', 'Dinner'];

  DateTime get _firstDay => DateTime(2024, 1, 1);
  DateTime get _lastDay => DateTime(DateTime.now().year + 10, 12, 31, 23, 59, 59);

  DateTime _clampToCalendarRange(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    if (normalized.isBefore(_firstDay)) return _firstDay;
    if (normalized.isAfter(_lastDay)) return _lastDay;
    return normalized;
  }

  @override
  void initState() {
    super.initState();
    _focusedDay = _clampToCalendarRange(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final messProvider = Provider.of<MessProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      await messProvider.loadMealHistory(
        authProvider.user!.uid!,
        days: 90,
      );
      _prepareEvents(messProvider.tokens);
    }
  }

  void _prepareEvents(List<MessTokenModel> tokens) {
    _events = {};
    for (var token in tokens) {
      if (token.mealDate != null) {
        DateTime date = DateTime(
          token.mealDate!.toDate().year,
          token.mealDate!.toDate().month,
          token.mealDate!.toDate().day,
        );
        
        if (_events[date] == null) {
          _events[date] = [];
        }
        _events[date]!.add(token);
      }
    }
    setState(() {});
  }

  List<MessTokenModel> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  List<MessTokenModel> _getFilteredEvents() {
    if (_selectedDay == null) return [];
    
    List<MessTokenModel> events = _getEventsForDay(_selectedDay!);
    
    if (_selectedMealType != null && _selectedMealType != 'All') {
      events = events.where((e) {
        return e.mealTypeString == _selectedMealType;
      }).toList();
    }
    
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final messProvider = Provider.of<MessProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Meal History'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Changed to black color
                const Text(
                  'Track Your Meals',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Meal Type Filters
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mealTypes.length,
                    itemBuilder: (context, index) {
                      final type = _mealTypes[index];
                      final isSelected = _selectedMealType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedMealType = selected ? type : null;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.grey700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Colors.transparent : AppColors.grey300,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: messProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Calendar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TableCalendar(
                      firstDay: _firstDay,
                      lastDay: _lastDay,
                      focusedDay: _clampToCalendarRange(_focusedDay),
                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },
                      calendarFormat: _calendarFormat,
                      eventLoader: (day) => _getEventsForDay(day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = _clampToCalendarRange(selectedDay);
                          _focusedDay = _clampToCalendarRange(focusedDay);
                        });
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = _clampToCalendarRange(focusedDay);
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: TextStyle(color: AppColors.primary),
                        selectedDecoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        weekendTextStyle: const TextStyle(color: Colors.red),
                        defaultTextStyle: const TextStyle(fontSize: 14),
                        //weekendDefaultTextStyle: const TextStyle(fontSize: 14),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: true,
                        formatButtonDecoration: BoxDecoration(
                          border: Border.all(color: AppColors.primary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        formatButtonTextStyle: TextStyle(color: AppColors.primary),
                        titleCentered: true,
                        titleTextStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.primary),
                        rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.primary),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: const TextStyle(fontSize: 12),
                        weekendStyle: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ),

                  // Selected Day Summary
                  if (_selectedDay != null) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy').format(_selectedDay!),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE').format(_selectedDay!),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.restaurant, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_getEventsForDay(_selectedDay!).where((e) => e.isUsed == true).length}/${_getEventsForDay(_selectedDay!).length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Meal List
                  Expanded(
                    child: _selectedDay != null
                        ? _getFilteredEvents().isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.restaurant, size: 60, color: AppColors.grey300),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No meals on this day',
                                      style: TextStyle(
                                        color: AppColors.grey600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _getFilteredEvents().length,
                                itemBuilder: (context, index) {
                                  final meal = _getFilteredEvents()[index];
                                  return _buildMealCard(meal);
                                },
                              )
                        : _buildStatistics(messProvider.tokens),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMealCard(MessTokenModel meal) {
    final color = _getMealColor(meal.mealTypeString);
    final isUsed = meal.isUsed == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getMealIcon(meal.mealTypeString),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.mealTypeString,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('hh:mm a').format(meal.mealDate!.toDate()),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUsed
                        ? Colors.green.withOpacity(0.3)
                        : (meal.isValid
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUsed
                            ? Icons.check_circle
                            : (meal.isValid ? Icons.schedule : Icons.cancel),
                        color: isUsed
                            ? Colors.green
                            : (meal.isValid ? Colors.orange : Colors.red),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUsed
                            ? 'Taken'
                            : (meal.isValid ? 'Active' : 'Expired'),
                        style: TextStyle(
                          color: isUsed
                              ? Colors.green
                              : (meal.isValid ? Colors.orange : Colors.red),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Token Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailChip(
                      'Token ID',
                      meal.tokenCode ?? 'N/A',
                      Icons.qr_code,
                    ),
                    _buildDetailChip(
                      'Valid From',
                      DateFormat('hh:mm a').format(meal.validFrom!.toDate()),
                      Icons.access_time,
                    ),
                    _buildDetailChip(
                      'Valid Until',
                      DateFormat('hh:mm a').format(meal.validUntil!.toDate()),
                      Icons.timer,
                    ),
                  ],
                ),

                // Scan Details (if used)
                if (isUsed && meal.usedAt != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 10),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scanned at ${DateFormat('hh:mm a').format(meal.usedAt!.toDate())}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (meal.scannedAtLocation != null)
                                Text(
                                  'Counter: ${meal.scannedAtLocation}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.grey600,
                                  ),
                                ),
                            ],
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

  Widget _buildDetailChip(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 14, color: AppColors.grey600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.grey600,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics(List<MessTokenModel> tokens) {
    int totalMeals = tokens.length;
    int takenMeals = tokens.where((t) => t.isUsed == true).length;
    int missedMeals = tokens.where((t) => t.isUsed == false && !t.isValid).length;
    
    // Group by meal type
    Map<String, int> mealsByType = {};
    for (var token in tokens) {
      String type = token.mealTypeString;
      mealsByType[type] = (mealsByType[type] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.analytics, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Your Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary Cards Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Meals',
                  totalMeals.toString(),
                  Icons.restaurant,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Taken',
                  takenMeals.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Missed',
                  missedMeals.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'Attendance',
                  totalMeals > 0
                      ? '${((takenMeals / totalMeals) * 100).toStringAsFixed(1)}%'
                      : '0%',
                  Icons.pie_chart,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Meal Type Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meal Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...mealsByType.entries.map((entry) {
                  double percentage =
                      totalMeals > 0 ? (entry.value / totalMeals) * 100 : 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getMealIcon(entry.key),
                                  color: _getMealColor(entry.key),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${entry.value} meals',
                              style: TextStyle(
                                color: AppColors.grey600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.grey200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getMealColor(entry.key),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: AppColors.grey600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getMealColor(String mealType) {
    switch (mealType.toLowerCase()) {
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

  IconData _getMealIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }
}