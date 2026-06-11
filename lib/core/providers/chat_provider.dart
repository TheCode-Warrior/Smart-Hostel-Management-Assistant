import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../services/chatbot_service.dart';

class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _currentMessages = [];
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isTyping = false;

  List<ChatMessage> get currentMessages => _currentMessages;
  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isTyping => _isTyping;

  // Start a new conversation
  Future<String> startConversation(String userId) async {
    _setLoading(true);
    try {
      final sessionId = await ChatbotService.startConversation(userId);
      
      // Load initial messages
      _currentMessages = await ChatbotService.getConversationHistory(
        userId,
        sessionId,
      );
      
      _currentSession = ChatSession(
        id: sessionId,
        userId: userId,
        startedAt: DateTime.now(),
        status: 'active',
        messages: _currentMessages,
      );
      
      _setLoading(false);
      return sessionId;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      rethrow;
    }
  }

  // Send a message
  Future<ChatMessage> sendMessage({
    required String userId,
    required String message,
    required String sessionId,
  }) async {
    _setTyping(true);
    
    try {
      final botMessage = await ChatbotService.processMessage(
        userId: userId,
        message: message,
        sessionId: sessionId,
      );
      
      // Reload messages
      _currentMessages = await ChatbotService.getConversationHistory(
        userId,
        sessionId,
      );
      
      _setTyping(false);
      return botMessage;
    } catch (e) {
      _errorMessage = e.toString();
      _setTyping(false);
      rethrow;
    }
  }

  // Load conversation history
  Future<void> loadConversationHistory(String userId, String sessionId) async {
    _setLoading(true);
    try {
      _currentMessages = await ChatbotService.getConversationHistory(
        userId,
        sessionId,
      );
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // Load all sessions for a user
  Future<void> loadUserSessions(String userId) async {
    _setLoading(true);
    try {
      // This would fetch all sessions from Firestore
      // For now, using placeholder
      _sessions = [];
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  // End current conversation
  Future<void> endConversation(String sessionId) async {
    try {
      await ChatbotService.endConversation(sessionId);
      _currentSession = null;
      _currentMessages = [];
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Rate conversation
  Future<void> rateConversation({
    required String sessionId,
    required int rating,
    String? comment,
  }) async {
    try {
      await ChatbotService.rateConversation(
        sessionId: sessionId,
        rating: rating,
        comment: comment,
      );
      
      if (_currentSession?.id == sessionId) {
        _currentSession?.feedback = {
          'rating': rating,
          'comment': comment,
        };
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Clear current conversation
  void clearCurrentConversation() {
    _currentMessages = [];
    _currentSession = null;
    notifyListeners();
  }

  // Get suggested replies based on last message
  List<String> getSuggestedReplies() {
    if (_currentMessages.isEmpty) {
      return ChatQuickReplies.welcome;
    }
    
    final lastBotMessage = _currentMessages.lastWhere(
      (m) => m.isFromBot,
      orElse: () => _currentMessages.last,
    );
    
    return lastBotMessage.quickReplies ?? ChatQuickReplies.welcome;
  }

  // Check if conversation should be escalated
  bool shouldEscalate() {
    if (_currentMessages.length < 3) return false;
    
    // Check for repeated questions or low confidence
    final botMessages = _currentMessages.where((m) => m.isFromBot).toList();
    if (botMessages.length >= 2) {
      final lastTwo = botMessages.reversed.take(2).toList();
      if (lastTwo.length == 2) {
        // If bot gave same response twice, escalate
        if (lastTwo[0].message == lastTwo[1].message) {
          return true;
        }
        // If confidence is consistently low
        if ((lastTwo[0].confidence ?? 1) < 0.5 && 
            (lastTwo[1].confidence ?? 1) < 0.5) {
          return true;
        }
      }
    }
    
    return false;
  }

  // Get conversation summary
  Map<String, dynamic> getConversationSummary() {
    if (_currentMessages.isEmpty) {
      return {};
    }
    
    int userMessages = _currentMessages.where((m) => m.isFromUser).length;
    int botMessages = _currentMessages.where((m) => m.isFromBot).length;
    
    Map<String, int> intents = {};
    for (var msg in _currentMessages) {
      if (msg.intent != null) {
        intents[msg.intent!] = (intents[msg.intent!] ?? 0) + 1;
      }
    }
    
    return {
      'totalMessages': _currentMessages.length,
      'userMessages': userMessages,
      'botMessages': botMessages,
      'intents': intents,
      'duration': _currentSession?.durationString ?? '0s',
    };
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set typing state
  void _setTyping(bool typing) {
    _isTyping = typing;
    notifyListeners();
  }
}