import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatMessage {
  String? id;
  String? sender; // 'user' or 'bot'
  String? message;
  DateTime? timestamp;
  String? type; // 'text', 'image', 'quick_reply'
  List<String>? quickReplies;
  String? intent;
  String? sentiment;
  double? confidence;
  Map<String, dynamic>? metadata;
  bool? isRead;

  ChatMessage({
    this.id,
    this.sender,
    this.message,
    this.timestamp,
    this.type,
    this.quickReplies,
    this.intent,
    this.sentiment,
    this.confidence,
    this.metadata,
    this.isRead,
  });

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'message': message,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'type': type ?? 'text',
      'quickReplies': quickReplies ?? [],
      'intent': intent,
      'sentiment': sentiment,
      'confidence': confidence,
      'metadata': metadata ?? {},
      'isRead': isRead ?? false,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      sender: map['sender'],
      message: map['message'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
      type: map['type'],
      quickReplies: List<String>.from(map['quickReplies'] ?? []),
      intent: map['intent'],
      sentiment: map['sentiment'],
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      metadata: map['metadata'],
      isRead: map['isRead'],
    );
  }

  bool get isFromUser => sender == 'user';
  bool get isFromBot => sender == 'bot';

  Color get senderColor {
    return isFromUser ? Colors.blue : Colors.grey;
  }

  IconData get senderIcon {
    return isFromUser ? Icons.person : Icons.smart_toy;
  }

  String get timeString {
    if (timestamp == null) return '';
    return '${timestamp!.hour.toString().padLeft(2, '0')}:${timestamp!.minute.toString().padLeft(2, '0')}';
  }

  String get dateString {
    if (timestamp == null) return '';
    return '${timestamp!.day}/${timestamp!.month}/${timestamp!.year}';
  }

  String get fullDateTimeString {
    if (timestamp == null) return '';
    return '$dateString $timeString';
  }

  bool get hasQuickReplies {
    return quickReplies != null && quickReplies!.isNotEmpty;
  }

  bool get hasMetadata {
    return metadata != null && metadata!.isNotEmpty;
  }

  String? getMetadataValue(String key) {
    return metadata?[key]?.toString();
  }

  double get confidenceScore {
    return (confidence ?? 0) * 100;
  }

  String get confidenceLevel {
    if (confidence == null) return 'Unknown';
    if (confidence! >= 0.9) return 'High';
    if (confidence! >= 0.7) return 'Medium';
    if (confidence! >= 0.5) return 'Low';
    return 'Very Low';
  }

  Color get confidenceColor {
    if (confidence == null) return Colors.grey;
    if (confidence! >= 0.9) return Colors.green;
    if (confidence! >= 0.7) return Colors.blue;
    if (confidence! >= 0.5) return Colors.orange;
    return Colors.red;
  }
}

class ChatSession {
  String? id;
  String? userId;
  DateTime? startedAt;
  DateTime? endedAt;
  String? status; // 'active', 'completed', 'escalated'
  List<ChatMessage>? messages;
  Map<String, dynamic>? feedback;
  String? escalatedTo;
  DateTime? escalatedAt;
  String? escalationReason;
  String? deviceInfo;
  String? platform;

  ChatSession({
    this.id,
    this.userId,
    this.startedAt,
    this.endedAt,
    this.status,
    this.messages,
    this.feedback,
    this.escalatedTo,
    this.escalatedAt,
    this.escalationReason,
    this.deviceInfo,
    this.platform,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : FieldValue.serverTimestamp(),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'status': status ?? 'active',
      'messages': messages?.map((m) => m.toMap()).toList() ?? [],
      'feedback': feedback ?? {},
      'escalatedTo': escalatedTo,
      'escalatedAt': escalatedAt != null ? Timestamp.fromDate(escalatedAt!) : null,
      'escalationReason': escalationReason,
      'deviceInfo': deviceInfo,
      'platform': platform,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map, String id) {
    return ChatSession(
      id: id,
      userId: map['userId'],
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      status: map['status'],
      messages: (map['messages'] as List?)
          ?.map((m) => ChatMessage.fromMap(m, m['id'] ?? ''))
          .toList(),
      feedback: map['feedback'],
      escalatedTo: map['escalatedTo'],
      escalatedAt: (map['escalatedAt'] as Timestamp?)?.toDate(),
      escalationReason: map['escalationReason'],
      deviceInfo: map['deviceInfo'],
      platform: map['platform'],
    );
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isEscalated => status == 'escalated';

  int get messageCount => messages?.length ?? 0;

  int get userMessageCount {
    return messages?.where((m) => m.isFromUser).length ?? 0;
  }

  int get botMessageCount {
    return messages?.where((m) => m.isFromBot).length ?? 0;
  }

  Duration get duration {
    if (startedAt == null) return Duration.zero;
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  String get durationString {
    final d = duration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m';
    } else {
      return '${d.inSeconds}s';
    }
  }

  bool hasFeedback() {
    return feedback != null && feedback!.isNotEmpty;
  }

  int? get feedbackRating {
    return feedback?['rating'];
  }

  String? get feedbackComment {
    return feedback?['comment'];
  }
}

class QuickReplyOption {
  String? title;
  String? payload;
  String? imageUrl;

  QuickReplyOption({
    this.title,
    this.payload,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'payload': payload,
      'imageUrl': imageUrl,
    };
  }

  factory QuickReplyOption.fromMap(Map<String, dynamic> map) {
    return QuickReplyOption(
      title: map['title'],
      payload: map['payload'],
      imageUrl: map['imageUrl'],
    );
  }
}

class ChatIntent {
  String? name;
  double? confidence;
  Map<String, dynamic>? parameters;

  ChatIntent({
    this.name,
    this.confidence,
    this.parameters,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'confidence': confidence,
      'parameters': parameters ?? {},
    };
  }

  factory ChatIntent.fromMap(Map<String, dynamic> map) {
    return ChatIntent(
      name: map['name'],
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      parameters: map['parameters'],
    );
  }

  bool get isHighConfidence => (confidence ?? 0) >= 0.8;
  bool get isMediumConfidence => (confidence ?? 0) >= 0.5 && (confidence ?? 0) < 0.8;
  bool get isLowConfidence => (confidence ?? 0) < 0.5;

  String? getParameter(String key) {
    return parameters?[key]?.toString();
  }
}

// Pre-defined quick replies for common queries
class ChatQuickReplies {
  static const List<String> welcome = [
    'Fees',
    'Complaints',
    'Mess Menu',
    'Attendance',
    'Contact',
  ];

  static const List<String> fees = [
    'My fee status',
    'Pay fee',
    'Due date',
    'Fine details',
  ];

  static const List<String> complaints = [
    'Raise complaint',
    'Complaint status',
    'Track complaint',
    'Previous complaints',
  ];

  static const List<String> mess = [
    'Today\'s menu',
    'Mess timings',
    'Meal history',
    'Special meal',
  ];

  static const List<String> attendance = [
    'Today\'s attendance',
    'Attendance history',
    'Mark attendance',
    'Leave request',
  ];

  static const List<String> contact = [
    'Warden contact',
    'Caretaker',
    'Emergency',
    'Office hours',
  ];

  static List<String> getRepliesForIntent(String? intent) {
    switch (intent) {
      case 'fee':
        return fees;
      case 'complaint':
        return complaints;
      case 'mess':
        return mess;
      case 'attendance':
        return attendance;
      case 'contact':
        return contact;
      default:
        return welcome;
    }
  }
}