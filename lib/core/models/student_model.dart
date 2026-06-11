import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  String? id;
  String? userId;
  String? fullName;
  String? email;
  String? phoneNumber;
  String? profileImage;
  String? enrollmentNo;
  String? course;
  int? semester;
  String? batch;
  String? parentName;
  String? parentPhone;
  String? parentEmail;
  String? address;
  String? city;
  String? state;
  String? pincode;
  String? bloodGroup;
  String? emergencyContact;
  String? medicalConditions;
  Map<String, String>? documents;
  bool? isVerified;
  String? verifiedBy;
  Timestamp? verifiedAt;
  String? roomId;
  String? roomNumber;
  bool? messFeePaid;
  Timestamp? messFeePaidUntil;
  double? fineAmount;
  Map<String, bool>? messMonthlyFees;
  bool? hostelSemesterFeeSelected;
  bool? messMonthlyFeeSelected;
  String? feePlan;

  StudentModel({
    this.id,
    this.userId,
    this.fullName,
    this.email,
    this.phoneNumber,
    this.profileImage,
    this.enrollmentNo,
    this.course,
    this.semester,
    this.batch,
    this.parentName,
    this.parentPhone,
    this.parentEmail,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.bloodGroup,
    this.emergencyContact,
    this.medicalConditions,
    this.documents,
    this.isVerified = false, // ✅ Default to false
    this.verifiedBy,
    this.verifiedAt,
    this.roomId,
    this.roomNumber,
    this.messFeePaid,
    this.messFeePaidUntil,
    this.fineAmount,
    this.messMonthlyFees,
    this.hostelSemesterFeeSelected,
    this.messMonthlyFeeSelected,
    this.feePlan,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
      'enrollmentNo': enrollmentNo,
      'course': course,
      'semester': semester,
      'batch': batch,
      'parentName': parentName,
      'parentPhone': parentPhone,
      'parentEmail': parentEmail,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'bloodGroup': bloodGroup,
      'emergencyContact': emergencyContact,
      'medicalConditions': medicalConditions,
      'documents': documents,
      'isVerified': isVerified ?? false,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt,
      'roomId': roomId,
      'roomNumber': roomNumber,
      'messFeePaid': messFeePaid ?? false,
      'messFeePaidUntil': messFeePaidUntil,
      'fineAmount': fineAmount ?? 0,
      'messMonthlyFees': messMonthlyFees ?? {},
      'hostelSemesterFeeSelected': hostelSemesterFeeSelected ?? _derivedHostelSemesterSelected,
      'messMonthlyFeeSelected': messMonthlyFeeSelected ?? _derivedMessMonthlySelected,
      'feePlan': feePlan ?? _derivedFeePlan,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map, String id) {
    return StudentModel(
      id: id,
      userId: map['userId'],
      fullName: map['fullName'],
      email: map['email'],
      phoneNumber: map['phoneNumber'],
      profileImage: map['profileImage'],
      enrollmentNo: map['enrollmentNo'],
      course: map['course'],
      semester: map['semester'],
      batch: map['batch'],
      parentName: map['parentName'],
      parentPhone: map['parentPhone'],
      parentEmail: map['parentEmail'],
      address: map['address'],
      city: map['city'],
      state: map['state'],
      pincode: map['pincode'],
      bloodGroup: map['bloodGroup'],
      emergencyContact: map['emergencyContact'],
      medicalConditions: map['medicalConditions'],
      documents: Map<String, String>.from(map['documents'] ?? {}),
      isVerified: map['isVerified'] ?? false,
      verifiedBy: map['verifiedBy'],
      verifiedAt: map['verifiedAt'],
      roomId: map['roomId'],
      roomNumber: map['roomNumber'],
      messFeePaid: map['messFeePaid'],
      messFeePaidUntil: map['messFeePaidUntil'],
      fineAmount: (map['fineAmount'] ?? 0).toDouble(),
      messMonthlyFees: Map<String, bool>.from(map['messMonthlyFees'] ?? {}),
      hostelSemesterFeeSelected: map['hostelSemesterFeeSelected'] ?? _legacyHostelSemesterSelected(map['feePlan']),
      messMonthlyFeeSelected: map['messMonthlyFeeSelected'] ?? _legacyMessMonthlySelected(map['feePlan']),
      feePlan: map['feePlan'] ?? _deriveFeePlanFromFlags(
        map['hostelSemesterFeeSelected'] == true,
        map['messMonthlyFeeSelected'] == true,
      ),
    );
  }

  String get fullAddress {
    return '$address, $city, $state - $pincode';
  }

  bool get isMessFeeValid {
    if (messFeePaidUntil == null) return false;
    return messFeePaidUntil!.toDate().isAfter(DateTime.now());
  }

  bool get _derivedHostelSemesterSelected {
    return hostelSemesterFeeSelected ?? _legacyHostelSemesterSelected(feePlan) ?? true;
  }

  bool get _derivedMessMonthlySelected {
    return messMonthlyFeeSelected ?? _legacyMessMonthlySelected(feePlan) ?? false;
  }

  String get _derivedFeePlan {
    return _deriveFeePlanFromFlags(_derivedHostelSemesterSelected, _derivedMessMonthlySelected);
  }

  static bool? _legacyHostelSemesterSelected(dynamic feePlan) {
    final plan = feePlan?.toString();
    if (plan == null || plan.isEmpty) return null;
    return plan == 'hostelSemester' || plan == 'hostelSemester+messMonthly';
  }

  static bool? _legacyMessMonthlySelected(dynamic feePlan) {
    final plan = feePlan?.toString();
    if (plan == null || plan.isEmpty) return null;
    return plan == 'messMonthly' || plan == 'hostelSemester+messMonthly';
  }

  static String _deriveFeePlanFromFlags(bool hostelSemesterSelected, bool messMonthlySelected) {
    if (hostelSemesterSelected && messMonthlySelected) {
      return 'hostelSemester+messMonthly';
    }
    if (hostelSemesterSelected) {
      return 'hostelSemester';
    }
    if (messMonthlySelected) {
      return 'messMonthly';
    }
    return 'none';
  }
}