import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/mess_menu_model.dart';
import '../../core/services/mess_menu_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/colors.dart';

class MealSubscriptionScreen extends StatefulWidget {
  const MealSubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<MealSubscriptionScreen> createState() => _MealSubscriptionScreenState();
}

class _MealSubscriptionScreenState extends State<MealSubscriptionScreen> {
  late String _currentMonth;
  final Set<String> _selectedMeals = {};
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;
  MessMenuModel? _currentMenu;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    _loadCurrentMenu();
    _loadExistingSubscription();
  }

  Future<void> _loadCurrentMenu() async {
    try {
      final menu = await MessMenuService.getCurrentWeekMenu();
      setState(() {
        _currentMenu = menu;
      });
    } catch (e) {
      print('Error loading menu: $e');
    }
  }

  Future<void> _loadExistingSubscription() async {
    try {
      final studentId = context.read<AuthProvider>().user?.uid ?? '';
      final subscription =
          await MessMenuService.getStudentSubscription(studentId, _currentMonth);

      if (subscription != null) {
        setState(() {
          _selectedMeals.addAll(subscription.subscribedMeals);
        });
      }
    } catch (e) {
      print('Error loading subscription: $e');
    }
  }

  void _toggleMealSelection(String mealType) {
    setState(() {
      if (_selectedMeals.contains(mealType)) {
        _selectedMeals.remove(mealType);
      } else {
        _selectedMeals.add(mealType);
      }
    });
  }

  double _calculateTotalCost() {
    // Cost per meal type per month (customize as needed)
    const costPerMeal = 1500.0;
    return _selectedMeals.length * costPerMeal;
  }

  Future<void> _saveSubscription() async {
    if (_selectedMeals.isEmpty) {
      _showErrorMessage('Please select at least one meal');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final studentId = context.read<AuthProvider>().user?.uid ?? '';
      final totalCost = _calculateTotalCost();

      await MessMenuService.saveMealSubscription(
        studentId,
        _currentMonth,
        _selectedMeals.toList(),
        totalCost,
      );

      _showSuccessMessage('Subscription saved successfully!');
    } catch (e) {
      _showErrorMessage('Failed to save subscription: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessMessage(String message) {
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _successMessage = null;
        });
      }
    });
  }

  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  String _formatMealType(String type) {
    return type[0].toUpperCase() + type.substring(1);
  }

  String _formatMonthDisplay(String month) {
    try {
      final date = DateFormat('yyyy-MM').parse(month);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return month;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Subscription'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success/Error Messages
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Month info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                border: Border.all(color: AppColors.primary, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subscription For',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          _formatMonthDisplay(_currentMonth),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Meal selection section
            Text(
              'Select Your Meals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose which meals you want to subscribe to for this month',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Meal option cards
            ...[
              ('breakfast', Icons.free_breakfast, 'Breakfast (7-9 AM)'),
              ('lunch', Icons.lunch_dining, 'Lunch (12-2 PM)'),
              ('dinner', Icons.dinner_dining, 'Dinner (7-9 PM)'),
            ].map((meal) {
              final mealType = meal.$1;
              final icon = meal.$2;
              final label = meal.$3;
              final isSelected = _selectedMeals.contains(mealType);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMealCard(
                  mealType,
                  icon,
                  label,
                  isSelected,
                ),
              );
            }).toList(),

            const SizedBox(height: 24),

            // Menu preview
            if (_currentMenu != null && _selectedMeals.isNotEmpty) ...[
              Text(
                'Menu Preview',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ..._selectedMeals.map((mealType) {
                final items = _currentMenu!.getMealItems(mealType);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildMenuPreviewCard(mealType, items),
                );
              }).toList(),
              const SizedBox(height: 24),
            ],

            // Cost summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Selected Meals',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        '${_selectedMeals.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Cost',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rs. ${_calculateTotalCost().toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Subscription',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(
    String mealType,
    IconData icon,
    String label,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => _toggleMealSelection(mealType),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : Colors.black,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuPreviewCard(String mealType, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatMealType(mealType),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
