import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../../firebase_options.dart';
import 'notification_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth state changes stream
  static Stream<User?> get user => _auth.authStateChanges();

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  static Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          return UserModel.fromMap(userDoc.data() as Map<String, dynamic>, user.uid);
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Sign in error: ${e.message}');
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  static Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String role,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      User? user = result.user;
      if (user != null) {
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          fullName: fullName,
          phoneNumber: phoneNumber,
          role: _stringToRole(role),
          isActive: true,
          createdAt: Timestamp.now(),
          lastLogin: Timestamp.now(),
        );
        
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        
        if (role == 'student') {
          await _firestore.collection('students').doc(user.uid).set({
            'userId': user.uid,
            'fullName': fullName,
            'email': email,
            'phoneNumber': phoneNumber,
            'enrollmentNo': '',
            'course': '',
            'semester': 1,
            'batch': '',
            'isVerified': false,
            'messFeePaid': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        return newUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Registration error: ${e.message}');
      throw _handleAuthException(e);
    }
  }

  // Create user by admin
  static Future<UserModel?> createUserByAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String role,
  }) async {
    FirebaseAuth? secondaryAuth;
    try {
      const secondaryAppName = 'secondaryAuthApp';

      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app(secondaryAppName);
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: secondaryAppName,
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final secondaryFirestore = FirebaseFirestore.instanceFor(app: secondaryApp);

      final result = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final createdUser = result.user;
      if (createdUser == null) {
        return null;
      }

      final newUser = UserModel(
        uid: createdUser.uid,
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        role: _stringToRole(role),
        isActive: true,
        createdAt: Timestamp.now(),
        lastLogin: null,
      );

      await _firestore.collection('users').doc(createdUser.uid).set(newUser.toMap());

      if (role == 'student') {
        await secondaryFirestore.collection('students').doc(createdUser.uid).set({
          'userId': createdUser.uid,
          'fullName': fullName,
          'email': email,
          'phoneNumber': phoneNumber,
          'enrollmentNo': '',
          'course': '',
          'semester': 1,
          'batch': '',
          'isVerified': true, // Auto-verified for admin creation
          'messFeePaid': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return newUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('Admin create user error: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Admin create user error: $e');
      rethrow;
    } finally {
      try {
        await secondaryAuth?.signOut();
      } catch (_) {}
    }
  }

  // Sign in with Google
  static Future<UserModel?> signInWithGoogle() async {
    try {
      debugPrint('Google Sign In not fully configured. Email/password auth available.');
      return null;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      return null;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ✅ NEW: Change password with re-authentication
  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not logged in');
      }
      
      // Re-authenticate user (required for sensitive operations)
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
      
      // Send notification
      await NotificationService.sendNotification(
        title: '🔒 Password Changed',
        body: 'Your password was successfully changed.',
        userId: user.uid,
        type: 'security',
        data: {'changeTime': DateTime.now().toIso8601String()},
      );
      
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Change password error: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('Change password error: $e');
      rethrow;
    }
  }

  // Update email
  static Future<void> updateEmail(String newEmail) async {
    try {
      User? user = _auth.currentUser;
      await user?.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Delete account
  static Future<void> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).delete();
        await _firestore.collection('students').doc(user.uid).delete();
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Handle auth exceptions
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'Email already in use.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'requires-recent-login':
        return 'Please log in again to change password.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  static UserRole _stringToRole(String role) {
    switch (role) {
      case 'student':
        return UserRole.student;
      case 'warden':
        return UserRole.warden;
      case 'admin':
        return UserRole.admin;
      case 'caretaker':
        return UserRole.caretaker;
      case 'messStaff':
        return UserRole.messStaff;
      default:
        return UserRole.student;
    }
  }
}