import 'package:cloud_firestore/cloud_firestore.dart';

class MessMenuModel {
  String? id;
  String weekStart; // Format: "2026-05-10"
  String? menuDate; // Format: "2026-05-10" for daily overrides
  List<String> breakfastItems;
  List<String> lunchItems;
  List<String> dinnerItems;
  // weekPlan: { 'monday': { 'breakfast': [...], 'lunch': [...], 'dinner': [...] }, ... }
  Map<String, Map<String, List<String>>> weekPlan;
  List<String> enabledMeals; // ["breakfast", "lunch", "dinner"]
  Timestamp? lastUpdated;
  String? updatedBy;

  MessMenuModel({
    this.id,
    required this.weekStart,
    this.menuDate,
    this.breakfastItems = const [],
    this.lunchItems = const [],
    this.dinnerItems = const [],
    this.weekPlan = const {},
    this.enabledMeals = const ['breakfast', 'lunch', 'dinner'],
    this.lastUpdated,
    this.updatedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'weekStart': weekStart,
      'menuDate': menuDate,
      'breakfast': breakfastItems,
      'lunch': lunchItems,
      'dinner': dinnerItems,
      'weekPlan': weekPlan,
      'enabledMeals': enabledMeals,
      'lastUpdated': lastUpdated ?? FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  factory MessMenuModel.fromMap(Map<String, dynamic> map, String id) {
    return MessMenuModel(
      id: id,
      weekStart: map['weekStart'] ?? '',
      menuDate: map['menuDate'],
      breakfastItems: List<String>.from(map['breakfast'] ?? []),
      lunchItems: List<String>.from(map['lunch'] ?? []),
      dinnerItems: List<String>.from(map['dinner'] ?? []),
      weekPlan: (map['weekPlan'] as Map<String, dynamic>?)?.map((k, v) {
            final meals = v as Map<String, dynamic>;
            return MapEntry(k, meals.map((mk, mv) => MapEntry(mk, List<String>.from(mv ?? []))));
          }) ?? {},
      enabledMeals: List<String>.from(map['enabledMeals'] ?? ['breakfast', 'lunch', 'dinner']),
      lastUpdated: map['lastUpdated'],
      updatedBy: map['updatedBy'],
    );
  }

  List<String> getMealItems(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return breakfastItems;
      case 'lunch':
        return lunchItems;
      case 'dinner':
        return dinnerItems;
      default:
        return [];
    }
  }

  List<String> getWeekdayMealItems(String weekday, String mealType) {
    final dayKey = weekday.toLowerCase();
    final meals = weekPlan[dayKey];
    if (meals != null) {
      return List<String>.from(meals[mealType.toLowerCase()] ?? []);
    }
    return [];
  }

  bool isMealEnabled(String mealType) {
    return enabledMeals.contains(mealType.toLowerCase());
  }
}

class MealSubscriptionModel {
  String? id;
  String studentId;
  String month; // Format: "2026-05"
  List<String> subscribedMeals; // ["breakfast", "lunch"] - which meals student chose
  bool isPaid;
  Timestamp? subscribedAt;
  double totalCost;

  MealSubscriptionModel({
    this.id,
    required this.studentId,
    required this.month,
    required this.subscribedMeals,
    this.isPaid = false,
    this.subscribedAt,
    this.totalCost = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'month': month,
      'subscribedMeals': subscribedMeals,
      'isPaid': isPaid,
      'subscribedAt': subscribedAt ?? FieldValue.serverTimestamp(),
      'totalCost': totalCost,
    };
  }

  factory MealSubscriptionModel.fromMap(Map<String, dynamic> map, String id) {
    return MealSubscriptionModel(
      id: id,
      studentId: map['studentId'] ?? '',
      month: map['month'] ?? '',
      subscribedMeals: List<String>.from(map['subscribedMeals'] ?? []),
      isPaid: map['isPaid'] ?? false,
      subscribedAt: map['subscribedAt'],
      totalCost: (map['totalCost'] ?? 0.0).toDouble(),
    );
  }

  bool hasSubscribedToMeal(String mealType) {
    return subscribedMeals.contains(mealType.toLowerCase());
  }
}

class MealConsumptionModel {
  String? id;
  String studentId;
  String date; // Format: "2026-05-10"
  List<MealRecord> meals;
  Timestamp? recordedAt;

  MealConsumptionModel({
    this.id,
    required this.studentId,
    required this.date,
    this.meals = const [],
    this.recordedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'date': date,
      'meals': meals.map((m) => m.toMap()).toList(),
      'recordedAt': recordedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory MealConsumptionModel.fromMap(Map<String, dynamic> map, String id) {
    return MealConsumptionModel(
      id: id,
      studentId: map['studentId'] ?? '',
      date: map['date'] ?? '',
      meals: (map['meals'] as List?)
          ?.map((m) => MealRecord.fromMap(m as Map<String, dynamic>))
          .toList() ??
          [],
      recordedAt: map['recordedAt'],
    );
  }

  int getMealCount(String mealType) {
    return meals.where((m) => m.type == mealType && m.tokenUsed).length;
  }
}

class MealRecord {
  String type; // breakfast, lunch, dinner
  bool tokenUsed;
  String? timestamp; // Time of consumption (HH:mm)

  MealRecord({
    required this.type,
    required this.tokenUsed,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'tokenUsed': tokenUsed,
      'timestamp': timestamp,
    };
  }

  factory MealRecord.fromMap(Map<String, dynamic> map) {
    return MealRecord(
      type: map['type'] ?? '',
      tokenUsed: map['tokenUsed'] ?? false,
      timestamp: map['timestamp'],
    );
  }
}
