import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ComplaintCategory {
  electrical, plumbing, carpentry, cleaning, internet, security, mess, other
}

enum ComplaintPriority { low, medium, high, emergency }
enum ComplaintStatus { pending, assigned, resolved, rejected }

class ComplaintModel {
  String? id;
  String? studentId;
  String? studentName;
  String? complaintNumber;
  ComplaintCategory? category;
  String? subCategory;
  ComplaintPriority? priority;
  String? title;
  String? description;
  String? location;
  List<String>? attachments;
  ComplaintStatus? status;
  String? assignedTo;
  String? assignedToName;
  Timestamp? assignedAt;
  Timestamp? resolvedAt;
  String? resolvedBy;
  String? resolvedByName;
  String? resolutionNotes;
  List<String>? resolutionAttachments;
  double? studentRating;
  String? studentFeedback;
  int? timeToResolve;
  bool? isEscalated;
  String? escalatedTo;
  Timestamp? escalatedAt;
  String? escalationReason;
  List<ComplaintUpdate>? updates;
  String? createdBy;
  Timestamp? createdAt;
  Timestamp? lastUpdatedAt;

  ComplaintModel({
    this.id,
    this.studentId,
    this.studentName,
    this.complaintNumber,
    this.category,
    this.subCategory,
    this.priority,
    this.title,
    this.description,
    this.location,
    this.attachments,
    this.status,
    this.assignedTo,
    this.assignedToName,
    this.assignedAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolvedByName,
    this.resolutionNotes,
    this.resolutionAttachments,
    this.studentRating,
    this.studentFeedback,
    this.timeToResolve,
    this.isEscalated,
    this.escalatedTo,
    this.escalatedAt,
    this.escalationReason,
    this.updates,
    this.createdBy,
    this.createdAt,
    this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'complaintNumber': complaintNumber,
      'category': category?.toString().split('.').last,
      'subCategory': subCategory,
      'priority': priority?.toString().split('.').last,
      'title': title,
      'description': description,
      'location': location,
      'attachments': attachments ?? [],
      'status': status?.toString().split('.').last ?? 'pending',
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedAt': assignedAt,
      'resolvedAt': resolvedAt,
      'resolvedBy': resolvedBy,
      'resolvedByName': resolvedByName,
      'resolutionNotes': resolutionNotes,
      'resolutionAttachments': resolutionAttachments ?? [],
      'studentRating': studentRating,
      'studentFeedback': studentFeedback,
      'timeToResolve': timeToResolve,
      'isEscalated': isEscalated ?? false,
      'escalatedTo': escalatedTo,
      'escalatedAt': escalatedAt,
      'escalationReason': escalationReason,
      'updates': updates?.map((u) => u.toMap()).toList() ?? [],
      'createdBy': createdBy,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastUpdatedAt': lastUpdatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory ComplaintModel.fromMap(Map<String, dynamic> map, String id) {
    return ComplaintModel(
      id: id,
      studentId: map['studentId'],
      studentName: map['studentName'],
      complaintNumber: map['complaintNumber'],
      category: _stringToCategory(map['category']),
      subCategory: map['subCategory'],
      priority: _stringToPriority(map['priority']),
      title: map['title'],
      description: map['description'],
      location: map['location'],
      attachments: List<String>.from(map['attachments'] ?? []),
      status: _stringToStatus(map['status']),
      assignedTo: map['assignedTo'],
      assignedToName: map['assignedToName'],
      assignedAt: map['assignedAt'],
      resolvedAt: map['resolvedAt'],
      resolvedBy: map['resolvedBy'],
      resolvedByName: map['resolvedByName'],
      resolutionNotes: map['resolutionNotes'],
      resolutionAttachments: List<String>.from(map['resolutionAttachments'] ?? []),
      studentRating: (map['studentRating'] ?? 0).toDouble(),
      studentFeedback: map['studentFeedback'],
      timeToResolve: map['timeToResolve'],
      isEscalated: map['isEscalated'] ?? false,
      escalatedTo: map['escalatedTo'],
      escalatedAt: map['escalatedAt'],
      escalationReason: map['escalationReason'],
      updates: (map['updates'] as List?)
          ?.map((u) => ComplaintUpdate.fromMap(u))
          .toList(),
      createdBy: map['createdBy'],
      createdAt: map['createdAt'],
      lastUpdatedAt: map['lastUpdatedAt'],
    );
  }

  static ComplaintCategory _stringToCategory(String? category) {
    switch (category) {
      case 'electrical': return ComplaintCategory.electrical;
      case 'plumbing': return ComplaintCategory.plumbing;
      case 'carpentry': return ComplaintCategory.carpentry;
      case 'cleaning': return ComplaintCategory.cleaning;
      case 'internet': return ComplaintCategory.internet;
      case 'security': return ComplaintCategory.security;
      case 'mess': return ComplaintCategory.mess;
      case 'other': return ComplaintCategory.other;
      default: return ComplaintCategory.other;
    }
  }

  static ComplaintPriority _stringToPriority(String? priority) {
    switch (priority) {
      case 'low': return ComplaintPriority.low;
      case 'medium': return ComplaintPriority.medium;
      case 'high': return ComplaintPriority.high;
      case 'emergency': return ComplaintPriority.emergency;
      default: return ComplaintPriority.medium;
    }
  }

  static ComplaintStatus _stringToStatus(String? status) {
    switch (status) {
      case 'pending': return ComplaintStatus.pending;
      case 'assigned': return ComplaintStatus.assigned;
      case 'resolved': return ComplaintStatus.resolved;
      case 'rejected': return ComplaintStatus.rejected;
      default: return ComplaintStatus.pending;
    }
  }

  String get categoryString {
    switch (category) {
      case ComplaintCategory.electrical: return 'Electrical';
      case ComplaintCategory.plumbing: return 'Plumbing';
      case ComplaintCategory.carpentry: return 'Carpentry';
      case ComplaintCategory.cleaning: return 'Cleaning';
      case ComplaintCategory.internet: return 'Internet';
      case ComplaintCategory.security: return 'Security';
      case ComplaintCategory.mess: return 'Mess';
      case ComplaintCategory.other: return 'Other';
      default: return 'Other';
    }
  }

  String get priorityString {
    switch (priority) {
      case ComplaintPriority.low: return 'Low';
      case ComplaintPriority.medium: return 'Medium';
      case ComplaintPriority.high: return 'High';
      case ComplaintPriority.emergency: return 'Emergency';
      default: return 'Medium';
    }
  }

  String get statusString {
    switch (status) {
      case ComplaintStatus.pending: return 'Pending';
      case ComplaintStatus.assigned: return 'Assigned';
      case ComplaintStatus.resolved: return 'Resolved';
      case ComplaintStatus.rejected: return 'Rejected';
      default: return 'Pending';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case ComplaintPriority.low: return Colors.green;
      case ComplaintPriority.medium: return Colors.orange;
      case ComplaintPriority.high: return Colors.red;
      case ComplaintPriority.emergency: return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color get statusColor {
    switch (status) {
      case ComplaintStatus.pending: return Colors.orange;
      case ComplaintStatus.assigned: return Colors.blue;
      case ComplaintStatus.resolved: return Colors.green;
      case ComplaintStatus.rejected: return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case ComplaintStatus.pending: return Icons.pending;
      case ComplaintStatus.assigned: return Icons.person;
      case ComplaintStatus.resolved: return Icons.check_circle;
      case ComplaintStatus.rejected: return Icons.cancel;
      default: return Icons.help;
    }
  }
}

// ✅ FIXED: ComplaintUpdate with dynamic updatedAt to handle both Timestamp and String
class ComplaintUpdate {
  String? status;
  String? comment;
  String? updatedBy;
  dynamic updatedAt; // Can be Timestamp or String
  List<String>? attachments;

  ComplaintUpdate({
    this.status,
    this.comment,
    this.updatedBy,
    this.updatedAt,
    this.attachments,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'comment': comment,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
      'attachments': attachments ?? [],
    };
  }

  factory ComplaintUpdate.fromMap(Map<String, dynamic> map) {
    return ComplaintUpdate(
      status: map['status'],
      comment: map['comment'],
      updatedBy: map['updatedBy'],
      updatedAt: map['updatedAt'],
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }
  
  // Helper method to get DateTime from updatedAt
  DateTime? get updatedAtDateTime {
    if (updatedAt == null) return null;
    if (updatedAt is Timestamp) {
      return (updatedAt as Timestamp).toDate();
    }
    if (updatedAt is String) {
      return DateTime.tryParse(updatedAt as String);
    }
    return null;
  }
}