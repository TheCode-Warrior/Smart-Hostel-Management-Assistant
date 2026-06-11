import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../core/services/mess_menu_service.dart';
import '../../core/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';
import '../../routes/app_routes.dart';

class MessMenuScreen extends StatefulWidget {
  const MessMenuScreen({Key? key}) : super(key: key);

  @override
  _MessMenuScreenState createState() => _MessMenuScreenState();
}

class _MessMenuScreenState extends State<MessMenuScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _menuData;
  bool _isLoading = false;
  Map<String, dynamic> _mealTimings = {};
  Map<String, dynamic> _activeMeals = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadMenu();
  }

  Future<void> _loadSettings() async {
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('hostelSettings')
          .doc('settings')
          .get();
      final settings = settingsDoc.data() ?? <String, dynamic>{};
      
      setState(() {
        _mealTimings = Map<String, dynamic>.from(settings['messTimings'] ?? {});
        final activeMealsRaw = settings['messActiveMealTypes'];
        _activeMeals = {};
        if (activeMealsRaw is List) {
          for (var meal in activeMealsRaw) {
            _activeMeals[meal.toString().toLowerCase()] = true;
          }
        }
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);

    try {
      final menu = await MessMenuService.getDailyMenu(_selectedDate);
      setState(() {
        _menuData = menu == null
            ? null
            : {
                'breakfast': {
                  'items': menu.breakfastItems,
                  'enabled': menu.isMealEnabled('breakfast'),
                },
                'lunch': {
                  'items': menu.lunchItems,
                  'enabled': menu.isMealEnabled('lunch'),
                },
                'dinner': {
                  'items': menu.dinnerItems,
                  'enabled': menu.isMealEnabled('dinner'),
                },
              };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _menuData = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });

      await _loadMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Menu'),
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: () async {
                await _loadSettings();
                await _loadMenu();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE').format(_selectedDate),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd MMMM yyyy').format(_selectedDate),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedDate.day == DateTime.now().day)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Today',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
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

                    // Breakfast
                    _buildMealSection(
                      'breakfast',
                      'Breakfast',
                      Icons.free_breakfast,
                      Colors.orange,
                    ),
                    const SizedBox(height: 16),

                    // Lunch
                    _buildMealSection(
                      'lunch',
                      'Lunch',
                      Icons.lunch_dining,
                      Colors.green,
                    ),
                    const SizedBox(height: 16),

                    // Dinner
                    _buildMealSection(
                      'dinner',
                      'Dinner',
                      Icons.dinner_dining,
                      Colors.blue,
                    ),
                    const SizedBox(height: 24),

                    // Quick Links
                    _buildQuickActionsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMealSection(
    String mealKey,
    String title,
    IconData icon,
    Color color,
  ) {
    final items = _getMealItems(mealKey);
    final timing = _getMealTiming(mealKey);
    final isActive = _isMealActive(mealKey);
    final isEnabled = _activeMeals[mealKey] ?? false;

    return Container(
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
        children: [
          // Header with gradient background
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.8),
                  color.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        timing,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : Colors.orange.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActive ? 'Active Now' : 'Coming',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Menu Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEnabled)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.lock_outline, size: 40, color: AppColors.grey400),
                          const SizedBox(height: 8),
                          Text(
                            'This meal is not available',
                            style: TextStyle(color: AppColors.grey600),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.restaurant_menu, size: 40, color: AppColors.grey400),
                          const SizedBox(height: 8),
                          Text(
                            'Menu not updated yet',
                            style: TextStyle(color: AppColors.grey600),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (index == 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '⭐ Special',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMealTiming(String mealKey) {
    final timing = _mealTimings[mealKey];
    if (timing is Map<String, dynamic>) {
      final start = timing['start']?.toString() ?? '--:--';
      final end = timing['end']?.toString() ?? '--:--';
      return '$start - $end';
    }
    return 'Timing not set';
  }

  bool _isMealActive(String mealKey) {
    if (!_activeMeals.containsKey(mealKey)) return false;
    
    final timing = _mealTimings[mealKey];
    if (timing is! Map<String, dynamic>) return false;
    
    final startStr = timing['start']?.toString();
    final endStr = timing['end']?.toString();
    
    if (startStr == null || endStr == null) return false;

    final now = DateTime.now();
    final startParts = startStr.split(':');
    final endParts = endStr.split(':');
    
    if (startParts.length != 2 || endParts.length != 2) return false;

    final startHour = int.tryParse(startParts[0]) ?? 0;
    final startMinute = int.tryParse(startParts[1]) ?? 0;
    final endHour = int.tryParse(endParts[0]) ?? 0;
    final endMinute = int.tryParse(endParts[1]) ?? 0;

    final startTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
    final endTime = DateTime(now.year, now.month, now.day, endHour, endMinute);

    return !now.isBefore(startTime) && !now.isAfter(endTime);
  }

  List<String> _getMealItems(String mealType) {
    final details = _menuData?[mealType];
    if (details is Map<String, dynamic>) {
      return List<String>.from(details['items'] ?? []);
    }
    return [];
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _showFeedbackDialog,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.feedback, color: AppColors.primary, size: 24),
                      const SizedBox(height: 8),
                      const Text(
                        'Feedback',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/meal-history'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.history, color: Colors.orange, size: 24),
                      const SizedBox(height: 8),
                      const Text(
                        'History',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  await _loadSettings();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.refresh, color: Colors.green, size: 24),
                      const SizedBox(height: 8),
                      const Text(
                        'Refresh',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFeedbackDialog() {
    int rating = 0;
    TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Meal Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was today\'s meal?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [1, 2, 3, 4, 5].map((r) {
                  return IconButton(
                    icon: Icon(
                      Icons.star,
                      color: r <= rating ? Colors.amber : AppColors.grey400,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        rating = r;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                decoration: InputDecoration(
                  hintText: 'Any suggestions?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.grey100,
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your feedback!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}