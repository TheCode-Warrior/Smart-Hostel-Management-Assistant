import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/mess_token_model.dart';
import '../models/student_model.dart';
import '../services/mess_service.dart';
import '../services/mess_menu_service.dart';

class MessProvider extends ChangeNotifier {
  List<MessTokenModel> _tokens = [];
  MessTokenModel? _currentToken;
  Map<String, bool> _todayMealStatus = {};
  Map<String, dynamic>? _todayMenu;
  bool _isLoading = false;
  String? _errorMessage;
  int _todayMealCount = 0;

  List<MessTokenModel> get tokens => _tokens;
  MessTokenModel? get currentToken => _currentToken;
  Map<String, bool> get todayMealStatus => _todayMealStatus;
  Map<String, dynamic>? get todayMenu => _todayMenu;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get todayMealCount => _todayMealCount;

  // Load current token for student
  Future<void> loadCurrentToken(String studentId) async {
    _setLoading(true);
    try {
      _currentToken = await MessService.getCurrentTokenForStudent(studentId);
      await loadTodayMealStatus(studentId);
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load meal history for student
  Future<void> loadMealHistory(String studentId, {int days = 7}) async {
    _setLoading(true);
    try {
      _tokens = await MessService.getStudentMealHistory(studentId, days: days);
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load today's meal status
  Future<void> loadTodayMealStatus(String studentId) async {
    try {
      _todayMealStatus = await MessService.getTodayMealStatus(studentId);
      _todayMealCount = _todayMealStatus.values.where((taken) => taken).length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Load today's menu
  Future<void> loadTodayMenu() async {
    _setLoading(true);
    try {
      print('Loading today\'s menu...');
      final menu = await MessMenuService.getTodayMenu();
      if (menu != null) {
        _errorMessage = null;
        _todayMenu = {
          'date': menu.menuDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'source': menu.menuDate != null ? 'daily' : 'weekly',
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
      } else {
        _todayMenu = null;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _todayMenu = null;
    } finally {
      _setLoading(false);
    }
  }

  // Validate and use token (for staff)
  Future<Map<String, dynamic>> validateToken({
    required String scannedData,
    required String staffId,
    required String location,
  }) async {
    _setLoading(true);
    try {
      final result = await MessService.validateAndMarkToken(
        scannedData: scannedData,
        staffId: staffId,
        location: location,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Generate tokens for current meal time (auto-detect)
  Future<void> generateTokensForCurrentMealTime() async {
    _setLoading(true);
    try {
      await MessService.generateTokensForCurrentMealTime();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      rethrow;
    }
  }


  // Get mess statistics (for admin)
  Future<Map<String, dynamic>> getMessStats(DateTime date) async {
    try {
      // Implementation for mess statistics
      // This would aggregate data from mealRecords
      return {};
    } catch (e) {
      _errorMessage = e.toString();
      return {};
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    // Defer notification to after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}