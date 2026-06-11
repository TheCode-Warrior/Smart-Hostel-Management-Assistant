import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/attendance_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/attendance_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../routes/app_routes.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({Key? key}) : super(key: key);

  @override
  _MarkAttendanceScreenState createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  bool _isLoading = false;
  Position? _currentPosition;
  String? _address;
  bool _isWithinGeofence = false;
  double _distanceFromHostel = 0;
  Map<String, dynamic>? _todayAttendance;
  Map<String, dynamic>? _hostelLocation;
  String? _hostelAddress;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get hostel location first
      _hostelLocation = await AttendanceService.getHostelLocation();
      
      // Get hostel address from coordinates
      if (_hostelLocation != null && _hostelLocation!['latitude'] != 0.0) {
        _hostelAddress = await _getAddressFromCoordinates(
          _hostelLocation!['latitude'],
          _hostelLocation!['longitude'],
        );
      }
      
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorDialog('Location services are disabled. Please enable location.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorDialog('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorDialog('Location permissions are permanently denied');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      bool withinGeofence = await AttendanceService.isWithinGeofence(position);
      double distance = await AttendanceService.getDistanceFromHostel(position);

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          _address = '${place.name}, ${place.locality}, ${place.administrativeArea}';
        }
        _isWithinGeofence = withinGeofence;
        _distanceFromHostel = distance;
      });

      // Load today's attendance
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      
      if (authProvider.user != null) {
        await attendanceProvider.loadTodayAttendance(authProvider.user!.uid!);
        if (!mounted) return;
        setState(() {
          _todayAttendance = attendanceProvider.todayAttendance;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error getting location: $e';
        });
      }
      _showErrorDialog('Error getting location: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = place.name ?? '';
        if (address.isEmpty) address = place.street ?? '';
        if (address.isEmpty) address = place.locality ?? '';
        if (address.isEmpty) address = place.administrativeArea ?? '';
        if (address.isEmpty) address = 'Hostel Location';
        return address;
      }
      return 'Hostel Location';
    } catch (e) {
      debugPrint('Error getting hostel address: $e');
      return 'Hostel Location';
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAttendance() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isWithinGeofence) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are ${_distanceFromHostel.toStringAsFixed(0)} meters outside hostel premises. Please move closer.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);

    bool isCheckedIn = _todayAttendance?['checkedIn'] ?? false;
    bool isCheckedOut = _todayAttendance?['checkedOut'] ?? false;

    Map<String, dynamic> result;

    if (!isCheckedIn) {
      // Check In
      result = await attendanceProvider.markCheckIn(
        studentId: authProvider.user!.uid!,
        location: _currentPosition!,
        method: 'gps',
      );
    } else if (isCheckedIn && !isCheckedOut) {
      // Check Out
      result = await attendanceProvider.markCheckOut(authProvider.user!.uid!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already checked out today'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result['message']}'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = Provider.of<AttendanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _checkLocation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hostel Location Info - Now showing address instead of Lat/Lng
                    if (_hostelLocation != null && _hostelLocation!['latitude'] != 0.0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_city, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Hostel Location',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _hostelAddress ?? 'Hostel Location',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Location Status Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _isWithinGeofence ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isWithinGeofence ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _isWithinGeofence ? Icons.location_on : Icons.location_off,
                            color: _isWithinGeofence ? Colors.green : Colors.red,
                            size: 50,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isWithinGeofence ? 'Within Hostel Premises' : 'Outside Hostel Premises',
                            style: TextStyle(
                              color: _isWithinGeofence ? Colors.green : Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Distance: ${_distanceFromHostel.toStringAsFixed(0)} meters',
                            style: TextStyle(
                              color: _isWithinGeofence ? Colors.green : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                          if (_address != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _address!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.grey600, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Location Details - Now with better formatting
                    if (_currentPosition != null) ...[
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
                          children: [
                            _buildLocationDetailRow(
                              'Your Location',
                              _address ?? 'Unknown location',
                              Icons.my_location,
                              AppColors.primary,
                            ),
                            const Divider(),
                            _buildLocationDetailRow(
                              'Distance from Hostel',
                              '${_distanceFromHostel.toStringAsFixed(0)} meters',
                              Icons.straighten,
                              Colors.blue,
                            ),
                            const Divider(),
                            _buildLocationDetailRow(
                              'Accuracy',
                              '${_currentPosition!.accuracy.toStringAsFixed(1)} meters',
                              Icons.gps_fixed,
                              Colors.orange,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Current Status
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
                        children: [
                          Row(
                            children: [
                              Icon(
                                _todayAttendance?['checkedIn'] == true
                                    ? Icons.check_circle
                                    : Icons.pending,
                                color: _todayAttendance?['checkedIn'] == true
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _todayAttendance?['checkedIn'] == true
                                    ? 'Already checked in today'
                                    : 'Not checked in yet',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          if (_todayAttendance?['checkInTime'] != null) ...[
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Check In Time:'),
                                Text(
                                  DateFormat('hh:mm a').format(
                                    _todayAttendance!['checkInTime'].toDate(),
                                  ),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                          if (_todayAttendance?['checkOutTime'] != null) ...[
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Check Out Time:'),
                                Text(
                                  DateFormat('hh:mm a').format(
                                    _todayAttendance!['checkOutTime'].toDate(),
                                  ),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Mark Attendance Button
                    CustomButton(
                      text: _todayAttendance?['checkedIn'] == true
                          ? (_todayAttendance?['checkedOut'] == true
                              ? 'Already Checked Out'
                              : 'Check Out Now')
                          : 'Check In Now',
                      onPressed: _todayAttendance?['checkedOut'] == true
                          ? null
                          : _markAttendance,
                      icon: _todayAttendance?['checkedIn'] == true
                          ? Icons.logout
                          : Icons.login,
                    ),

                    const SizedBox(height: 16),

                    // Refresh Location Button
                    OutlinedButton.icon(
                      onPressed: _checkLocation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Location'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLocationDetailRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: AppColors.grey600, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}