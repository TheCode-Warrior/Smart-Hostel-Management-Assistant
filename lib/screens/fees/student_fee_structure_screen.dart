import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';

class StudentFeeStructureScreen extends StatefulWidget {
  const StudentFeeStructureScreen({Key? key}) : super(key: key);

  @override
  State<StudentFeeStructureScreen> createState() => _StudentFeeStructureScreenState();
}

class _StudentFeeStructureScreenState extends State<StudentFeeStructureScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _settingsData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        throw Exception('Student account not found');
      }

      final studentDoc = await FirebaseFirestore.instance.collection('students').doc(userId).get();
      final settingsDoc = await FirebaseFirestore.instance.collection('hostelSettings').doc('settings').get();

      setState(() {
        _studentData = studentDoc.data();
        _settingsData = settingsDoc.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  double _readAmount(String key, double fallback) {
    final value = _settingsData?[key];
    if (value is num) return value.toDouble();
    return fallback;
  }

  bool _isMessActive() {
    return _studentData?['messMonthlyFeeSelected'] == true ||
        _studentData?['feePlan']?.toString() == 'messMonthly' ||
        _studentData?['feePlan']?.toString() == 'hostelSemester+messMonthly';
  }

  bool _isCurrentMonthPaid() {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final messMonthlyFees = _studentData?['messMonthlyFees'] is Map
        ? Map<String, bool>.from(_studentData!['messMonthlyFees'] as Map)
        : <String, bool>{};
    return messMonthlyFees[currentMonth] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final studentName = _studentData?['fullName']?.toString() ?? 'Student';
    final enrollment = _studentData?['enrollmentNo']?.toString() ?? 'N/A';
    final course = _studentData?['course']?.toString() ?? 'N/A';
    final semester = _studentData?['semester']?.toString() ?? 'N/A';
    final messMonthlySelected = _isMessActive();
    final isCurrentMonthPaid = _isCurrentMonthPaid();

    final hostelFee = _readAmount('hostelFeePerSemester', 15000);
    final messMonthlyFee = _readAmount('messFeePerMonth', 2000);

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('My Fee Structure'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load fee structure',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.grey700),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student Info Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fee Details',
                                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                studentName,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$course • Semester $semester',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enrollment: $enrollment',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatusCard(
                                'Mess Plan',
                                messMonthlySelected ? 'Active' : 'Not Active',
                                Icons.restaurant,
                                messMonthlySelected ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatusCard(
                                'Current Month',
                                isCurrentMonthPaid ? 'Paid' : 'Pending',
                                Icons.calendar_month,
                                isCurrentMonthPaid ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Fee Cards
                        _buildFeeCard(
                          'Hostel Semester Fee',
                          hostelFee,
                          'Semester hostel fee for the current academic cycle.',
                          Icons.apartment,
                        ),
                        const SizedBox(height: 12),
                        _buildFeeCard(
                          'Mess Monthly Fee',
                          messMonthlyFee,
                          'Monthly mess fee for meal access.',
                          Icons.restaurant,
                        ),
                        const SizedBox(height: 16),

                        // Info Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.info.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.info),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'To pay fees, go to the Fee Dashboard and submit a payment request. Admin will verify and mark it as paid.',
                                  style: TextStyle(color: AppColors.grey700, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Back Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Go Back'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: AppColors.grey600, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildFeeCard(String label, double amount, String description, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(description, style: TextStyle(color: AppColors.grey700, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}