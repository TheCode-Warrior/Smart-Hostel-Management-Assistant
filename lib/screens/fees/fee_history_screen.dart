import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/fee_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/fee_model.dart';
import '../../routes/app_routes.dart';
import 'package:intl/intl.dart';

class FeeHistoryScreen extends StatefulWidget {
  const FeeHistoryScreen({Key? key}) : super(key: key);

  @override
  _FeeHistoryScreenState createState() => _FeeHistoryScreenState();
}

class _FeeHistoryScreenState extends State<FeeHistoryScreen> {
  String _selectedFilter = 'All';
  String _selectedYear = 'All';  // Default to 'All' to show all records
  final List<String> _filters = ['All', 'Paid', 'Pending', 'Overdue'];
  final List<String> _years = ['All', '2024', '2023', '2022', '2021'];

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

  List<FeeModel> _getFilteredFees() {
    final feeProvider = Provider.of<FeeProvider>(context, listen: false);
    
    return feeProvider.fees.where((fee) {
      // Apply status filter
      if (_selectedFilter != 'All') {
        if (_selectedFilter == 'Paid' && fee.status != 'paid') return false;
        if (_selectedFilter == 'Pending' && fee.status != 'pending') return false;
        if (_selectedFilter == 'Overdue' && fee.status != 'overdue') return false;
      }
      
      // Apply year filter
      if (_selectedYear != 'All') {
        final feeYear = DateFormat('yyyy').format(fee.dueDate!.toDate());
        if (feeYear != _selectedYear) return false;
      }
      
      return true;
    }).toList();
  }

  Map<String, List<FeeModel>> _groupFeesByMonth(List<FeeModel> fees) {
    final Map<String, List<FeeModel>> grouped = {};
    
    for (var fee in fees) {
      final monthYear = DateFormat('MMMM yyyy').format(fee.dueDate!.toDate());
      if (!grouped.containsKey(monthYear)) {
        grouped[monthYear] = [];
      }
      grouped[monthYear]!.add(fee);
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final feeProvider = Provider.of<FeeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    final isStudent = authProvider.user?.roleString == 'Student';
    final filteredFees = _getFilteredFees();
    final groupedFees = _groupFeesByMonth(filteredFees);
    
    // Calculate totals for summary
    final totalAmount = filteredFees.fold(0.0, (sum, fee) => sum + (fee.amount ?? 0));
    final totalPaid = filteredFees.fold(0.0, (sum, fee) => sum + (fee.paidAmount ?? 0));
    final totalDue = totalAmount - totalPaid;

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Fee History'),
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
          // Year Filter
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _selectedYear = value;
              });
            },
            itemBuilder: (context) => _years.map((year) {
              return PopupMenuItem(
                value: year,
                child: Text(year == 'All' ? 'All Years' : year),
              );
            }).toList(),
          ),
        ],
      ),
      body: feeProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Filter Chips
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFilter = selected ? filter : 'All';
                                });
                              },
                              backgroundColor: Colors.white,
                              selectedColor: _getFilterColor(filter).withOpacity(0.2),
                              checkmarkColor: _getFilterColor(filter),
                              labelStyle: TextStyle(
                                color: isSelected ? _getFilterColor(filter) : AppColors.grey700,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Summary Stats Card
                  Container(
                    margin: const EdgeInsets.all(16),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Total', '₹${totalAmount.toStringAsFixed(0)}', AppColors.primary),
                        _buildStatColumn('Paid', '₹${totalPaid.toStringAsFixed(0)}', Colors.green),
                        _buildStatColumn('Due', '₹${totalDue.toStringAsFixed(0)}', Colors.red),
                      ],
                    ),
                  ),

                  // History List
                  Expanded(
                    child: filteredFees.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: groupedFees.length,
                            itemBuilder: (context, index) {
                              final monthYear = groupedFees.keys.elementAt(index);
                              final monthFees = groupedFees[monthYear]!;
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Month Header
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          monthYear,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...monthFees.map((fee) => _buildHistoryCard(fee, isStudent)),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.grey600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(FeeModel fee, bool isStudent) {
    final isPaid = fee.status == 'paid';
    final statusColor = isPaid ? Colors.green : (fee.status == 'overdue' ? Colors.red : Colors.orange);
    
    // Get period display
    String periodDisplay = '';
    if (fee.feeType == 'mess' && fee.dueDate != null) {
      periodDisplay = DateFormat('MMM yyyy').format(fee.dueDate!.toDate());
    } else if (fee.feeType == 'hostel' && fee.semester != null) {
      periodDisplay = 'Semester ${fee.semester}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (!isPaid && isStudent) {
            Navigator.pushNamed(
              context,
              AppRoutes.feePayment,
              arguments: fee.id,
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getFeeTypeColor(fee.feeType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFeeTypeIcon(fee.feeType),
                      color: _getFeeTypeColor(fee.feeType),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${fee.feeType?.toUpperCase()} Fee${periodDisplay.isNotEmpty ? ' ($periodDisplay)' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Due: ${DateFormat('dd MMM yyyy').format(fee.dueDate!.toDate())}',
                          style: TextStyle(
                            color: AppColors.grey600,
                            fontSize: 12,
                          ),
                        ),
                        if (fee.paidDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Paid: ${DateFormat('dd MMM yyyy').format(fee.paidDate!.toDate())}',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${(fee.amount ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
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
                ],
              ),
              if ((fee.paidAmount ?? 0) > 0) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paid Amount:',
                      style: TextStyle(color: AppColors.grey600),
                    ),
                    Text(
                      '₹${(fee.paidAmount ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (fee.paymentMode != null && fee.paymentMode!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Mode:',
                        style: TextStyle(color: AppColors.grey600),
                      ),
                      Text(
                        fee.paymentMode!.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
                if (fee.transactionId != null && fee.transactionId!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaction ID:',
                        style: TextStyle(color: AppColors.grey600),
                      ),
                      Expanded(
                        child: Text(
                          fee.transactionId!,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
                if (fee.receiptNumber != null && fee.receiptNumber!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Receipt No:',
                        style: TextStyle(color: AppColors.grey600),
                      ),
                      GestureDetector(
                        onTap: () {
                          // View receipt functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Receipt view coming soon'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Text(
                          fee.receiptNumber!,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt,
            size: 80,
            color: AppColors.grey400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Fee Records Found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedYear != 'All'
                ? 'No fee records for $_selectedYear'
                : 'There are no fee transactions to display.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey600),
          ),
          const SizedBox(height: 16),
          if (_selectedYear != 'All')
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedYear = 'All';
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Year Filter'),
            ),
        ],
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'Paid':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Overdue':
        return Colors.red;
      default:
        return AppColors.primary;
    }
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