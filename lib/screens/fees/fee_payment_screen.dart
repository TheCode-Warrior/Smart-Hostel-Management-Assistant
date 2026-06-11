import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/fee_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/fee_model.dart';
import '../../core/services/fee_request_service.dart';
import 'package:intl/intl.dart';

class FeePaymentScreen extends StatefulWidget {
  final String? feeId;

  const FeePaymentScreen({Key? key, this.feeId}) : super(key: key);

  @override
  _FeePaymentScreenState createState() => _FeePaymentScreenState();
}

class _FeePaymentScreenState extends State<FeePaymentScreen> {
  FeeModel? _selectedFee;
  String _selectedPaymentMethod = 'Cash';
  double _paymentAmount = 0;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _paymentMethods = ['Cash', 'Bank Transfer', 'Cheque', 'Online Transfer'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final feeProvider = Provider.of<FeeProvider>(context, listen: false);

    if (widget.feeId != null) {
      await feeProvider.loadFeeById(widget.feeId!);
      setState(() {
        _selectedFee = feeProvider.currentFee;
        if (_selectedFee != null) {
          _paymentAmount = _selectedFee!.dueAmount;
        }
      });
    } else {
      await feeProvider.loadStudentFees(authProvider.user!.uid!);
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedFee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a fee to pay'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_paymentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final result = await FeeRequestService.requestPayment(
      feeId: _selectedFee!.id!,
      studentId: authProvider.user!.uid!,
      studentName: authProvider.user!.fullName!,
      amount: _paymentAmount,
      paymentMethod: _selectedPaymentMethod,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
    );

    setState(() => _isSubmitting = false);

    if (result['success'] == true && mounted) {
      _showRequestSubmittedDialog();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRequestSubmittedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Icon(Icons.request_page, color: Colors.orange, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Request Submitted!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        content: const Text(
          'Your payment request has been submitted to the admin.\n\nYou will receive a notification once it is approved.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feeProvider = Provider.of<FeeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Payment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: feeProvider.isLoading
          ? const LoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fee Selection (if no specific fee selected)
                  if (widget.feeId == null) ...[
                    const Text(
                      'Select Fee to Pay',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...feeProvider.pendingFees.map((fee) => _buildFeeSelectionCard(fee)),
                    const SizedBox(height: 20),
                  ],

                  // Selected Fee Details
                  if (_selectedFee != null) ...[
                    _buildSelectedFeeCard(),
                    const SizedBox(height: 20),

                    // Payment Method Selection
                    _buildPaymentMethodSection(),
                    const SizedBox(height: 20),

                    // Note Section
                    _buildNoteSection(),
                    const SizedBox(height: 20),

                    // Summary
                    _buildPaymentSummary(),
                    const SizedBox(height: 30),

                    // Submit Request Button
                    CustomButton(
                      text: 'Submit Payment Request',
                      onPressed: _submitRequest,
                      isLoading: _isSubmitting,
                      icon: Icons.send,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFeeSelectionCard(FeeModel fee) {
    double dueAmount = fee.dueAmount;
    bool isOverdue = fee.status == 'overdue';
    bool hasPendingRequest = fee.hasPendingRequest;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Radio<FeeModel>(
          value: fee,
          groupValue: _selectedFee,
          onChanged: hasPendingRequest ? null : (value) {
            setState(() {
              _selectedFee = value;
              _paymentAmount = dueAmount;
            });
          },
        ),
        title: Text(
          '${fee.feeType?.toUpperCase()} Fee',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: hasPendingRequest ? AppColors.grey500 : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Due Date: ${fee.formattedDueDate}'),
            if (isOverdue)
              const Text(
                'OVERDUE',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            if (hasPendingRequest)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Request Pending',
                  style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${fee.amount?.toStringAsFixed(2) ?? '0'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Due: ₹${dueAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? Colors.red : AppColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFeeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Fee',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFeeTypeIcon(_selectedFee!.feeType),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedFee!.feeType?.toUpperCase()} Fee',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Due: ${_selectedFee!.formattedDueDate}',
                      style: TextStyle(color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white30),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '₹${_selectedFee!.amount?.toStringAsFixed(2) ?? '0'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if ((_selectedFee!.paidAmount ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Already Paid',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  '₹${_selectedFee!.paidAmount?.toStringAsFixed(2) ?? '0'}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Submit request to admin. Admin will verify and mark as paid.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'Payment Method',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paymentMethods.map((method) {
              bool isSelected = _selectedPaymentMethod == method;
              return FilterChip(
                label: Text(method),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedPaymentMethod = selected ? method : 'Cash';
                  });
                },
                backgroundColor: Colors.white,
                selectedColor: AppColors.primary.withOpacity(0.1),
                checkmarkColor: AppColors.primary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            'Additional Note (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'e.g., Paid via bank transfer, transaction ID: xxx',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: AppColors.grey100,
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Amount to Pay'),
              Text(
                '₹${_paymentAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total to Pay',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${_paymentAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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