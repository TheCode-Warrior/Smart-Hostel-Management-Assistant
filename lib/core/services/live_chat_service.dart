import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';

class LiveChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get or create support chat for current user
  static Future<String> getOrCreateSupportChat(String userId) async {
    try {
      final chatDocRef = _firestore.collection('support_chats').doc('support_$userId');
      
      final doc = await chatDocRef.get();
      if (!doc.exists) {
        await chatDocRef.set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'status': 'open', // open, closed, waiting
          'lastMessage': '',
        });
      }
      
      return 'support_$userId';
    } catch (e) {
      debugPrint('Error getting/creating support chat: $e');
      rethrow;
    }
  }

  // Send message to support chat
  static Future<void> sendMessage({
    required String chatId,
    required String userId,
    required String message,
    String sender = 'user', // 'user' or 'support'
  }) async {
    try {
      final messagesRef = _firestore
          .collection('support_chats')
          .doc(chatId)
          .collection('messages');

      await messagesRef.add({
        'userId': userId,
        'sender': sender,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'isRead': sender == 'support' ? false : true,
      });

      // Update last message in chat doc
      await _firestore.collection('support_chats').doc(chatId).update({
        'lastMessage': message,
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'open',
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  // Stream of messages for a chat
  static Stream<List<ChatMessage>> getMessagesStream(String chatId) {
    try {
      return _firestore
          .collection('support_chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
                .toList();
          });
    } catch (e) {
      debugPrint('Error getting messages stream: $e');
      return Stream.value([]);
    }
  }

  // Mark messages as read
  static Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      final batch = _firestore.batch();

      final unreadDocs = await _firestore
          .collection('support_chats')
          .doc(chatId)
          .collection('messages')
          .where('sender', isEqualTo: 'support')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // Close support chat
  static Future<void> closeChat(String chatId) async {
    try {
      await _firestore.collection('support_chats').doc(chatId).update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error closing chat: $e');
      rethrow;
    }
  }

  // Ensure anonymous auth if needed
  static Future<String> ensureAuth() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        return user.uid;
      }

      // Fallback to anonymous sign-in
      final anonUser = await _auth.signInAnonymously();
      return anonUser.user!.uid;
    } catch (e) {
      debugPrint('Error ensuring auth: $e');
      rethrow;
    }
  }

  // Get unread count for a chat
  static Future<int> getUnreadCount(String chatId) async {
    try {
      final snapshot = await _firestore
          .collection('support_chats')
          .doc(chatId)
          .collection('messages')
          .where('sender', isEqualTo: 'support')
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return snapshot.count!;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }
}
