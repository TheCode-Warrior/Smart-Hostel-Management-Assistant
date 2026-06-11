// lib/core/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload profile image
  static Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      final String fileName = 'profile_$userId.jpg';
      final Reference ref = _storage.ref().child('profile_images/$fileName');
      
      // Upload file
      final TaskSnapshot uploadTask = await ref.putFile(imageFile);
      
      // Get download URL
      final String downloadUrl = await uploadTask.ref.getDownloadURL();
      
      debugPrint('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Delete profile image
  static Future<bool> deleteProfileImage(String userId) async {
    try {
      final String fileName = 'profile_$userId.jpg';
      final Reference ref = _storage.ref().child('profile_images/$fileName');
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }
}