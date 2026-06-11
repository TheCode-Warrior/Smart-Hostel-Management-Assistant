import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/models/mess_menu_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/mess_provider.dart';
import '../../core/services/mess_menu_service.dart';
import '../../core/widgets/loading_indicator.dart';

enum _MenuMode { daily, weekly }

class MessMenuManagementScreen extends StatefulWidget {
  const MessMenuManagementScreen({Key? key}) : super(key: key);

  @override
  State<MessMenuManagementScreen> createState() => _MessMenuManagementScreenState();
}

class _MessMenuManagementScreenState extends State<MessMenuManagementScreen> {
  final TextEditingController _itemController = TextEditingController();

  bool _isFetching = true;
  bool _isLoading = false;
  _MenuMode _mode = _MenuMode.daily;
  DateTime _selectedDate = DateTime.now();
  int _selectedWeekdayIndex = DateTime.now().weekday - 1;
  MessMenuModel? _weeklyMenu;
  MessMenuModel? _dailyMenu;
  List<String> _activeMealTypes = const ['breakfast', 'lunch', 'dinner'];
  String? _successMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  // Simplify: operate in weekly-only mode to avoid confusion. Daily mode removed from UI.
  bool get _isDailyMode => false;
  MessMenuModel? get _activeMenu => _weeklyMenu;

  static const List<String> _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  String get _modeTitle => 'Weekly menu';

  String get _modeDescription => 'Edit the weekly template used as the default mess menu for the current week.';

  Future<void> _loadMenus() async {
    if (mounted) {
      setState(() => _isFetching = true);
    }

    try {
      final results = await Future.wait([
        MessMenuService.getCurrentWeekMenu(),
        FirebaseFirestore.instance.collection('hostelSettings').doc('settings').get(),
      ]);
      final weekly = results[0] as MessMenuModel?;
      final settingsDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
      final settings = settingsDoc.data() ?? <String, dynamic>{};
      final activeMeals = List<String>.from(settings['messActiveMealTypes'] ?? const []);
      if (!mounted) return;
      setState(() {
        _weeklyMenu = weekly;
        _activeMealTypes = activeMeals.isEmpty ? const ['breakfast', 'lunch', 'dinner'] : activeMeals;
        _isFetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load menu: $e';
        _isFetching = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadMenus();
  }

  void _showSuccessMessage(String message) {
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _successMessage = null);
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
        setState(() => _errorMessage = null);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _mode = _MenuMode.daily;
      });
      await _loadMenus();
    }
  }

  bool _isMealTypeActive(String mealType) {
    return _activeMealTypes.contains(mealType.toLowerCase());
  }

  Future<void> _addMealItem(String mealType) async {
    if (_itemController.text.trim().isEmpty) {
      _showErrorMessage('Please enter an item');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final adminId = context.read<AuthProvider>().user?.uid ?? '';
      final newItem = _itemController.text.trim();
      if (_isDailyMode) {
        await MessMenuService.addMealItem(
          mealType,
          newItem,
          adminId,
          daily: true,
          date: _selectedDate,
        );
        // update local daily menu immediately
        if (_dailyMenu != null) {
          final items = _dailyMenu!.getMealItems(mealType);
          if (!items.contains(newItem)) {
            items.add(newItem);
            setState(() {});
          }
        }
      } else {
        final weekday = _weekdayNames[_selectedWeekdayIndex];
        await MessMenuService.addWeekdayMealItem(
          weekday,
          mealType,
          newItem,
          adminId,
        );
        // update local weekly menu immediately to avoid stale reads
        final dayKey = weekday.toLowerCase();
        _weeklyMenu ??= MessMenuModel(weekStart: DateFormat('yyyy-MM-dd').format(DateTime.now()));
        final plan = Map<String, Map<String, List<String>>>.from(_weeklyMenu!.weekPlan);
        final dayMap = Map<String, List<String>>.from(plan[dayKey] ?? {});
        final list = List<String>.from(dayMap[mealType.toLowerCase()] ?? []);
        if (!list.contains(newItem)) {
          list.add(newItem);
          dayMap[mealType.toLowerCase()] = list;
          plan[dayKey] = dayMap;
          _weeklyMenu = MessMenuModel(
            id: _weeklyMenu!.id,
            weekStart: _weeklyMenu!.weekStart,
            menuDate: _weeklyMenu!.menuDate,
            breakfastItems: _weeklyMenu!.breakfastItems,
            lunchItems: _weeklyMenu!.lunchItems,
            dinnerItems: _weeklyMenu!.dinnerItems,
            enabledMeals: _weeklyMenu!.enabledMeals,
            lastUpdated: _weeklyMenu!.lastUpdated,
            updatedBy: _weeklyMenu!.updatedBy,
            weekPlan: plan,
          );
          setState(() {});
        }
      }
      _itemController.clear();
      _showSuccessMessage('Item added successfully');
      // Ensure dashboard shows today's menu updates
      try {
        await context.read<MessProvider>().loadTodayMenu();
      } catch (_) {}
    } catch (e) {
      _showErrorMessage('Failed to add item: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeMealItem(String mealType, String item) async {
    setState(() => _isLoading = true);

    try {
      final adminId = context.read<AuthProvider>().user?.uid ?? '';
      if (_isDailyMode) {
        await MessMenuService.removeMealItem(
          mealType,
          item,
          adminId,
          daily: true,
          date: _selectedDate,
        );
        if (_dailyMenu != null) {
          final items = _dailyMenu!.getMealItems(mealType);
          items.remove(item);
          setState(() {});
        }
      } else {
        final weekday = _weekdayNames[_selectedWeekdayIndex];
        await MessMenuService.removeWeekdayMealItem(
          weekday,
          mealType,
          item,
          adminId,
        );
        // update local weekly menu immediately
        final dayKey = weekday.toLowerCase();
        if (_weeklyMenu != null) {
          final plan = Map<String, Map<String, List<String>>>.from(_weeklyMenu!.weekPlan);
          final dayMap = Map<String, List<String>>.from(plan[dayKey] ?? {});
          final list = List<String>.from(dayMap[mealType.toLowerCase()] ?? []);
          list.remove(item);
          dayMap[mealType.toLowerCase()] = list;
          plan[dayKey] = dayMap;
          _weeklyMenu = MessMenuModel(
            id: _weeklyMenu!.id,
            weekStart: _weeklyMenu!.weekStart,
            menuDate: _weeklyMenu!.menuDate,
            breakfastItems: _weeklyMenu!.breakfastItems,
            lunchItems: _weeklyMenu!.lunchItems,
            dinnerItems: _weeklyMenu!.dinnerItems,
            enabledMeals: _weeklyMenu!.enabledMeals,
            lastUpdated: _weeklyMenu!.lastUpdated,
            updatedBy: _weeklyMenu!.updatedBy,
            weekPlan: plan,
          );
          setState(() {});
        }
      }
      _showSuccessMessage('Item removed successfully');
      // Ensure dashboard shows today's menu updates
      try {
        await context.read<MessProvider>().loadTodayMenu();
      } catch (_) {}
    } catch (e) {
      _showErrorMessage('Failed to remove item: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRemoveConfirmation(String mealType, String item) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Remove item',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remove "$item" from ${_formatMealType(mealType)}?',
                    style: TextStyle(color: AppColors.grey800, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will delete the item from the selected weekday menu.',
                    style: TextStyle(color: AppColors.grey600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _removeMealItem(mealType, item);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog(String mealType) {
    _itemController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to ${_formatMealType(mealType)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: TextField(
                controller: _itemController,
                decoration: InputDecoration(
                  hintText: 'Enter item name',
                  filled: true,
                  fillColor: AppColors.grey500.withOpacity(0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.restaurant_menu, color: AppColors.primary),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  Navigator.pop(dialogContext);
                  _addMealItem(mealType);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _addMealItem(mealType);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMealType(String type) {
    return type[0].toUpperCase() + type.substring(1);
  }

  Widget _buildStatusBanner(
    String message, {
    required IconData icon,
    required Color background,
    required Color border,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, {Color? color, IconData? icon}) {
    final chipColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: chipColor),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeToggle({required bool canEdit}) {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Daily'),
            selected: _mode == _MenuMode.daily,
            onSelected: (selected) {
              if (!selected) return;
              setState(() => _mode = _MenuMode.daily);
              _loadMenus();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            label: const Text('Weekly'),
            selected: _mode == _MenuMode.weekly,
            onSelected: (selected) {
              if (!selected) return;
              setState(() => _mode = _MenuMode.weekly);
              _loadMenus();
            },
          ),
        ),
        if (_isDailyMode && canEdit) ...[
          const SizedBox(width: 10),
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Pick date',
          ),
        ],
      ],
    );
  }

  Widget _buildWeekdaySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_weekdayNames.length, (i) {
          final name = _weekdayNames[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(name.substring(0, 3)),
              selected: _selectedWeekdayIndex == i,
              onSelected: (s) {
                if (!s) return;
                setState(() => _selectedWeekdayIndex = i);
                // no need to reload menus, weekly menu already has weekPlan
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMealSection({
    required String mealType,
    required IconData icon,
    required List<String> items,
    required bool canEdit,
  }) {
    final cardColor = AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cardColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatMealType(mealType),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Managed from Hostel Settings',
                        style: TextStyle(color: AppColors.grey700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _buildChip('Active', color: Colors.green),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'No items added yet',
                      style: TextStyle(color: AppColors.grey700, fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: items.map((item) {
                      return Container(
                        constraints: const BoxConstraints(minWidth: 92),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.10),
                              Colors.white,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary.withOpacity(0.14)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.restaurant, size: 14, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.grey900,
                                ),
                              ),
                            ),
                            if (canEdit) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _isLoading ? null : () => _showRemoveConfirmation(mealType, item),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                if (canEdit) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _showAddItemDialog(mealType),
                      icon: const Icon(Icons.add),
                      label: const Text('Add item'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  Widget _buildMiniInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey500,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.grey700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final role = user?.roleString ?? '';
    final canEdit = role == 'Admin' || role == 'Mess Staff';
    final menu = _activeMenu;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mess Menu Management',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isFetching
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_successMessage != null)
                      _buildStatusBanner(
                        _successMessage!,
                        icon: Icons.check_circle,
                        background: Colors.green.shade50,
                        border: Colors.green,
                        color: Colors.green,
                      ),
                    if (_errorMessage != null)
                      _buildStatusBanner(
                        _errorMessage!,
                        icon: Icons.error,
                        background: Colors.red.shade50,
                        border: Colors.red,
                        color: Colors.red,
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mess menu control',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _modeTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _modeDescription,
                            style: const TextStyle(color: Colors.white, height: 1.35),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildChip(canEdit ? 'Editable' : 'View only', color: Colors.white),
                              _buildChip('Current week', color: Colors.white, icon: Icons.calendar_today),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isDailyMode
                                      ? 'Daily menu overrides the weekly template for this date.'
                                      : 'Weekly menu acts as the default menu for the whole week.',
                                  style: TextStyle(color: AppColors.grey800, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniInfoCard(
                                  'Breakfast',
                                  (_weeklyMenu?.getWeekdayMealItems(_weekdayNames[_selectedWeekdayIndex], 'breakfast').length ?? 0).toString(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildMiniInfoCard(
                                  'Lunch',
                                  (_weeklyMenu?.getWeekdayMealItems(_weekdayNames[_selectedWeekdayIndex], 'lunch').length ?? 0).toString(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildMiniInfoCard(
                                  'Dinner',
                                  (_weeklyMenu?.getWeekdayMealItems(_weekdayNames[_selectedWeekdayIndex], 'dinner').length ?? 0).toString(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (menu == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'No menu found.',
                          style: TextStyle(color: AppColors.grey700),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 8),
                      _buildWeekdaySelector(),
                      const SizedBox(height: 12),
                      if (_isMealTypeActive('breakfast'))
                        _buildMealSection(
                          mealType: 'breakfast',
                          icon: Icons.free_breakfast,
                          items: _weeklyMenu?.getWeekdayMealItems(_weekdayNames[_selectedWeekdayIndex], 'breakfast') ?? [],
                          canEdit: canEdit,
                        ),
                      if (_isMealTypeActive('lunch'))
                        _buildMealSection(
                          mealType: 'lunch',
                          icon: Icons.lunch_dining,
                          items: _weeklyMenu?.getWeekdayMealItems(_weekdayNames[_selectedWeekdayIndex], 'lunch') ?? [],
                          canEdit: canEdit,
                        ),
                      if (_isMealTypeActive('dinner'))
                        _buildMealSection(
                          mealType: 'dinner',
                          icon: Icons.dinner_dining,
                          items: _weeklyMenu?.getWeekdayMealItems(_weekdayNames[_selectedWeekdayIndex], 'dinner') ?? [],
                          canEdit: canEdit,
                        ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
