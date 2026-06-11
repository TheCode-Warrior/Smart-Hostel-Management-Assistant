import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/fee_provider.dart';
import '../../core/providers/student_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/fee_model.dart';
import '../../core/models/student_model.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class GenerateInvoiceScreen extends StatefulWidget {
  final String? studentId;

  const GenerateInvoiceScreen({Key? key, this.studentId}) : super(key: key);

  @override
  _GenerateInvoiceScreenState createState() => _GenerateInvoiceScreenState();
}

class _GenerateInvoiceScreenState extends State<GenerateInvoiceScreen> {
  StudentModel? _selectedStudent;
  List<FeeModel> _studentFees = [];
  String _selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  bool _isLoading = false;

  final List<String> _months = List.generate(12, (index) {
    DateTime date = DateTime.now().subtract(Duration(days: 30 * index));
    return DateFormat('MMMM yyyy').format(date);
  });

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    final feeProvider = Provider.of<FeeProvider>(context, listen: false);

    if (widget.studentId != null) {
      await studentProvider.loadStudentById(widget.studentId!);
      _selectedStudent = studentProvider.currentStudent;
      
      if (_selectedStudent != null) {
        await feeProvider.loadStudentFees(_selectedStudent!.id!);
        _studentFees = feeProvider.fees;
      }
    } else {
      await studentProvider.loadAllStudents();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _generateInvoice() async {
    if (_selectedStudent == null) return;

    final pdf = pw.Document();

    // Filter fees for selected month
    List<FeeModel> monthFees = _studentFees.where((fee) {
      String feeMonth = DateFormat('MMMM yyyy').format(fee.dueDate!.toDate());
      return feeMonth == _selectedMonth;
    }).toList();

    double totalAmount = monthFees.fold(0.0, (sum, fee) => sum + (fee.amount ?? 0));
    double totalPaid = monthFees.fold(0.0, (sum, fee) => sum + (fee.paidAmount ?? 0));
    double totalDue = totalAmount - totalPaid;

    // Add PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'HOSTEL MANAGEMENT SYSTEM',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text('123 University Road, City - 123456'),
                  pw.Text('Phone: +91 9876543210 | Email: hostel@college.edu'),
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue800),
                ),
                child: pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),

          // Invoice Details
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Invoice To:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('Name: ${_selectedStudent!.fullName}'),
                  pw.Text('Enrollment: ${_selectedStudent!.enrollmentNo}'),
                  pw.Text('Course: ${_selectedStudent!.course}'),
                  pw.Text('Semester: ${_selectedStudent!.semester}'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Invoice No: INV-${DateTime.now().millisecondsSinceEpoch}'),
                  pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
                  pw.Text('Period: $_selectedMonth'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Fee Table
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              // Header Row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Due Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Paid', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              // Data Rows
              ...monthFees.map((fee) {
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('${fee.feeType?.toUpperCase()} Fee'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(DateFormat('dd MMM yyyy').format(fee.dueDate!.toDate())),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('₹${(fee.amount ?? 0).toStringAsFixed(2)}'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('₹${(fee.paidAmount ?? 0).toStringAsFixed(2)}'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        fee.status?.toUpperCase() ?? '',
                        style: pw.TextStyle(
                          color: fee.status == 'paid' ? PdfColors.green : PdfColors.red,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
          pw.SizedBox(height: 20),

          // Summary
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 100,
                      child: pw.Text('Subtotal:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Text('₹${totalAmount.toStringAsFixed(2)}'),
                  ],
                ),
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 100,
                      child: pw.Text('Total Paid:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Text('₹${totalPaid.toStringAsFixed(2)}'),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 100,
                      child: pw.Text('Balance Due:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Text(
                      '₹${totalDue.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: totalDue > 0 ? PdfColors.red : PdfColors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),

          // Footer
          pw.SizedBox(height: 20),
          pw.Text(
            'This is a computer generated invoice. No signature is required.',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'For any queries regarding this invoice, please contact the hostel office.',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    // Preview PDF
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final studentProvider = Provider.of<StudentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Invoice'),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Selection (if not pre-selected)
                  if (widget.studentId == null) ...[
                    const Text(
                      'Select Student',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
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
                      child: DropdownButtonFormField<StudentModel>(
                        decoration: const InputDecoration(
                          labelText: 'Search Student',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        items: studentProvider.students.map((student) {
                          return DropdownMenuItem(
                            value: student,
                            child: Text('${student.fullName} (${student.enrollmentNo})'),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          setState(() {
                            _selectedStudent = value;
                          });
                          
                          if (value != null) {
                            final feeProvider = Provider.of<FeeProvider>(context, listen: false);
                            await feeProvider.loadStudentFees(value.id!);
                            setState(() {
                              _studentFees = feeProvider.fees;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (_selectedStudent != null) ...[
                    // Selected Student Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Student',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedStudent!.fullName ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enrollment: ${_selectedStudent!.enrollmentNo}',
                            style: TextStyle(color: Colors.white.withOpacity(0.9)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Course: ${_selectedStudent!.course} - Sem ${_selectedStudent!.semester}',
                            style: TextStyle(color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Month Selection
                    Container(
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
                            'Select Month',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _months.map((month) {
                              bool isSelected = _selectedMonth == month;
                              return FilterChip(
                                label: Text(month),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedMonth = selected ? month : _months.first;
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
                    ),
                    const SizedBox(height: 20),

                    // Invoice Preview
                    Container(
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
                            'Invoice Preview',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          
                          // Summary Table
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.grey100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                _buildPreviewRow('Month', _selectedMonth),
                                _buildPreviewRow('Total Fees', '₹${_studentFees.fold(0.0, (sum, fee) => sum + (fee.amount ?? 0)).toStringAsFixed(2)}'),
                                _buildPreviewRow('Total Paid', '₹${_studentFees.fold(0.0, (sum, fee) => sum + (fee.paidAmount ?? 0)).toStringAsFixed(2)}'),
                                _buildPreviewRow(
                                  'Balance Due',
                                  '₹${(_studentFees.fold(0.0, (sum, fee) => sum + (((fee.amount ?? 0) - (fee.paidAmount ?? 0))))).toStringAsFixed(2)}',
                                  highlight: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Generate Button
                    CustomButton(
                      text: 'Generate Invoice',
                      onPressed: _generateInvoice,
                      icon: Icons.picture_as_pdf,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? AppColors.primary : AppColors.grey700,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? AppColors.primary : null,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}