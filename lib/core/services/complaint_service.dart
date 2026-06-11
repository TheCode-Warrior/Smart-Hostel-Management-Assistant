import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/complaint_model.dart';
import 'firestore_service.dart';

class ComplaintService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new complaint
  static Future<Map<String, dynamic>> createComplaint({
    required String studentId,
    required String studentName,
    required String category,
    required String priority,
    required String title,
    required String description,
    required String location,
    List<String>? attachments,
  }) async {
    try {
      final complaintNumber = await _generateComplaintNumber();
      
      final complaintData = {
        'studentId': studentId,
        'studentName': studentName,
        'complaintNumber': complaintNumber,
        'category': category.toLowerCase(),
        'priority': priority.toLowerCase(),
        'title': title,
        'description': description,
        'location': location,
        'attachments': attachments ?? [],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await _firestore.collection('complaints').add(complaintData);
      
      return {
        'success': true,
        'message': 'Complaint raised successfully',
        'complaintId': docRef.id,
        'complaintNumber': complaintNumber,
      };
    } catch (e) {
      debugPrint('Error creating complaint: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Get complaints for a student
  static Future<List<ComplaintModel>> getStudentComplaints(String studentId) async {
    try {
      final querySnapshot = await _firestore
          .collection('complaints')
          .where('studentId', isEqualTo: studentId)
          .get();
      
      final complaints = querySnapshot.docs
          .map((doc) => ComplaintModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      complaints.sort((a, b) {
        final aDate = a.createdAt?.toDate() ?? DateTime.now();
        final bDate = b.createdAt?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
      
      return complaints;
    } catch (e) {
      debugPrint('Error getting student complaints: $e');
      return [];
    }
  }

  // Get all complaints
  static Future<List<ComplaintModel>> getAllComplaints({
    ComplaintStatus? status,
    String? assignedTo,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('complaints');
      
      if (status != null) {
        query = query.where('status', isEqualTo: status.toString().split('.').last);
      }
      
      if (assignedTo != null) {
        query = query.where('assignedTo', isEqualTo: assignedTo);
      }
      
      final querySnapshot = await query.get();
      
      final complaints = querySnapshot.docs
          .map((doc) => ComplaintModel.fromMap(doc.data(), doc.id))
          .toList();
      
      complaints.sort((a, b) {
        final aDate = a.createdAt?.toDate() ?? DateTime.now();
        final bDate = b.createdAt?.toDate() ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
      
      return complaints;
    } catch (e) {
      debugPrint('Error getting all complaints: $e');
      return [];
    }
  }

  // Get complaint by ID
  static Future<ComplaintModel?> getComplaintById(String complaintId) async {
    try {
      final doc = await _firestore.collection('complaints').doc(complaintId).get();
      
      if (doc.exists) {
        return ComplaintModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting complaint: $e');
      return null;
    }
  }

  // Update complaint status - FIXED
  static Future<Map<String, dynamic>> updateComplaintStatus({
    required String complaintId,
    required ComplaintStatus newStatus,
    required String updatedBy,
    String? comment,
    String? resolvedBy,
    String? resolutionNotes,
    List<String>? attachments,
  }) async {
    try {
      final complaintRef = _firestore.collection('complaints').doc(complaintId);
      
      final doc = await complaintRef.get();
      if (!doc.exists) {
        return {'success': false, 'message': 'Complaint not found'};
      }
      
      final currentData = doc.data() as Map<String, dynamic>;
      final currentUpdates = List<Map<String, dynamic>>.from(currentData['updates'] ?? []);
      
      // Create new update entry with DateTime.now() - Firestore will convert to Timestamp
      final updateEntry = {
        'status': newStatus.toString().split('.').last,
        'updatedBy': updatedBy,
        'updatedAt': DateTime.now(), // DateTime.now() is automatically converted to Timestamp by Firestore
      };
      
      if (comment != null && comment.isNotEmpty) {
        updateEntry['comment'] = comment;
      }
      
      currentUpdates.add(updateEntry);
      
      final Map<String, dynamic> updateData = {
        'status': newStatus.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
        'updates': currentUpdates,
      };
      
      if (newStatus == ComplaintStatus.resolved) {
        updateData['resolvedAt'] = FieldValue.serverTimestamp();
        if (resolvedBy != null) updateData['resolvedBy'] = resolvedBy;
        if (resolutionNotes != null) updateData['resolutionNotes'] = resolutionNotes;
        if (attachments != null) updateData['resolutionAttachments'] = attachments;
      }
      
      if (newStatus == ComplaintStatus.rejected) {
        updateData['rejectedAt'] = FieldValue.serverTimestamp();
        updateData['rejectedBy'] = updatedBy;
        if (comment != null) updateData['rejectionReason'] = comment;
      }
      
      await complaintRef.update(updateData);
      
      debugPrint('✅ Complaint status updated to: ${newStatus.toString().split('.').last}');
      
      return {
        'success': true,
        'message': 'Complaint status updated to ${newStatus.toString().split('.').last}',
      };
    } catch (e) {
      debugPrint('Error updating complaint status: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Assign complaint to staff
  static Future<Map<String, dynamic>> assignComplaint({
    required String complaintId,
    required String staffId,
    required String staffName,
    required String assignedBy,
  }) async {
    try {
      final complaintRef = _firestore.collection('complaints').doc(complaintId);
      
      final doc = await complaintRef.get();
      if (!doc.exists) {
        return {'success': false, 'message': 'Complaint not found'};
      }
      
      final currentData = doc.data() as Map<String, dynamic>;
      final currentUpdates = List<Map<String, dynamic>>.from(currentData['updates'] ?? []);
      
      final updateEntry = {
        'status': 'assigned',
        'comment': 'Assigned to $staffName',
        'updatedBy': assignedBy,
        'updatedAt': DateTime.now(), // DateTime.now() works here
      };
      
      currentUpdates.add(updateEntry);
      
      final updateData = {
        'assignedTo': staffId,
        'assignedToName': staffName,
        'assignedAt': FieldValue.serverTimestamp(),
        'status': 'assigned',
        'updatedAt': FieldValue.serverTimestamp(),
        'updates': currentUpdates,
      };
      
      await complaintRef.update(updateData);
      
      debugPrint('✅ Complaint assigned to: $staffName');
      
      return {
        'success': true,
        'message': 'Complaint assigned successfully',
      };
    } catch (e) {
      debugPrint('Error assigning complaint: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Rate complaint
  static Future<Map<String, dynamic>> rateComplaint({
    required String complaintId,
    required int rating,
    String? feedback,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'studentRating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (feedback != null && feedback.isNotEmpty) {
        updateData['studentFeedback'] = feedback;
      }
      
      await _firestore.collection('complaints').doc(complaintId).update(updateData);
      
      return {
        'success': true,
        'message': 'Thank you for your feedback!',
      };
    } catch (e) {
      debugPrint('Error rating complaint: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Get complaint statistics
  static Future<Map<String, dynamic>> getComplaintStats() async {
    try {
      final complaints = await _firestore.collection('complaints').get();
      
      int pending = 0;
      int assigned = 0;
      int resolved = 0;
      int rejected = 0;
      
      for (var doc in complaints.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString().toLowerCase() ?? 'pending';
        
        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'assigned':
            assigned++;
            break;
          case 'resolved':
            resolved++;
            break;
          case 'rejected':
            rejected++;
            break;
        }
      }
      
      return {
        'total': complaints.docs.length,
        'pending': pending,
        'assigned': assigned,
        'resolved': resolved,
        'rejected': rejected,
      };
    } catch (e) {
      debugPrint('Error getting complaint stats: $e');
      return {};
    }
  }

  // Add comment to complaint
  static Future<void> addComment({
    required String complaintId,
    required String comment,
    required String userId,
    required String userName,
  }) async {
    try {
      final complaintRef = _firestore.collection('complaints').doc(complaintId);
      
      final doc = await complaintRef.get();
      if (!doc.exists) return;
      
      final currentData = doc.data() as Map<String, dynamic>;
      final currentUpdates = List<Map<String, dynamic>>.from(currentData['updates'] ?? []);
      
      final commentEntry = {
        'status': 'comment',
        'comment': comment,
        'updatedBy': userName,
        'updatedAt': DateTime.now(), // DateTime.now() works here
      };
      
      currentUpdates.add(commentEntry);
      
      await complaintRef.update({
        'updates': currentUpdates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Comment added to complaint');
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  // Generate complaint number
  static Future<String> _generateComplaintNumber() async {
    try {
      final year = DateTime.now().year.toString().substring(2);
      final month = DateTime.now().month.toString().padLeft(2, '0');
      
      final startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
      
      final snapshot = await _firestore
          .collection('complaints')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();
      
      final count = snapshot.docs.length + 1;
      final sequence = count.toString().padLeft(3, '0');
      
      return 'CMP$year$month$sequence';
    } catch (e) {
      return 'CMP${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}