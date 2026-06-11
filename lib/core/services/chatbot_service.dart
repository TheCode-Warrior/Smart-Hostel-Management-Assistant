import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import 'firestore_service.dart';
import 'attendance_service.dart';
import 'package:intl/intl.dart';

class ChatbotService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Process user message and return bot response
  static Future<ChatMessage> processMessage({
    required String userId,
    required String message,
    required String sessionId,
  }) async {
    try {
      // Save user message
      final userMessage = ChatMessage(
        id: _generateMessageId(),
        sender: 'user',
        message: message,
        timestamp: DateTime.now(),
        type: 'text',
      );

      await _saveMessage(userId, sessionId, userMessage);

      // Get bot response based on intent
      final response = await _getBotResponse(message, userId);
      final analysis = await _analyzeIntent(message);
      
      // Create bot response
      final botMessage = ChatMessage(
        id: _generateMessageId(),
        sender: 'bot',
        message: response,
        timestamp: DateTime.now(),
        type: 'text',
        intent: analysis['intent'],
        confidence: analysis['confidence'],
        quickReplies: _getQuickReplies(analysis['intent']),
      );

      await _saveMessage(userId, sessionId, botMessage);

      return botMessage;
    } catch (e) {
      debugPrint('Error processing message: $e');
      
      return ChatMessage(
        id: _generateMessageId(),
        sender: 'bot',
        message: "I'm having trouble processing your request. Please try again or contact support.",
        timestamp: DateTime.now(),
        type: 'text',
      );
    }
  }

  // Get conversation history (NO INDEX REQUIRED - fetches all and sorts in memory)
  static Future<List<ChatMessage>> getConversationHistory(
    String userId,
    String sessionId,
  ) async {
    try {
      // Fetch all messages without orderBy
      final snapshot = await _firestore
          .collection('chatbot_conversations')
          .doc(sessionId)
          .collection('messages')
          .get();
      
      // Convert to list and sort in memory
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .toList();
      
      // Sort by timestamp (oldest first)
      messages.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
      
      return messages;
    } catch (e) {
      debugPrint('Error getting conversation history: $e');
      return [];
    }
  }

  // Start new conversation
  static Future<String> startConversation(String userId) async {
    try {
      final sessionId = _generateSessionId();
      
      await _firestore.collection('chatbot_conversations').doc(sessionId).set({
        'userId': userId,
        'startedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Send welcome message
      final welcomeMessage = ChatMessage(
        id: _generateMessageId(),
        sender: 'bot',
        message: _getWelcomeMessage(),
        timestamp: DateTime.now(),
        type: 'text',
        quickReplies: _getQuickReplies('welcome'),
      );

      await _saveMessage(userId, sessionId, welcomeMessage);

      return sessionId;
    } catch (e) {
      debugPrint('Error starting conversation: $e');
      rethrow;
    }
  }

  // End conversation
  static Future<void> endConversation(String sessionId) async {
    try {
      await _firestore.collection('chatbot_conversations').doc(sessionId).update({
        'endedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });
    } catch (e) {
      debugPrint('Error ending conversation: $e');
    }
  }

  // Rate conversation
  static Future<void> rateConversation({
    required String sessionId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _firestore.collection('chatbot_conversations').doc(sessionId).update({
        'feedback.rating': rating,
        'feedback.comment': comment,
        'feedback.submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error rating conversation: $e');
    }
  }

  // Private methods
  static Future<String> _getBotResponse(String message, String userId) async {
    final lowerMessage = message.toLowerCase();
    
    // Fee queries
    if (lowerMessage.contains('fee') || lowerMessage.contains('payment') || 
        lowerMessage.contains('due') || lowerMessage.contains('amount')) {
      return await _getFeeResponse(userId);
    }
    
    // Complaint queries
    if (lowerMessage.contains('complaint') || lowerMessage.contains('issue') || 
        lowerMessage.contains('problem')) {
      return await _getComplaintResponse(userId);
    }
    
    // Mess queries
    if (lowerMessage.contains('mess') || lowerMessage.contains('food') || 
        lowerMessage.contains('meal') || lowerMessage.contains('menu')) {
      return await _getMessResponse();
    }
    
    // Attendance queries
    if (lowerMessage.contains('attendance') || lowerMessage.contains('present') || 
        lowerMessage.contains('absent') || lowerMessage.contains('check')) {
      return await _getAttendanceResponse(userId);
    }
    
    // Room queries
    if (lowerMessage.contains('room') || lowerMessage.contains('hostel') || 
        lowerMessage.contains('accommodation')) {
      return await _getRoomResponse(userId);
    }
    
    // Announcement queries
    if (lowerMessage.contains('announcement') || lowerMessage.contains('notice') ||
        lowerMessage.contains('news')) {
      return await _getAnnouncementResponse();
    }
    
    // Contact queries
    if (lowerMessage.contains('contact') || lowerMessage.contains('warden') || 
        lowerMessage.contains('help') || lowerMessage.contains('support')) {
      return await _getContactResponse();
    }
    
    // Greeting
    if (lowerMessage.contains('hello') || lowerMessage.contains('hi') || 
        lowerMessage.contains('hey')) {
      return _getGreetingResponse();
    }
    
    // Default response
    return _getDefaultResponse();
  }

  static Future<String> _getFeeResponse(String userId) async {
    try {
      // Fetch fees without orderBy
      final feesSnapshot = await _firestore
          .collection('fees')
          .where('studentId', isEqualTo: userId)
          .get();
      
      final fees = feesSnapshot.docs.map((doc) => doc.data()).toList();

      if (fees.isEmpty) {
        return "📋 I couldn't find any fee records for your account.\n\nPlease contact the admin office for assistance.";
      }

      double totalDue = 0;
      double totalPaid = 0;
      final List<String> feeDetails = [];

      for (var fee in fees) {
        final amount = (fee['amount'] as num?)?.toDouble() ?? 0;
        final paidAmount = (fee['paidAmount'] as num?)?.toDouble() ?? 0;
        final due = amount - paidAmount;
        final status = fee['status'] ?? 'pending';
        
        totalPaid += paidAmount;
        if (due > 0) {
          totalDue += due;
          feeDetails.add("• ${fee['feeType'] ?? 'Fee'}: ₹${due.toStringAsFixed(2)} (${_capitalize(status)})");
        } else {
          feeDetails.add("• ${fee['feeType'] ?? 'Fee'}: ✅ Paid ₹${amount.toStringAsFixed(2)}");
        }
      }

      if (totalDue > 0) {
        return "💰 **Fee Status**\n\n"
               "Total Pending: ₹${totalDue.toStringAsFixed(2)}\n"
               "Total Paid: ₹${totalPaid.toStringAsFixed(2)}\n\n"
               "**Details:**\n${feeDetails.join('\n')}\n\n"
               "Please pay before the due date to avoid late fees.";
      } else {
        return "✅ **Great news!**\n\n"
               "You have no pending fees.\n"
               "Total Paid: ₹${totalPaid.toStringAsFixed(2)}\n\n"
               "All your payments are up to date!";
      }
    } catch (e) {
      debugPrint('Fee response error: $e');
      return "I'm having trouble fetching your fee details. Please check the Fees section in the app.";
    }
  }

  static Future<String> _getComplaintResponse(String userId) async {
    try {
      // Fetch complaints without orderBy
      final complaintsSnapshot = await _firestore
          .collection('complaints')
          .where('studentId', isEqualTo: userId)
          .get();
      
      final complaints = complaintsSnapshot.docs.map((doc) => doc.data()).toList();
      
      // Sort in memory by createdAt (newest first)
      complaints.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      if (complaints.isEmpty) {
        return "📝 You haven't raised any complaints yet.\n\nIf you have an issue, you can raise a complaint in the Complaints section. I'm here to help!";
      }

      final List<String> complaintList = [];
      for (var c in complaints.take(5)) {
        final status = c['status'] ?? 'pending';
        String emoji;
        String displayStatus;
        
        switch (status) {
          case 'resolved':
            emoji = '✅';
            displayStatus = 'Resolved';
            break;
          case 'assigned':
            emoji = '🔄';
            displayStatus = 'Assigned';
            break;
          case 'rejected':
            emoji = '❌';
            displayStatus = 'Rejected';
            break;
          default:
            emoji = '⏳';
            displayStatus = 'Pending';
        }
        
        complaintList.add("$emoji #${c['complaintNumber']}: ${c['title']} - $displayStatus");
      }

      return "📋 **Your Complaints**\n\n${complaintList.join('\n')}\n\n"
             "Total: ${complaints.length} complaint${complaints.length > 1 ? 's' : ''}\n\n"
             "You can track all complaints in the Complaints section.";
    } catch (e) {
      debugPrint('Complaint response error: $e');
      return "I'm having trouble fetching your complaints. Please check the Complaints section.";
    }
  }

  static Future<String> _getMessResponse() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final menuSnapshot = await _firestore
          .collection('messMenuDaily')
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (menuSnapshot.docs.isNotEmpty) {
        final todayMenu = menuSnapshot.docs.first.data();
        final breakfast = List<String>.from(todayMenu['breakfast']?['items'] ?? []);
        final lunch = List<String>.from(todayMenu['lunch']?['items'] ?? []);
        final dinner = List<String>.from(todayMenu['dinner']?['items'] ?? []);
        
        String response = "🍽️ **Today's Mess Menu**\n\n";
        
        if (breakfast.isNotEmpty) {
          response += "🌅 **Breakfast** (7:00 AM - 9:00 AM)\n";
          response += "${breakfast.map((i) => "• $i").join('\n')}\n\n";
        }
        if (lunch.isNotEmpty) {
          response += "☀️ **Lunch** (12:00 PM - 2:00 PM)\n";
          response += "${lunch.map((i) => "• $i").join('\n')}\n\n";
        }
        if (dinner.isNotEmpty) {
          response += "🌙 **Dinner** (7:00 PM - 9:00 PM)\n";
          response += "${dinner.map((i) => "• $i").join('\n')}";
        }
        
        return response;
      }
      
      return "📋 Today's menu hasn't been updated yet.\n\nPlease check back later or contact the mess office.";
    } catch (e) {
      debugPrint('Mess response error: $e');
      return "🍽️ **Today's Sample Menu**\n\n"
             "🌅 Breakfast: Idli, Sambar, Chutney\n"
             "☀️ Lunch: Rice, Dal, Mixed Vegetable Curry\n"
             "🌙 Dinner: Roti, Paneer Butter Masala, Salad\n\n"
             "Check the Mess Menu section for exact details.";
    }
  }

  static Future<String> _getAttendanceResponse(String userId) async {
    try {
      final today = await AttendanceService.getTodayAttendance(userId);
      
      if (!today['checkedIn']) {
        return "📅 **Attendance Status**\n\n"
               "You haven't checked in today.\n\n"
               "📍 Please mark your attendance when you enter the hostel campus.";
      }
      
      final checkInTime = DateFormat('hh:mm a').format(today['checkInTime'].toDate());
      
      if (!today['checkedOut']) {
        return "📅 **Today's Attendance**\n\n"
               "✅ Check-in: $checkInTime\n"
               "⏳ Check-out: Not yet\n\n"
               "Don't forget to check out before leaving the hostel.";
      } else {
        final checkOutTime = DateFormat('hh:mm a').format(today['checkOutTime'].toDate());
        return "📅 **Today's Attendance**\n\n"
               "✅ Check-in: $checkInTime\n"
               "✅ Check-out: $checkOutTime\n\n"
               "Have a great day!";
      }
    } catch (e) {
      debugPrint('Attendance response error: $e');
      return "Your attendance for today is not marked yet. Please check in when you're in the hostel.";
    }
  }

  static Future<String> _getRoomResponse(String userId) async {
    try {
      final studentDoc = await _firestore
          .collection('students')
          .doc(userId)
          .get();

      if (studentDoc.exists) {
        final student = studentDoc.data();
        if (student != null && student['roomNumber'] != null) {
          return "🏠 **Your Room Information**\n\n"
                 "• Room Number: ${student['roomNumber']}\n"
                 "• Block: ${student['hostelBlock'] ?? 'N/A'}\n"
                 "• Floor: ${student['floor'] ?? 'N/A'}\n\n"
                 "For any room-related issues, please contact the hostel office.";
        }
      }
      
      return "🏠 You haven't been allocated a room yet.\n\n"
             "Please contact the hostel administration for room allocation.";
    } catch (e) {
      debugPrint('Room response error: $e');
      return "For room-related queries, please contact the hostel office during working hours (9 AM - 5 PM).";
    }
  }

  static Future<String> _getAnnouncementResponse() async {
    try {
      // Fetch announcements without orderBy
      final announcementsSnapshot = await _firestore
          .collection('announcements')
          .limit(3)
          .get();
      
      final announcements = announcementsSnapshot.docs.map((doc) => doc.data()).toList();
      
      // Sort in memory by createdAt (newest first)
      announcements.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      if (announcements.isEmpty) {
        return "📢 No recent announcements.\n\nCheck back later for updates.";
      }

      String response = "📢 **Recent Announcements**\n\n";
      for (var ann in announcements.take(3)) {
        response += "• ${ann['title']}\n";
        response += "  ${_getTimeAgo(ann['createdAt'])}\n\n";
      }
      response += "Check the Announcements section for more details.";
      
      return response;
    } catch (e) {
      debugPrint('Announcement response error: $e');
      return "You can view all announcements in the Announcements section of the app.";
    }
  }

  static Future<String> _getContactResponse() async {
    try {
      final settingsDoc = await _firestore
          .collection('hostelSettings')
          .doc('settings')
          .get();

      if (settingsDoc.exists) {
        final settings = settingsDoc.data();
        if (settings != null) {
          return "📞 **Hostel Contact Information**\n\n"
                 "🏢 Warden: ${settings['wardenName'] ?? 'N/A'}\n"
                 "📱 Contact: ${settings['contactNumber'] ?? 'N/A'}\n"
                 "📧 Email: ${settings['email'] ?? 'N/A'}\n"
                 "⏰ Office Hours: 9:00 AM - 5:00 PM\n\n"
                 "For emergencies, contact the security desk immediately.";
        }
      }
    } catch (e) {
      debugPrint('Contact response error: $e');
    }
    
    return "📞 **Contact Information**\n\n"
           "• Warden: Available during office hours\n"
           "• Caretaker: +91 9876543210\n"
           "• Security: Emergency number in app\n"
           "• Office: hostel@college.edu\n\n"
           "Office Hours: Monday-Friday, 9 AM - 5 PM";
  }

  static String _getGreetingResponse() {
    final greetings = [
      "👋 Hello! How can I assist you today?",
      "Hi there! 👋 What can I help you with?",
      "Hey! 😊 How can I make your day better?",
      "Greetings! 🌟 What would you like to know?",
    ];
    return greetings[Random().nextInt(greetings.length)];
  }

  static String _getWelcomeMessage() {
    return "👋 **Welcome to Hostel Assistant!**\n\n"
           "I'm your AI-powered hostel companion. I can help you with:\n\n"
           "💰 Check fee status\n"
           "📝 Track your complaints\n"
           "🍽️ View today's mess menu\n"
           "📅 Mark attendance\n"
           "🏠 Get room information\n"
           "📢 Read announcements\n"
           "📞 Find contact details\n\n"
           "**What would you like to know today?**";
  }

  static String _getDefaultResponse() {
    final responses = [
      "I understand you need help. Could you please be more specific?\n\nYou can ask about:\n• Fee status\n• Complaint tracking\n• Today's mess menu\n• Attendance\n• Announcements\n• Contact details",
      
      "I'm here to help! What would you like to know about?\n\nTry asking:\n• \"What's my fee status?\"\n• \"Where is my complaint?\"\n• \"Today's menu\"\n• \"Contact warden\"",
      
      "I'm not sure I understood that. Here's what I can help with:\n\n💰 Fees | 📝 Complaints | 🍽️ Mess Menu\n📅 Attendance | 🏠 Rooms | 📢 Announcements | 📞 Contacts",
    ];
    return responses[Random().nextInt(responses.length)];
  }

  static List<String> _getQuickReplies(String? intent) {
    switch (intent) {
      case 'fee':
        return ['My fee status', 'Pay fee', 'Due date'];
      case 'complaint':
        return ['Raise complaint', 'Complaint status', 'Track complaint'];
      case 'mess':
        return ["Today's menu", 'Mess timings', 'Meal history'];
      case 'attendance':
        return ["Today's attendance", 'Mark attendance', 'Attendance history'];
      case 'room':
        return ['My room', 'Room allocation', 'Roommates'];
      case 'announcement':
        return ['Recent announcements', 'View all'];
      case 'contact':
        return ['Warden contact', 'Emergency', 'Office hours'];
      case 'welcome':
        return ['Fees', 'Complaints', 'Mess Menu', 'Attendance', 'Announcements', 'Contact'];
      default:
        return ['Fee status', 'My complaints', "Today's menu", 'Contact support'];
    }
  }

  static Future<Map<String, dynamic>> _analyzeIntent(String message) async {
    final lowerMessage = message.toLowerCase();
    
    if (lowerMessage.contains('fee') || lowerMessage.contains('payment') || lowerMessage.contains('due')) {
      return {'intent': 'fee', 'confidence': 0.95};
    }
    if (lowerMessage.contains('complaint') || lowerMessage.contains('issue') || lowerMessage.contains('problem')) {
      return {'intent': 'complaint', 'confidence': 0.95};
    }
    if (lowerMessage.contains('mess') || lowerMessage.contains('food') || lowerMessage.contains('meal') || lowerMessage.contains('menu')) {
      return {'intent': 'mess', 'confidence': 0.95};
    }
    if (lowerMessage.contains('attendance') || lowerMessage.contains('present') || lowerMessage.contains('absent')) {
      return {'intent': 'attendance', 'confidence': 0.95};
    }
    if (lowerMessage.contains('room') || lowerMessage.contains('hostel')) {
      return {'intent': 'room', 'confidence': 0.90};
    }
    if (lowerMessage.contains('announcement') || lowerMessage.contains('notice')) {
      return {'intent': 'announcement', 'confidence': 0.90};
    }
    if (lowerMessage.contains('contact') || lowerMessage.contains('warden') || lowerMessage.contains('help')) {
      return {'intent': 'contact', 'confidence': 0.90};
    }
    if (lowerMessage.contains('hello') || lowerMessage.contains('hi') || lowerMessage.contains('hey')) {
      return {'intent': 'greeting', 'confidence': 0.99};
    }
    
    return {'intent': 'unknown', 'confidence': 0.3};
  }

  static String _getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 7) return '${diff.inDays} days ago';
      if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
      return 'Just now';
    }
    return 'Recently';
  }

  static Future<void> _saveMessage(
    String userId,
    String sessionId,
    ChatMessage message,
  ) async {
    try {
      await _firestore
          .collection('chatbot_conversations')
          .doc(sessionId)
          .collection('messages')
          .doc(message.id)
          .set(message.toMap());
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  static String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  static String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}