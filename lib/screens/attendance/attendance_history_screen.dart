import 'package:flutter/material.dart';
import 'package:fyp_2026/core/models/attendance_model.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/attendance_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({Key? key}) : super(key: key);

  @override
  _AttendanceHistoryScreenState createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  late final DateTime _firstDay;
  late final DateTime _lastDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDay = DateTime.utc(now.year - 2, 1, 1);
    _lastDay = DateTime.utc(now.year + 2, 12, 31);
    _focusedDay = now.isBefore(_firstDay)
        ? _firstDay
        : now.isAfter(_lastDay)
            ? _lastDay
            : now;
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      await attendanceProvider.loadAttendanceHistory(
        authProvider.user!.uid!,
        days: 90,
      );
      _prepareEvents(attendanceProvider.attendanceHistory);
    }
  }

  void _prepareEvents(List<dynamic> history) {
    _events = {};
    for (var record in history) {
      final date = _normalizeDate(record.date.toDate());
      
      if (_events[date] == null) {
        _events[date] = [];
      }
      _events[date]!.add(record);
    }
    setState(() {});
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[_normalizeDate(day)] ?? [];
  }

  DateTime _normalizeDate(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);

    final calendarHeight = _calendarFormat == CalendarFormat.month ? 360.0 : 300.0;
    final totalRecords = attendanceProvider.attendanceHistory.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_month),
            onPressed: () {
              setState(() {
                _calendarFormat = _calendarFormat == CalendarFormat.month
                    ? CalendarFormat.week
                    : CalendarFormat.month;
              });
            },
          ),
        ],
      ),
      body: attendanceProvider.isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.history, color: Colors.white),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Attendance History',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Clean view of your recent attendance records',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '$totalRecords records',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        height: calendarHeight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.grey200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TableCalendar(
                            firstDay: _firstDay,
                            lastDay: _lastDay,
                            focusedDay: _focusedDay,
                            rowHeight: 36,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            calendarFormat: _calendarFormat,
                            eventLoader: _getEventsForDay,
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            },
                            onPageChanged: (focusedDay) {
                              if (focusedDay.isBefore(_firstDay)) {
                                _focusedDay = _firstDay;
                              } else if (focusedDay.isAfter(_lastDay)) {
                                _focusedDay = _lastDay;
                              } else {
                                _focusedDay = focusedDay;
                              }
                            },
                            calendarStyle: CalendarStyle(
                              todayDecoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.primary),
                              rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_selectedDay != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat('EEEE, dd MMMM yyyy').format(_selectedDay!),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getEventsForDay(_selectedDay!).isNotEmpty
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_getEventsForDay(_selectedDay!).length} records',
                                  style: TextStyle(
                                    color: _getEventsForDay(_selectedDay!).isNotEmpty
                                        ? Colors.green
                                        : AppColors.grey600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedDay != null
                            ? _getEventsForDay(_selectedDay!).length
                            : attendanceProvider.attendanceHistory.length,
                        itemBuilder: (context, index) {
                          final record = _selectedDay != null
                              ? _getEventsForDay(_selectedDay!)[index]
                              : attendanceProvider.attendanceHistory[index];

                          return _buildHistoryCard(record);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHistoryCard(dynamic record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.grey200),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(record.date.toDate()),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(record.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(record.status).toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(record.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Times
            Row(
              children: [
                Expanded(
                  child: _buildTimeChip(
                    'Check In',
                    record.checkInTime != null
                        ? DateFormat('hh:mm a').format(record.checkInTime.toDate())
                        : '--:--',
                    record.checkInTime != null ? Icons.login : Icons.block,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTimeChip(
                    'Check Out',
                    record.checkOutTime != null
                        ? DateFormat('hh:mm a').format(record.checkOutTime.toDate())
                        : '--:--',
                    record.checkOutTime != null ? Icons.logout : Icons.block,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Locations
            if (record.checkInLocation != null) ...[
              const Divider(),
              _buildLocationInfo(
                'Check In Location',
                record.checkInAddress ?? '${record.checkInLocation.latitude}, ${record.checkInLocation.longitude}',
                Icons.location_on,
              ),
            ],
            if (record.checkOutLocation != null) ...[
              const SizedBox(height: 8),
              _buildLocationInfo(
                'Check Out Location',
                record.checkOutAddress ?? '${record.checkOutLocation.latitude}, ${record.checkOutLocation.longitude}',
                Icons.location_off,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, String time, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.grey600),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.grey600,
                  fontSize: 10,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(String label, String location, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.grey600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.grey600,
                  fontSize: 10,
                ),
              ),
              Text(
                location,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusKey(dynamic status) {
    if (status is String) {
      return status.toLowerCase();
    }

    if (status is AttendanceStatus) {
      switch (status) {
        case AttendanceStatus.present:
          return 'present';
        case AttendanceStatus.absent:
          return 'absent';
        case AttendanceStatus.late:
          return 'late';
        case AttendanceStatus.halfDay:
          return 'half-day';
        case AttendanceStatus.holiday:
          return 'holiday';
      }
    }

    return 'unknown';
  }

  String _getStatusLabel(dynamic status) {
    switch (_statusKey(status)) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'late':
        return 'Late';
      case 'half-day':
        return 'Half Day';
      case 'holiday':
        return 'Holiday';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(dynamic status) {
    switch (_statusKey(status)) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'half-day':
        return Colors.blue;
      case 'holiday':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}