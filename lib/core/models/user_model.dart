import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, warden, admin, caretaker, messStaff }

class UserModel {
  String? uid;
  String? email;
  String? fullName;
  String? phoneNumber;
  UserRole? role;
  String? profileImage;
  bool? isActive;
  Timestamp? createdAt;
  Timestamp? lastLogin;
  String? fcmToken;

  UserModel({
    this.uid,
    this.email,
    this.fullName,
    this.phoneNumber,
    this.role,
    this.profileImage,
    this.isActive,
    this.createdAt,
    this.lastLogin,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': role?.toString().split('.').last,
      'profileImage': profileImage,
      'isActive': isActive ?? true,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastLogin': lastLogin ?? FieldValue.serverTimestamp(),
      'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'],
      fullName: map['fullName'],
      phoneNumber: map['phoneNumber'],
      role: _stringToRole(map['role']),
      profileImage: map['profileImage'],
      isActive: map['isActive'],
      createdAt: map['createdAt'],
      lastLogin: map['lastLogin'],
      fcmToken: map['fcmToken'],
    );
  }

  static UserRole _stringToRole(String? role) {
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

  String get roleString {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.warden:
        return 'Warden';
      case UserRole.admin:
        return 'Admin';
      case UserRole.caretaker:
        return 'Caretaker';
      case UserRole.messStaff:
        return 'Mess Staff';
      default:
        return 'Unknown';
    }
  }
}