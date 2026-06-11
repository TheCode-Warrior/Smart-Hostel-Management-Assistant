import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/mess_menu_model.dart';

class MessMenuService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static DocumentReference<Map<String, dynamic>> _dailyMenuDoc(DateTime date) {
    return _firestore.collection('messMenuDaily').doc(_dateKey(date));
  }

  // Get or create current week's menu
  static Future<MessMenuModel?> getCurrentWeekMenu() async {
    try {
      final now = DateTime.now();
      final weekStart = _getWeekStart(now);
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);

      final doc = await _firestore
          .collection('hostelSettings')
          .doc('messMenu')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return MessMenuModel.fromMap(data, doc.id);
      }

      // Create empty menu for week if not exists
      return MessMenuModel(weekStart: weekStartStr);
    } catch (e) {
      print('Error getting menu: $e');
      return null;
    }
  }

  static Future<MessMenuModel?> getDailyMenu(DateTime date) async {
    try {
      MessMenuModel? dailyMenu;

      try {
        final doc = await _dailyMenuDoc(date).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            dailyMenu = MessMenuModel.fromMap(data, doc.id);
          }
        }
      } catch (e) {
        print('Error getting daily menu override: $e');
      }

      if (dailyMenu != null) {
        return dailyMenu;
      }

      final weeklyMenu = await getCurrentWeekMenu();
      if (weeklyMenu == null) {
        return MessMenuModel(
          weekStart: _dateKey(date),
          menuDate: _dateKey(date),
        );
      }

      // If weekly template contains a weekPlan, use the items for the requested weekday.
      // Use a fixed English weekday mapping (Monday..Sunday) to avoid locale mismatches.
      const weekdayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final weekdayKey = weekdayNames[date.weekday - 1];
      List<String> breakfast = [];
      List<String> lunch = [];
      List<String> dinner = [];

      if (weeklyMenu.weekPlan.isNotEmpty && weeklyMenu.weekPlan.containsKey(weekdayKey)) {
        final dayMap = weeklyMenu.weekPlan[weekdayKey]!;
        breakfast = List<String>.from(dayMap['breakfast'] ?? []);
        lunch = List<String>.from(dayMap['lunch'] ?? []);
        dinner = List<String>.from(dayMap['dinner'] ?? []);
      }

      return MessMenuModel(
        weekStart: weeklyMenu.weekStart,
        menuDate: _dateKey(date),
        breakfastItems: breakfast,
        lunchItems: lunch,
        dinnerItems: dinner,
        enabledMeals: List<String>.from(weeklyMenu.enabledMeals),
        weekPlan: Map.from(weeklyMenu.weekPlan),
      );
    } catch (e) {
      print('Error getting daily menu: $e');
      return null;
    }
  }

  static Future<MessMenuModel?> getTodayMenu() async {
    return getDailyMenu(DateTime.now());
  }

  // Save menu
  static Future<void> saveMenu(MessMenuModel menu, String adminId) async {
    try {
      await _firestore
          .collection('hostelSettings')
          .doc('messMenu')
          .set({
        'weekStart': menu.weekStart,
        'menuDate': menu.menuDate,
        'breakfast': menu.breakfastItems,
        'lunch': menu.lunchItems,
        'dinner': menu.dinnerItems,
        'weekPlan': menu.weekPlan,
        'enabledMeals': menu.enabledMeals,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': adminId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving menu: $e');
      rethrow;
    }
  }

  // Add an item to a weekday's meal list in the weekly template
  static Future<void> addWeekdayMealItem(
    String weekday,
    String mealType,
    String item,
    String adminId,
  ) async {
    try {
      final docRef = _firestore.collection('hostelSettings').doc('messMenu');
      final doc = await docRef.get();
      Map<String, dynamic> data = doc.exists ? (doc.data() as Map<String, dynamic>) : {};

      final weekPlan = (data['weekPlan'] as Map<String, dynamic>?) ?? {};
      final dayKey = weekday.toLowerCase();
      final dayMap = (weekPlan[dayKey] as Map<String, dynamic>?) ?? {};
      final items = List<String>.from(dayMap[mealType] ?? []);
      if (!items.contains(item)) items.add(item);
      dayMap[mealType] = items;
      weekPlan[dayKey] = dayMap;

      await docRef.set({
        'weekPlan': weekPlan,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': adminId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error adding weekday meal item: $e');
      rethrow;
    }
  }

  static Future<void> removeWeekdayMealItem(
    String weekday,
    String mealType,
    String item,
    String adminId,
  ) async {
    try {
      final docRef = _firestore.collection('hostelSettings').doc('messMenu');
      final doc = await docRef.get();
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final weekPlan = (data['weekPlan'] as Map<String, dynamic>?) ?? {};
      final dayKey = weekday.toLowerCase();
      final dayMap = (weekPlan[dayKey] as Map<String, dynamic>?) ?? {};
      final items = List<String>.from(dayMap[mealType] ?? []);
      items.remove(item);
      dayMap[mealType] = items;
      weekPlan[dayKey] = dayMap;

      await docRef.set({
        'weekPlan': weekPlan,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': adminId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error removing weekday meal item: $e');
      rethrow;
    }
  }

  static Future<void> setWeekdayMealItems(
    String weekday,
    String mealType,
    List<String> items,
    String adminId,
  ) async {
    try {
      final docRef = _firestore.collection('hostelSettings').doc('messMenu');
      final doc = await docRef.get();
      Map<String, dynamic> data = doc.exists ? (doc.data() as Map<String, dynamic>) : {};

      final weekPlan = (data['weekPlan'] as Map<String, dynamic>?) ?? {};
      final dayKey = weekday.toLowerCase();
      final dayMap = (weekPlan[dayKey] as Map<String, dynamic>?) ?? {};
      dayMap[mealType] = items;
      weekPlan[dayKey] = dayMap;

      await docRef.set({
        'weekPlan': weekPlan,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': adminId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error setting weekday meal items: $e');
      rethrow;
    }
  }

  static Future<void> saveDailyMenu(MessMenuModel menu, String adminId) async {
    try {
      final menuDate = menu.menuDate ?? menu.weekStart;
      await _dailyMenuDoc(DateTime.parse(menuDate)).set({
        'weekStart': menu.weekStart,
        'menuDate': menuDate,
        'breakfast': menu.breakfastItems,
        'lunch': menu.lunchItems,
        'dinner': menu.dinnerItems,
        'enabledMeals': menu.enabledMeals,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': adminId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving daily menu: $e');
      rethrow;
    }
  }

  static Future<MessMenuModel?> _getEditableMenu({required bool daily, DateTime? date}) async {
    if (daily) {
      return getDailyMenu(date ?? DateTime.now());
    }
    return getCurrentWeekMenu();
  }

  static MessMenuModel _copyMenu(MessMenuModel menu) {
    return MessMenuModel(
      id: menu.id,
      weekStart: menu.weekStart,
      menuDate: menu.menuDate,
      breakfastItems: List<String>.from(menu.breakfastItems),
      lunchItems: List<String>.from(menu.lunchItems),
      dinnerItems: List<String>.from(menu.dinnerItems),
      weekPlan: Map<String, Map<String, List<String>>>.from(menu.weekPlan),
      enabledMeals: List<String>.from(menu.enabledMeals),
      lastUpdated: menu.lastUpdated,
      updatedBy: menu.updatedBy,
    );
  }

  // Add item to meal
  static Future<void> addMealItem(
    String mealType,
    String item,
    String adminId,
    {bool daily = false, DateTime? date}
  ) async {
    try {
      final menu = await _getEditableMenu(daily: daily, date: date);
      if (menu == null) return;

      final updatedMenu = _copyMenu(menu);
      if (daily) {
        List<String> items = updatedMenu.getMealItems(mealType);
        if (!items.contains(item)) {
          items.add(item);
        }
        updatedMenu.menuDate = _dateKey(date ?? DateTime.now());
        await saveDailyMenu(updatedMenu, adminId);
      } else {
        final weekdayKey = _weekdayKey(date ?? DateTime.now());
        final plan = Map<String, Map<String, List<String>>>.from(updatedMenu.weekPlan);
        final dayMap = Map<String, List<String>>.from(plan[weekdayKey] ?? {});
        final items = List<String>.from(dayMap[mealType.toLowerCase()] ?? []);
        if (!items.contains(item)) {
          items.add(item);
        }
        dayMap[mealType.toLowerCase()] = items;
        plan[weekdayKey] = dayMap;
        updatedMenu.weekPlan = plan;
        await saveMenu(updatedMenu, adminId);
      }
    } catch (e) {
      print('Error adding meal item: $e');
      rethrow;
    }
  }

  // Remove item from meal
  static Future<void> removeMealItem(
    String mealType,
    String item,
    String adminId,
    {bool daily = false, DateTime? date}
  ) async {
    try {
      final menu = await _getEditableMenu(daily: daily, date: date);
      if (menu == null) return;

      final updatedMenu = _copyMenu(menu);
      if (daily) {
        List<String> items = updatedMenu.getMealItems(mealType);
        items.remove(item);
        updatedMenu.menuDate = _dateKey(date ?? DateTime.now());
        await saveDailyMenu(updatedMenu, adminId);
      } else {
        final weekdayKey = _weekdayKey(date ?? DateTime.now());
        final plan = Map<String, Map<String, List<String>>>.from(updatedMenu.weekPlan);
        final dayMap = Map<String, List<String>>.from(plan[weekdayKey] ?? {});
        final items = List<String>.from(dayMap[mealType.toLowerCase()] ?? []);
        items.remove(item);
        dayMap[mealType.toLowerCase()] = items;
        plan[weekdayKey] = dayMap;
        updatedMenu.weekPlan = plan;
        await saveMenu(updatedMenu, adminId);
      }
    } catch (e) {
      print('Error removing meal item: $e');
      rethrow;
    }
  }

  // Toggle meal type enabled/disabled
  static Future<void> toggleMealType(
    String mealType,
    String adminId,
    {bool daily = false, DateTime? date}
  ) async {
    try {
      final menu = await _getEditableMenu(daily: daily, date: date);
      if (menu == null) return;

      final updatedMenu = _copyMenu(menu);
      List<String> enabled = List.from(updatedMenu.enabledMeals);
      if (enabled.contains(mealType)) {
        enabled.remove(mealType);
      } else {
        enabled.add(mealType);
      }

      updatedMenu.enabledMeals = enabled;
      if (daily) {
        updatedMenu.menuDate = _dateKey(date ?? DateTime.now());
        await saveDailyMenu(updatedMenu, adminId);
      } else {
        await saveMenu(updatedMenu, adminId);
      }
    } catch (e) {
      print('Error toggling meal type: $e');
      rethrow;
    }
  }

  static String _weekdayKey(DateTime date) {
    const weekdayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return weekdayNames[date.weekday - 1];
  }

  // Save student meal subscription
  static Future<void> saveMealSubscription(
    String studentId,
    String month,
    List<String> meals,
    double cost,
  ) async {
    try {
      await _firestore
          .collection('mealSubscriptions')
          .doc('${studentId}_$month')
          .set({
        'studentId': studentId,
        'month': month,
        'subscribedMeals': meals,
        'isPaid': false,
        'subscribedAt': FieldValue.serverTimestamp(),
        'totalCost': cost,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving subscription: $e');
      rethrow;
    }
  }

  // Get student's subscription for month
  static Future<MealSubscriptionModel?> getStudentSubscription(
    String studentId,
    String month,
  ) async {
    try {
      final doc = await _firestore
          .collection('mealSubscriptions')
          .doc('${studentId}_$month')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return MealSubscriptionModel.fromMap(data, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting subscription: $e');
      return null;
    }
  }

  // Record meal consumption
  static Future<void> recordMealConsumption(
    String studentId,
    String date,
    String mealType,
    String time,
  ) async {
    try {
      final docId = '${studentId}_$date';

      await _firestore
          .collection('mealConsumption')
          .doc(docId)
          .set({
        'studentId': studentId,
        'date': date,
        'recordedAt': FieldValue.serverTimestamp(),
        'meals': FieldValue.arrayUnion([
          {
            'type': mealType,
            'tokenUsed': true,
            'timestamp': time,
          }
        ]),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error recording consumption: $e');
      rethrow;
    }
  }

  // Get daily consumption report
  static Future<Map<String, int>> getDailyConsumptionReport(String date) async {
    try {
      final docs = await _firestore
          .collection('mealConsumption')
          .where('date', isEqualTo: date)
          .get();

      Map<String, int> report = {
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
      };

      for (var doc in docs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final meals = data['meals'] as List?;

        if (meals != null) {
          for (var meal in meals) {
            final type = meal['type'] as String?;
            final used = meal['tokenUsed'] as bool?;

            if (type != null && used == true) {
              report[type] = (report[type] ?? 0) + 1;
            }
          }
        }
      }

      return report;
    } catch (e) {
      print('Error getting consumption report: $e');
      return {};
    }
  }

  // Get weekly consumption summary
  static Future<Map<String, Map<String, int>>> getWeeklyConsumptionReport(
    DateTime weekStart,
  ) async {
    try {
      Map<String, Map<String, int>> weekReport = {};

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        weekReport[dateStr] = await getDailyConsumptionReport(dateStr);
      }

      return weekReport;
    } catch (e) {
      print('Error getting weekly report: $e');
      return {};
    }
  }

  // Helper: Get week start (Monday)
  static DateTime _getWeekStart(DateTime date) {
    final dayOfWeek = date.weekday; // Monday=1, Sunday=7
    return date.subtract(Duration(days: dayOfWeek - 1));
  }
}
