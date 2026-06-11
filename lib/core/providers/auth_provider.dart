import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  // Login with email and password
Future<bool> login({
  required String email,
  required String password,
}) async {
  _setLoading(true);
  _clearError();

  try {
    final user = await AuthService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (user != null) {
      _user = user;
      await _saveUserSession(user.uid!);
      _setLoading(false);
      return true;
    } else {
      _errorMessage = 'Invalid email or password';  // ✅ Set error message
      _setLoading(false);
      return false;
    }
  } catch (e) {
    _errorMessage = e.toString();  // ✅ Set error message from exception
    _setLoading(false);
    return false;
  }
}
  // Register new user
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String role,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await AuthService.registerWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        role: role,
      );

      if (user != null) {
        _user = user;
        await _saveUserSession(user.uid!);
        _setLoading(false);
        return true;
      } else {
        _errorMessage = 'Registration failed';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }
// Add this method to AuthProvider class

// Update profile image URL
Future<bool> updateProfileImage(String imageUrl) async {
  if (_user == null) return false;

  _setLoading(true);
  try {
    await FirestoreService.updateDocument(
      collection: 'users',
      documentId: _user!.uid!,
      updates: {'profileImage': imageUrl},
    );

    _user = UserModel.fromMap(
      {..._user!.toMap(), 'profileImage': imageUrl},
      _user!.uid!,
    );

    _setLoading(false);
    return true;
  } catch (e) {
    _errorMessage = e.toString();
    _setLoading(false);
    return false;
  }
}
// Logout
  Future<void> logout() async {
    _setLoading(true);
    try {
      await AuthService.signOut();
      _user = null;
      await _clearUserSession();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Check if user is logged in
  Future<bool> checkUserSession() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId != null) {
        final userData = await FirestoreService.readDocument(
          collection: 'users',
          documentId: userId,
        );
        
        if (userData != null) {
          _user = UserModel.fromMap(userData, userId);
          _setLoading(false);
          return true;
        }
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_user == null) return false;

    _setLoading(true);
    try {
      await FirestoreService.updateDocument(
        collection: 'users',
        documentId: _user!.uid!,
        updates: updates,
      );

      _user = UserModel.fromMap(
        {..._user!.toMap(), ...updates},
        _user!.uid!,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // ✅ NEW: Change password with current password verification
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final success = await AuthService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _setLoading(false);
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Reset password (forgot password)
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await AuthService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // Save user session
  Future<void> _saveUserSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setBool('is_logged_in', true);
  }

  // Clear user session
  Future<void> _clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.setBool('is_logged_in', false);
  }

  // Clear error
  void _clearError() {
    _errorMessage = null;
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    _safeNotify();
  }

  // Safe notify
  void _safeNotify() {
    if (_isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}