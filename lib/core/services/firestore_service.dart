import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Generic CRUD Operations
  static Future<String> createDocument({
    required String collection,
    required Map<String, dynamic> data,
    String? documentId,
  }) async {
    try {
      if (documentId != null) {
        await _firestore.collection(collection).doc(documentId).set(data);
        return documentId;
      } else {
        DocumentReference docRef = await _firestore.collection(collection).add(data);
        return docRef.id;
      }
    } catch (e) {
      debugPrint('Error creating document: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> readDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(collection).doc(documentId).get();
      if (doc.exists) {
        return {...doc.data() as Map<String, dynamic>, 'id': doc.id};
      }
      return null;
    } catch (e) {
      debugPrint('Error reading document: $e');
      return null;
    }
  }

  static Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(updates);
    } catch (e) {
      debugPrint('Error updating document: $e');
      rethrow;
    }
  }

  static Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }

  // Query with conditions
  static Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    String? field,
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic arrayContains,
    List<String?>? orderBy,
    bool descending = false,
    int? limit,
    String? startAfter,
  }) async {
    try {
      Query query = _firestore.collection(collection);

      if (field != null) {
        if (isEqualTo != null) query = query.where(field, isEqualTo: isEqualTo);
        if (isNotEqualTo != null) query = query.where(field, isNotEqualTo: isNotEqualTo);
        if (isLessThan != null) query = query.where(field, isLessThan: isLessThan);
        if (isLessThanOrEqualTo != null) {
          query = query.where(field, isLessThanOrEqualTo: isLessThanOrEqualTo);
        }
        if (isGreaterThan != null) {
          query = query.where(field, isGreaterThan: isGreaterThan);
        }
        if (isGreaterThanOrEqualTo != null) {
          query = query.where(field, isGreaterThanOrEqualTo: isGreaterThanOrEqualTo);
        }
        if (arrayContains != null) {
          query = query.where(field, arrayContains: arrayContains);
        }
      }

      if (orderBy != null) {
        for (String? field in orderBy) {
          if (field != null) {
            query = query.orderBy(field, descending: descending);
          }
        }
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      if (startAfter != null) {
        DocumentSnapshot lastDoc = await _firestore.collection(collection).doc(startAfter).get();
        query = query.startAfterDocument(lastDoc);
      }

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs.map((doc) => <String, dynamic>{...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList();
    } catch (e) {
      debugPrint('Error querying documents: $e');
      return [];
    }
  }

  // Real-time listener
  static Stream<List<Map<String, dynamic>>> streamCollection({
    required String collection,
    String? field,
    dynamic isEqualTo,
    int? limit,
  }) {
    Query query = _firestore.collection(collection);
    
    if (field != null && isEqualTo != null) {
      query = query.where(field, isEqualTo: isEqualTo);
    }
    
    if (limit != null) {
      query = query.limit(limit);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => <String, dynamic>{...doc.data() as Map<String, dynamic>, 'id': doc.id}).toList();
    });
  }

  // File upload to Storage
  static Future<String> uploadFile({
    required String path,
    required Uint8List fileBytes,
    String? fileName,
  }) async {
    try {
      String fullPath = fileName != null ? '$path/$fileName' : path;
      Reference ref = _storage.ref().child(fullPath);
      UploadTask uploadTask = ref.putData(fileBytes);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  // Batch write
  static Future<void> batchWrite(List<Map<String, dynamic>> operations) async {
    WriteBatch batch = _firestore.batch();
    
    for (var op in operations) {
      String type = op['type'];
      String collection = op['collection'];
      String docId = op['documentId'];
      Map<String, dynamic> data = op['data'] ?? {};
      
      DocumentReference docRef = _firestore.collection(collection).doc(docId);
      
      if (type == 'set') {
        batch.set(docRef, data);
      } else if (type == 'update') {
        batch.update(docRef, data);
      } else if (type == 'delete') {
        batch.delete(docRef);
      }
    }
    
    await batch.commit();
  }

  // Transaction
  static Future<T> runTransaction<T>(Future<T> Function(Transaction) transactionFunction) async {
    return await _firestore.runTransaction(transactionFunction);
  }
}