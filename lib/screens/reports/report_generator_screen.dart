import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/student_provider.dart';
import '../../core/providers/room_provider.dart';
import '../../core/providers/fee_provider.dart';
import '../../core/providers/complaint_provider.dart';
import '../../core/providers/attendance_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportGeneratorScreen extends StatefulWidget {
  const ReportGeneratorScreen({Key? key}) : super(key: key);

  @override
  _ReportGeneratorScreenState createState() => _ReportGeneratorScreenState();
}

class _ReportGeneratorScreenState extends State<ReportGeneratorScreen> {
  String _selectedReportType = 'Students';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedFormat = 'PDF';
  bool _includeCharts = true;
  bool _includeSummary = true;
  bool _includeDetails = true;
  bool _isGenerating = false;
  
  Map<String, dynamic> _reportData = {};
  String? _errorMessage;

  final List<String> _reportTypes = [
    'Students',
    'Rooms',
    'Fees',
    'Attendance',
    'Complaints',
  ];

  final List<String> _formats = ['PDF', 'Excel', 'CSV'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Report', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _errorMessage = null);
        },
        color: Colors.white,
        backgroundColor: AppColors.primary,
        child: _isGenerating
            ? const LoadingIndicator()
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCard(
                      title: 'Report Type',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _reportTypes.map((type) {
                          bool isSelected = _selectedReportType == type;
                          return FilterChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedReportType = selected ? type : 'Students';
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.primary.withOpacity(0.2),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.grey700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildCard(
                      title: 'Date Range',
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDateField('Start Date', _startDate, () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() {
                                  _startDate = date;
                                  if (_startDate.isAfter(_endDate)) _endDate = _startDate;
                                });
                              }
                            }),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField('End Date', _endDate, () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now(),
                              );
                              if (date != null) setState(() => _endDate = date);
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildCard(
                      title: 'Export Format',
                      child: Row(
                        children: _formats.map((format) {
                          bool isSelected = _selectedFormat == format;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(format),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() => _selectedFormat = selected ? format : 'PDF');
                                },
                                backgroundColor: Colors.white,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.grey700,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildCard(
                      title: 'Report Options',
                      child: Column(
                        children: [
                          CheckboxListTile(
                            title: const Text('Include Summary'),
                            value: _includeSummary,
                            onChanged: (value) => setState(() => _includeSummary = value ?? true),
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),
                          CheckboxListTile(
                            title: const Text('Include Charts'),
                            value: _includeCharts,
                            onChanged: (value) => setState(() => _includeCharts = value ?? true),
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),
                          CheckboxListTile(
                            title: const Text('Include Detailed Data'),
                            value: _includeDetails,
                            onChanged: (value) => setState(() => _includeDetails = value ?? true),
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                            GestureDetector(
                              onTap: () => setState(() => _errorMessage = null),
                              child: const Icon(Icons.close, size: 16, color: Colors.red),
                            ),
                          ],
                        ),
                      ),

                    CustomButton(
                      text: 'Preview Report',
                      onPressed: _previewReport,
                      icon: Icons.preview,
                      isLoading: _isGenerating,
                    ),
                    const SizedBox(height: 12),
                    
                    CustomButton(
                      text: 'Generate & Share',
                      onPressed: _generateAndShare,
                      icon: Icons.share,
                      isLoading: _isGenerating,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: AppColors.grey300), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppColors.grey600, fontSize: 12)),
            const SizedBox(height: 4),
            Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchRealData() async {
    final firestore = FirebaseFirestore.instance;
    
    switch (_selectedReportType) {
      case 'Students':
        final students = await firestore.collection('students').get();
        _reportData = {
          'type': 'Students',
          'total': students.docs.length,
          'data': students.docs.map((doc) => doc.data()).toList(),
        };
        break;
        
      case 'Rooms':
        final rooms = await firestore.collection('rooms').get();
        int occupied = 0;
        for (var doc in rooms.docs) {
          if (doc.data()['isOccupied'] == true) occupied++;
        }
        _reportData = {
          'type': 'Rooms',
          'total': rooms.docs.length,
          'occupied': occupied,
          'available': rooms.docs.length - occupied,
          'data': rooms.docs.map((doc) => doc.data()).toList(),
        };
        break;
        
      case 'Fees':
        final fees = await firestore.collection('fees').get();
        double totalAmount = 0, totalPaid = 0;
        int paid = 0, pending = 0;
        for (var doc in fees.docs) {
          final data = doc.data();
          final amount = (data['amount'] ?? 0.0).toDouble();
          final paidAmount = (data['paidAmount'] ?? 0.0).toDouble();
          totalAmount += amount;
          totalPaid += paidAmount;
          if (data['status'] == 'paid') paid++;
          else pending++;
        }
        _reportData = {
          'type': 'Fees',
          'total': fees.docs.length,
          'totalAmount': totalAmount,
          'totalPaid': totalPaid,
          'pendingAmount': totalAmount - totalPaid,
          'paid': paid,
          'pending': pending,
          'data': fees.docs.map((doc) => doc.data()).toList(),
        };
        break;
        
      case 'Attendance':
        final startTimestamp = Timestamp.fromDate(_startDate);
        final endTimestamp = Timestamp.fromDate(_endDate);
        final attendance = await firestore
            .collection('attendance')
            .where('date', isGreaterThanOrEqualTo: startTimestamp)
            .where('date', isLessThanOrEqualTo: endTimestamp)
            .get();
        int present = 0, absent = 0, late = 0;
        for (var doc in attendance.docs) {
          final status = doc.data()['status']?.toString().toLowerCase() ?? 'absent';
          if (status == 'present') present++;
          else if (status == 'late') late++;
          else if (status == 'absent') absent++;
        }
        _reportData = {
          'type': 'Attendance',
          'total': attendance.docs.length,
          'present': present,
          'absent': absent,
          'late': late,
          'attendancePercentage': attendance.docs.isEmpty ? 0 : ((present + late) / attendance.docs.length) * 100,
          'data': attendance.docs.map((doc) => doc.data()).toList(),
        };
        break;
        
      case 'Complaints':
        final complaints = await firestore.collection('complaints').get();
        int pending = 0, assigned = 0, resolved = 0, rejected = 0;
        for (var doc in complaints.docs) {
          final status = doc.data()['status']?.toString().toLowerCase() ?? 'pending';
          if (status == 'pending') pending++;
          else if (status == 'assigned') assigned++;
          else if (status == 'resolved') resolved++;
          else if (status == 'rejected') rejected++;
        }
        _reportData = {
          'type': 'Complaints',
          'total': complaints.docs.length,
          'pending': pending,
          'assigned': assigned,
          'resolved': resolved,
          'rejected': rejected,
          'data': complaints.docs.map((doc) => doc.data()).toList(),
        };
        break;
    }
  }

  Future<void> _previewReport() async {
    setState(() { _isGenerating = true; _errorMessage = null; });
    try {
      await _fetchRealData();
      final pdf = await _generatePdf();
      setState(() => _isGenerating = false);
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      setState(() { _isGenerating = false; _errorMessage = 'Failed to generate preview: $e'; });
    }
  }

  Future<void> _generateAndShare() async {
    setState(() { _isGenerating = true; _errorMessage = null; });
    try {
      await _fetchRealData();
      if (_selectedFormat == 'PDF') {
        final pdf = await _generatePdf();
        final bytes = await pdf.save();
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: '${_selectedReportType} Report');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report ready to share!'), backgroundColor: Colors.green));
      } else {
        final csvContent = _generateCSV();
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/report_${DateTime.now().millisecondsSinceEpoch}.csv');
        await file.writeAsString(csvContent);
        await Share.shareXFiles([XFile(file.path)], text: '${_selectedReportType} Report');
      }
      setState(() => _isGenerating = false);
    } catch (e) {
      setState(() { _isGenerating = false; _errorMessage = 'Failed to generate report: $e'; });
    }
  }

  String _generateCSV() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('${_selectedReportType} Report');
    buffer.writeln('Generated: ${DateFormat('dd MMM yyyy HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('Period: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}');
    buffer.writeln('');
    buffer.writeln('SUMMARY');
    buffer.writeln('Total Records,${_reportData['total'] ?? 0}');
    
    switch (_selectedReportType) {
      case 'Rooms':
        buffer.writeln('Occupied Rooms,${_reportData['occupied'] ?? 0}');
        buffer.writeln('Available Rooms,${_reportData['available'] ?? 0}');
        break;
      case 'Fees':
        buffer.writeln('Total Amount,${_reportData['totalAmount'] ?? 0}');
        buffer.writeln('Total Paid,${_reportData['totalPaid'] ?? 0}');
        buffer.writeln('Pending Amount,${_reportData['pendingAmount'] ?? 0}');
        break;
      case 'Attendance':
        buffer.writeln('Present Days,${_reportData['present'] ?? 0}');
        buffer.writeln('Absent Days,${_reportData['absent'] ?? 0}');
        buffer.writeln('Late Days,${_reportData['late'] ?? 0}');
        buffer.writeln('Attendance Percentage,${(_reportData['attendancePercentage'] ?? 0).toStringAsFixed(1)}%');
        break;
      case 'Complaints':
        buffer.writeln('Pending,${_reportData['pending'] ?? 0}');
        buffer.writeln('Assigned,${_reportData['assigned'] ?? 0}');
        buffer.writeln('Resolved,${_reportData['resolved'] ?? 0}');
        buffer.writeln('Rejected,${_reportData['rejected'] ?? 0}');
        break;
    }
    
    buffer.writeln('');
    buffer.writeln('DETAILED DATA');
    if (_includeDetails && _reportData['data'] != null && _reportData['data'].isNotEmpty) {
      final firstItem = _reportData['data'][0];
      buffer.writeln(firstItem.keys.join(','));
      for (var item in _reportData['data']) {
        buffer.writeln(item.values.map((v) => v?.toString() ?? '').join(','));
      }
    }
    return buffer.toString();
  }

  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildPdfHeader(),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),
              
              // Summary
              if (_includeSummary) ...[
                _buildPdfSummary(),
                pw.SizedBox(height: 20),
              ],
              
              // Charts
              if (_includeCharts && _getSummaryItems().length > 1) ...[
                _buildPdfChart(),
                pw.SizedBox(height: 20),
              ],
              
              // Details
              if (_includeDetails) _buildPdfDetails(),
            ],
          );
        },
      ),
    );
    
    return pdf;
  }

  pw.Widget _buildPdfHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('HOSTEL MANAGEMENT SYSTEM', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.Text('$_selectedReportType Report', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Period: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}'),
            pw.Text('Generated: ${DateFormat('dd MMM yyyy HH:mm:ss').format(DateTime.now())}'),
            pw.Text('Total Records: ${_reportData['total'] ?? 0}'),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue800)),
          child: pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  pw.Widget _buildPdfSummary() {
    final items = _getSummaryItems();
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Summary', style:  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 20,
            runSpacing: 10,
            children: items.map((item) => _buildSummaryItem(item['label']!, item['value']!)).toList(),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  List<Map<String, String>> _getSummaryItems() {
    switch (_selectedReportType) {
      case 'Students': return [{'label': 'Total Students', 'value': '${_reportData['total'] ?? 0}'}];
      case 'Rooms': return [
        {'label': 'Total Rooms', 'value': '${_reportData['total'] ?? 0}'},
        {'label': 'Occupied', 'value': '${_reportData['occupied'] ?? 0}'},
        {'label': 'Available', 'value': '${_reportData['available'] ?? 0}'},
      ];
      case 'Fees': return [
        {'label': 'Total Amount', 'value': '₹${(_reportData['totalAmount'] ?? 0).toStringAsFixed(2)}'},
        {'label': 'Collected', 'value': '₹${(_reportData['totalPaid'] ?? 0).toStringAsFixed(2)}'},
        {'label': 'Pending', 'value': '₹${(_reportData['pendingAmount'] ?? 0).toStringAsFixed(2)}'},
      ];
      case 'Attendance': return [
        {'label': 'Present', 'value': '${_reportData['present'] ?? 0}'},
        {'label': 'Late', 'value': '${_reportData['late'] ?? 0}'},
        {'label': 'Absent', 'value': '${_reportData['absent'] ?? 0}'},
        {'label': 'Percentage', 'value': '${(_reportData['attendancePercentage'] ?? 0).toStringAsFixed(1)}%'},
      ];
      case 'Complaints': return [
        {'label': 'Pending', 'value': '${_reportData['pending'] ?? 0}'},
        {'label': 'Assigned', 'value': '${_reportData['assigned'] ?? 0}'},
        {'label': 'Resolved', 'value': '${_reportData['resolved'] ?? 0}'},
        {'label': 'Rejected', 'value': '${_reportData['rejected'] ?? 0}'},
      ];
      default: return [{'label': 'Total', 'value': '${_reportData['total'] ?? 0}'}];
    }
  }

  pw.Widget _buildPdfChart() {
    final items = _getSummaryItems();
    final numericItems = items.where((item) {
      final val = item['value']!.replaceAll('₹', '').replaceAll('%', '');
      return double.tryParse(val) != null;
    }).toList();
    
    if (numericItems.isEmpty) return pw.SizedBox();
    
    final maxValue = numericItems.map((item) => double.parse(item['value']!.replaceAll('₹', '').replaceAll('%', ''))).reduce((a, b) => a > b ? a : b);
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Statistics Chart', style:  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          ...numericItems.map((item) {
            final value = double.parse(item['value']!.replaceAll('₹', '').replaceAll('%', ''));
            final percentage = maxValue > 0 ? (value / maxValue) : 0;
            return pw.Column(
              children: [
                pw.Row(
                  children: [
                    pw.SizedBox(width: 100, child: pw.Text(item['label']!)),
                    pw.Expanded(
                      child: pw.Container(
                        height: 25,
                        child: pw.Stack(
                          children: [
                            pw.Container(
                              width: double.infinity,
                              height: 25,
                              decoration: pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.circular(4)),
                            ),
                            pw.Container(
                              width: (400 * percentage).toDouble(),
                              height: 25,
                              decoration: pw.BoxDecoration(
                                color: PdfColors.blue400,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Center(
                                child: pw.Text(
                                  item['value']!,
                                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  pw.Widget _buildPdfDetails() {
    if (_reportData['data'] == null || _reportData['data'].isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        child: pw.Text('No detailed data available for the selected period.'),
      );
    }
    
    final data = _reportData['data'] as List;
    final headers = data.first.keys.take(6).toList(); // Limit to 6 columns for PDF
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Detailed Data', style:  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: headers.map((h) => h.toString()).toList(),
            data: data
              .take(15)
              .map<List<dynamic>>((item) => headers.map((h) => item[h]?.toString() ?? '').toList())
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(6),
        ),
        if (data.length > 15)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text('Showing first 15 of ${data.length} records', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ),
      ],
    );
  }
}