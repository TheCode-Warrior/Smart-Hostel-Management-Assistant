import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/fee_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/fee_request_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/fee_model.dart';

class StudentRequestFeeScreen extends StatefulWidget {
  final FeeModel fee;

  const StudentRequestFeeScreen({Key? key, required this.fee}) : super(key: key);

  @override
  State<StudentRequestFeeScreen> createState() => _StudentRequestFeeScreenState();
}

class _StudentRequestFeeScreenState extends State<StudentRequestFeeScreen> {
  String _selectedPaymentMethod = 'Cash';
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _paymentMethods = ['Cash', 'Bank Transfer', 'Cheque', 'Online Transfer'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dueAmount = widget.fee.dueAmount;

    final result = await FeeRequestService.requestPayment(
      feeId: widget.fee.id!,
      studentId: authProvider.user!.uid!,
      studentName: authProvider.user!.fullName!,
      amount: dueAmount,
      paymentMethod: _selectedPaymentMethod,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
    );

    setState(() => _isSubmitting = false);

    if (result['success'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment request submitted! Admin will review it.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueAmount = widget.fee.dueAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Payment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fee Details Card
            Container(
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
                  _buildDetailRow('Fee Type', '${widget.fee.feeType?.toUpperCase()} Fee'),
                  const Divider(),
                  _buildDetailRow('Amount Due', '₹${dueAmount.toStringAsFixed(2)}', isHighlight: true),
                  const Divider(),
                  _buildDetailRow('Due Date', widget.fee.formattedDueDate),
                  if (widget.fee.isOverdue)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 16),
                            SizedBox(width: 8),
                            Text('This fee is overdue!', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment Method Selection
            const Text(
              'Select Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paymentMethods.map((method) {
                return FilterChip(
                  label: Text(method),
                  selected: _selectedPaymentMethod == method,
                  onSelected: (selected) {
                    setState(() {
                      _selectedPaymentMethod = selected ? method : 'Cash';
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Optional Note
            const Text(
              'Additional Note (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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

            const SizedBox(height: 24),

            // Info Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After submitting this request, admin will verify your payment and mark it as paid. You will receive a notification once approved.',
                      style: TextStyle(color: AppColors.grey700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            CustomButton(
              text: 'Submit Payment Request',
              onPressed: _submitRequest,
              isLoading: _isSubmitting,
              icon: Icons.send,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.grey600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlight ? 18 : 14,
              color: isHighlight ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}