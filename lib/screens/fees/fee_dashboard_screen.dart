import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/fee_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/models/fee_model.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class FeeDashboardScreen extends StatefulWidget {
  const FeeDashboardScreen({Key? key}) : super(key: key);

  @override
  _FeeDashboardScreenState createState() => _FeeDashboardScreenState();
}

class _FeeDashboardScreenState extends State<FeeDashboardScreen> {
  String _selectedPeriod = 'This Month';
  final List<String> _periods = ['This Week', 'This Month', 'This Semester', 'This Year'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final feeProvider = Provider.of<FeeProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      if (authProvider.user!.roleString == 'Student') {
        await feeProvider.loadStudentFees(authProvider.user!.uid!);
      } else {
        await feeProvider.loadAllFees();
      }
    }
  }

  // ✅ Fixed: Period filter actually filters fees
  List<FeeModel> _filterFeesByPeriod(List<FeeModel> fees) {
    final now = DateTime.now();
    
    switch (_selectedPeriod) {
      case 'This Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return fees.where((fee) => 
          fee.createdAt != null && fee.createdAt!.toDate().isAfter(startOfWeek)
        ).toList();
        
      case 'This Month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return fees.where((fee) => 
          fee.createdAt != null && fee.createdAt!.toDate().isAfter(startOfMonth)
        ).toList();
        
      case 'This Semester':
        final isFirstSemester = now.month <= 6;
        final startOfSemester = isFirstSemester 
            ? DateTime(now.year, 1, 1)
            : DateTime(now.year, 7, 1);
        return fees.where((fee) => 
          fee.createdAt != null && fee.createdAt!.toDate().isAfter(startOfSemester)
        ).toList();
        
      case 'This Year':
        final startOfYear = DateTime(now.year, 1, 1);
        return fees.where((fee) => 
          fee.createdAt != null && fee.createdAt!.toDate().isAfter(startOfYear)
        ).toList();
        
      default:
        return fees;
    }
  }

  void _showAddFeeDialog() {
    final studentIdController = TextEditingController();
    final amountController = TextEditingController();
    String selectedFeeType = 'hostel';
    int selectedSemester = 1;
    DateTime? selectedDueDate;
    
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: MediaQuery.of(dialogContext).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dialog Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add New Fee',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Dialog Content
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Student Selection
                      Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('students')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }
                            final students = snapshot.data!.docs;
                            return DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Select Student',
                                border: OutlineInputBorder(),
                              ),
                              items: students.map((student) {
                                final data = student.data() as Map<String, dynamic>;
                                return DropdownMenuItem(
                                  value: student.id,
                                  child: Text(
                                    '${data['fullName']} (${data['enrollmentNo'] ?? 'N/A'})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                studentIdController.text = value ?? '';
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Fee Type Dropdown
                      Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: DropdownButtonFormField<String>(
                          value: selectedFeeType,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Fee Type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'hostel', child: Text('Hostel Fee (Once per Semester)')),
                            DropdownMenuItem(value: 'mess', child: Text('Mess Fee (Monthly)')),
                            DropdownMenuItem(value: 'caution', child: Text('Caution Deposit')),
                            DropdownMenuItem(value: 'fine', child: Text('Fine')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedFeeType = value ?? 'hostel';
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Semester Selection (for hostel fee)
                      if (selectedFeeType == 'hostel')
                        Container(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: DropdownButtonFormField<int>(
                            value: selectedSemester,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Semester',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(8, (i) => i + 1).map((sem) {
                              return DropdownMenuItem(
                                value: sem,
                                child: Text('Semester $sem'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedSemester = value ?? 1;
                              });
                            },
                          ),
                        ),
                      
                      // Month Selection (for mess fee)
                      if (selectedFeeType == 'mess')
                        Container(
                          constraints: const BoxConstraints(maxWidth: 380),
                          child: DropdownButtonFormField<String>(
                            value: selectedDueDate != null 
                                ? DateFormat('MMMM yyyy').format(selectedDueDate!)
                                : DateFormat('MMMM yyyy').format(DateTime.now()),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Month',
                              border: OutlineInputBorder(),
                            ),
                            items: List.generate(12, (i) {
                              final date = DateTime.now().subtract(Duration(days: 30 * i));
                              return DropdownMenuItem(
                                value: DateFormat('MMMM yyyy').format(date),
                                child: Text(DateFormat('MMMM yyyy').format(date)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedDueDate = DateFormat('MMMM yyyy').parse(value!);
                              });
                            },
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Amount Field
                      Container(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: TextField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                            border: OutlineInputBorder(),
                            prefixText: '₹ ',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Dialog Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (studentIdController.text.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('Please select a student'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            if (amountController.text.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('Please enter amount'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            
                            Navigator.pop(dialogContext);
                            
                            final feeProvider = Provider.of<FeeProvider>(parentContext, listen: false);
                            
                            final newFee = FeeModel(
                              studentId: studentIdController.text,
                              feeType: selectedFeeType,
                              amount: double.tryParse(amountController.text) ?? 0,
                              dueDate: Timestamp.fromDate(selectedDueDate ?? DateTime.now()),
                              semester: selectedFeeType == 'hostel' ? selectedSemester.toString() : null,
                              paidAmount: 0,
                              status: 'pending',
                              createdAt: Timestamp.now(),
                            );
                            
                            final success = await feeProvider.addFee(newFee);
                            
                            if (success && parentContext.mounted) {
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Fee added successfully'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              await _loadData();
                            } else if (parentContext.mounted) {
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${feeProvider.errorMessage}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Add Fee'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feeProvider = Provider.of<FeeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    final isStudent = authProvider.user?.roleString == 'Student';
    final isAdmin = authProvider.user?.roleString == 'Admin';
    final hasPendingFees = feeProvider.pendingFees.isNotEmpty;
    
    // ✅ Apply period filter
    final filteredFees = isAdmin ? _filterFeesByPeriod(feeProvider.fees) : feeProvider.fees;
    
    // ✅ Calculate category data for chart
    final categoryData = _getCategoryData(filteredFees);

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Fee Management'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // if (isAdmin)
          //   PopupMenuButton<String>(
          //     icon: const Icon(Icons.filter_list, color: Colors.white),
          //     onSelected: (value) {
          //       setState(() {
          //         _selectedPeriod = value;
          //       });
          //     },
          //     itemBuilder: (context) => _periods.map((period) {
          //       return PopupMenuItem(
          //         value: period,
          //         child: Text(period),
          //       );
          //     }).toList(),
          //   ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.feeHistory);
            },
          ),
        ],
      ),
      body: feeProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Info Card
                    _buildTopInfoCard(),
                    const SizedBox(height: 16),
                    
                    // Summary Cards
                    _buildSummaryCards(feeProvider, isAdmin, filteredFees),
                    const SizedBox(height: 20),
                    
                    if (isStudent && hasPendingFees) ...[
                      _buildPendingAlert(feeProvider.pendingFees),
                      const SizedBox(height: 20),
                    ],
                    
                    // Chart Section - Fee Distribution
                    _buildChartSection(categoryData),
                    const SizedBox(height: 20),
                    
                    // Recent Transactions
                    _buildRecentTransactions(filteredFees, isStudent),
                    const SizedBox(height: 20),
                    
                    // Quick Actions
                    _buildQuickActions(isStudent),
                  ],
                ),
              ),
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showAddFeeDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Fee'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  // ✅ Helper method to calculate category data
  Map<String, double> _getCategoryData(List<FeeModel> fees) {
    final Map<String, double> categoryAmounts = {};
    
    for (var fee in fees) {
      final feeType = fee.feeType ?? 'other';
      final amount = fee.amount ?? 0;
      categoryAmounts[feeType] = (categoryAmounts[feeType] ?? 0) + amount;
    }
    
    return categoryAmounts;
  }

  Widget _buildTopInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: const Icon(Icons.payment, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fee Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage fees, payments, and collections',
                    style: TextStyle(color: AppColors.grey600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(FeeProvider feeProvider, bool isAdmin, List<FeeModel> filteredFees) {
    final totalAmount = filteredFees.fold(0.0, (sum, fee) => sum + (fee.amount ?? 0));
    final totalPaid = filteredFees.fold(0.0, (sum, fee) => sum + (fee.paidAmount ?? 0));
    final totalDue = totalAmount - totalPaid;
    final pendingCount = filteredFees.where((f) => f.status == 'pending' || f.status == 'overdue').length;
    final collectionRate = totalAmount > 0 ? (totalPaid / totalAmount * 100) : 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Due',
                  '₹${totalDue.toStringAsFixed(2)}',
                  Icons.currency_rupee,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Total Paid',
                  '₹${totalPaid.toStringAsFixed(2)}',
                  Icons.currency_rupee,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Pending',
                  '$pendingCount',
                  Icons.pending,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Collection',
                  '${collectionRate.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingAlert(List<FeeModel> pendingFees) {
    final totalPending = pendingFees.fold(0.0, (sum, fee) => sum + fee.dueAmount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Fees Alert!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You have ${pendingFees.length} pending fee payment(s) totaling ₹${totalPending.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.red.shade700),
                ),
                const SizedBox(height: 8),
                CustomButton(
                  text: 'Pay Now',
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.feePayment);
                  },
                  isSmall: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Fixed: Fee Distribution Chart with proper data
  Widget _buildChartSection(Map<String, double> categoryData) {
    // Colors for different fee types
    final Map<String, Color> categoryColors = {
      'hostel': Colors.blue,
      'mess': Colors.green,
      'caution': Colors.orange,
      'electricity': Colors.purple,
      'fine': Colors.red,
      'other': AppColors.primary,
    };
    
    // Category display names
    final Map<String, String> categoryNames = {
      'hostel': 'Hostel Fee',
      'mess': 'Mess Fee',
      'caution': 'Caution Deposit',
      'electricity': 'Electricity Bill',
      'fine': 'Fine',
      'other': 'Other',
    };

    // Prepare chart sections
    final List<PieChartSectionData> sections = [];
    int index = 0;
    categoryData.forEach((category, amount) {
      if (amount > 0) {
        final color = categoryColors[category] ?? AppColors.primary;
        final name = categoryNames[category] ?? category;
        sections.add(
          PieChartSectionData(
            value: amount,
            title: '$name\n₹${amount.toStringAsFixed(0)}',
            color: color,
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
      index++;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fee Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Breakdown by fee type',
            style: TextStyle(color: AppColors.grey600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: sections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pie_chart, size: 48, color: AppColors.grey400),
                        const SizedBox(height: 12),
                        Text(
                          'No fee data available',
                          style: TextStyle(color: AppColors.grey600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add fees to see distribution chart',
                          style: TextStyle(color: AppColors.grey500, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      startDegreeOffset: -90,
                    ),
                  ),
          ),
          // Legend
          if (sections.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: categoryData.entries.map((entry) {
                final color = categoryColors[entry.key] ?? AppColors.primary;
                final name = categoryNames[entry.key] ?? entry.key;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₹${entry.value.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(List<FeeModel> fees, bool isStudent) {
    final recentFees = fees.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.feeHistory);
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          recentFees.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.receipt, size: 40, color: AppColors.grey400),
                        const SizedBox(height: 8),
                        Text(
                          'No transactions yet',
                          style: TextStyle(color: AppColors.grey600),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentFees.length,
                  itemBuilder: (context, index) {
                    final fee = recentFees[index];
                    return _buildTransactionTile(fee, isStudent);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(FeeModel fee, bool isStudent) {
    final isPaid = fee.status == 'paid';
    final statusColor = isPaid ? Colors.green : (fee.status == 'overdue' ? Colors.red : Colors.orange);
    
    String periodDisplay = '';
    if (fee.feeType == 'mess' && fee.dueDate != null) {
      periodDisplay = DateFormat('MMM yyyy').format(fee.dueDate!.toDate());
    } else if (fee.feeType == 'hostel' && fee.semester != null) {
      periodDisplay = 'Semester ${fee.semester}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () {
          if (!isPaid && isStudent) {
            Navigator.pushNamed(
              context,
              AppRoutes.feePayment,
              arguments: fee.id,
            );
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getFeeTypeColor(fee.feeType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getFeeTypeIcon(fee.feeType),
            color: _getFeeTypeColor(fee.feeType),
            size: 20,
          ),
        ),
        title: Text(
          '${fee.feeType?.toUpperCase()} Fee${periodDisplay.isNotEmpty ? ' ($periodDisplay)' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Due: ${DateFormat('dd MMM yyyy').format(fee.dueDate!.toDate())}',
              style: TextStyle(color: AppColors.grey600, fontSize: 12),
            ),
            if (fee.paidDate != null)
              Text(
                'Paid: ${DateFormat('dd MMM yyyy').format(fee.paidDate!.toDate())}',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${(fee.amount ?? 0).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fee.status?.toUpperCase() ?? '',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isStudent) {
    if (!isStudent) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Pay Fees',
                  Icons.currency_rupee,
                  AppColors.primary,
                  () => Navigator.pushNamed(context, AppRoutes.feePayment),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  'History',
                  Icons.history,
                  Colors.green,
                  () => Navigator.pushNamed(context, AppRoutes.feeHistory),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  'Structure',
                  Icons.receipt,
                  Colors.orange,
                  () => Navigator.pushNamed(context, AppRoutes.studentFeeStructure),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFeeTypeColor(String? feeType) {
    switch (feeType) {
      case 'hostel':
        return Colors.blue;
      case 'mess':
        return Colors.green;
      case 'caution':
        return Colors.orange;
      case 'electricity':
        return Colors.purple;
      case 'fine':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  IconData _getFeeTypeIcon(String? feeType) {
    switch (feeType) {
      case 'hostel':
        return Icons.apartment;
      case 'mess':
        return Icons.restaurant;
      case 'caution':
        return Icons.security;
      case 'electricity':
        return Icons.bolt;
      case 'fine':
        return Icons.warning;
      default:
        return Icons.receipt;
    }
  }
}