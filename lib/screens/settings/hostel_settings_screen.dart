import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HostelSettingsScreen extends StatefulWidget {
  const HostelSettingsScreen({Key? key}) : super(key: key);

  @override
  _HostelSettingsScreenState createState() => _HostelSettingsScreenState();
}

class _HostelSettingsScreenState extends State<HostelSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Text Controllers
  final _hostelNameController = TextEditingController();
  final _hostelCodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _wardenNameController = TextEditingController();
  final _wardenContactController = TextEditingController();
  
  // Numeric Controllers
  final _totalBlocksController = TextEditingController();
  final _totalFloorsController = TextEditingController();
  final _totalRoomsController = TextEditingController();
  final _attendanceRadiusController = TextEditingController();
  final _qrValidDurationController = TextEditingController();
  final _lateEntryFineController = TextEditingController();
  final _cautionDepositController = TextEditingController();
  
  // Time Controllers - Flexible Meal Timings
  final _breakfastStartController = TextEditingController();
  final _breakfastEndController = TextEditingController();
  final _lunchStartController = TextEditingController();
  final _lunchEndController = TextEditingController();
  final _dinnerStartController = TextEditingController();
  final _dinnerEndController = TextEditingController();
  final _lateEntryTimeController = TextEditingController();
  
  // Meal timing toggles
  bool _breakfastEnabled = true;
  bool _lunchEnabled = false;
  bool _dinnerEnabled = true;
  
  // Location
  LatLng? _hostelLocation;
  LatLng? _currentLocation;
  GoogleMapController? _mapController;
  bool _isLoading = false;
  bool _isSaving = false;
  String _locationAddress = '';
  String _currentLocationAddress = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _hostelNameController.dispose();
    _hostelCodeController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _wardenNameController.dispose();
    _wardenContactController.dispose();
    _totalBlocksController.dispose();
    _totalFloorsController.dispose();
    _totalRoomsController.dispose();
    _attendanceRadiusController.dispose();
    _qrValidDurationController.dispose();
    _lateEntryFineController.dispose();
    _cautionDepositController.dispose();
    _breakfastStartController.dispose();
    _breakfastEndController.dispose();
    _lunchStartController.dispose();
    _lunchEndController.dispose();
    _dinnerStartController.dispose();
    _dinnerEndController.dispose();
    _lateEntryTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final settings = await FirestoreService.readDocument(
        collection: 'hostelSettings',
        documentId: 'settings',
      );

      if (settings != null) {
        _hostelNameController.text = settings['hostelName'] ?? '';
        _hostelCodeController.text = settings['hostelCode'] ?? '';
        _addressController.text = settings['address'] ?? '';
        _contactController.text = settings['contactNumber'] ?? '';
        _emailController.text = settings['email'] ?? '';
        _wardenNameController.text = settings['wardenName'] ?? '';
        _wardenContactController.text = settings['wardenContact'] ?? '';
        
        _totalBlocksController.text = settings['totalBlocks']?.toString() ?? '';
        _totalFloorsController.text = settings['totalFloors']?.toString() ?? '';
        _totalRoomsController.text = settings['totalRooms']?.toString() ?? '';
        _attendanceRadiusController.text = settings['attendanceRadius']?.toString() ?? '500';
        _qrValidDurationController.text = settings['qrCodeValidDuration']?.toString() ?? '30';
        _lateEntryFineController.text = settings['finePerHourLate']?.toString() ?? '50';
        _cautionDepositController.text = settings['cautionDeposit']?.toString() ?? '5000';

        // Load meal timings
        final timings = settings['messTimings'] ?? {};
        final activeMealTypes = List<String>.from(settings['messActiveMealTypes'] ?? const []);
        _breakfastStartController.text = timings['breakfast']?['start'] ?? '07:00';
        _breakfastEndController.text = timings['breakfast']?['end'] ?? '09:00';
        _lunchStartController.text = timings['lunch']?['start'] ?? '12:00';
        _lunchEndController.text = timings['lunch']?['end'] ?? '14:00';
        _dinnerStartController.text = timings['dinner']?['start'] ?? '19:00';
        _dinnerEndController.text = timings['dinner']?['end'] ?? '21:00';
        
        // Load meal type toggles
        _breakfastEnabled = activeMealTypes.isNotEmpty ? activeMealTypes.contains('breakfast') : timings['breakfast'] != null;
        _lunchEnabled = activeMealTypes.isNotEmpty ? activeMealTypes.contains('lunch') : timings['lunch'] != null;
        _dinnerEnabled = activeMealTypes.isNotEmpty ? activeMealTypes.contains('dinner') : timings['dinner'] != null;
        
        _lateEntryTimeController.text = settings['lateEntryTime'] ?? '22:00';

        if (settings['location'] != null) {
          final loc = settings['location'] as GeoPoint;
          _hostelLocation = LatLng(loc.latitude, loc.longitude);
          _locationAddress = settings['hostelLocationAddress'] ?? '';
        } else {
          try {
            final position = await Geolocator.getCurrentPosition();
            final currentLoc = LatLng(position.latitude, position.longitude);
            final currentAddr = await _getAddressFromCoordinates(position.latitude, position.longitude);
            setState(() {
              _currentLocation = currentLoc;
              _currentLocationAddress = currentAddr;
            });
          } catch (e) {
            debugPrint('Current location error: $e');
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return '${place.name ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}';
      }
      return 'Unknown location';
    } catch (e) {
      return 'Address not available';
    }
  }

  Future<void> _updateLocation(LatLng newLocation) async {
    setState(() {
      _hostelLocation = newLocation;
    });
    String address = await _getAddressFromCoordinates(newLocation.latitude, newLocation.longitude);
    setState(() {
      _locationAddress = address;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(newLocation));
  }

  Future<void> _goToCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.'), backgroundColor: Colors.red),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.'), backgroundColor: Colors.red),
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _searchLocation(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final url = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Flutter Hostel App',
        },
      );
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((item) => {
          'lat': double.parse(item['lat']),
          'lon': double.parse(item['lon']),
          'display_name': item['display_name'],
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  Future<void> _showLocationPickerDialog() async {
    if (_hostelLocation == null && _currentLocation == null) {
      try {
        final position = await Geolocator.getCurrentPosition();
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentLocationAddress = await _getAddressFromCoordinates(position.latitude, position.longitude);
      } catch (e) {
        debugPrint('Current location error: $e');
      }
    }

    final initialLocation = _hostelLocation ?? _currentLocation;
    final initialAddress = _hostelLocation != null
        ? _locationAddress
        : (_currentLocationAddress.isNotEmpty ? _currentLocationAddress : 'Current location');

    final selection = await showDialog<_LocationSelection>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LocationPickerDialog(
        initialLocation: initialLocation,
        initialAddress: initialAddress,
        searchLocation: _searchLocation,
        getAddressFromCoordinates: _getAddressFromCoordinates,
      ),
    );

    if (selection == null || !mounted) return;

    setState(() {
      _hostelLocation = selection.location;
      _locationAddress = selection.address;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 Location set: ${selection.address.substring(0, selection.address.length > 50 ? 50 : selection.address.length)}...'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_hostelLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set hostel location on the map'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (!_breakfastEnabled && !_lunchEnabled && !_dinnerEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable at least one meal type'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> messTimings = {};
      
      if (_breakfastEnabled) {
        messTimings['breakfast'] = {
          'start': _breakfastStartController.text,
          'end': _breakfastEndController.text
        };
      }
      if (_lunchEnabled) {
        messTimings['lunch'] = {
          'start': _lunchStartController.text,
          'end': _lunchEndController.text
        };
      }
      if (_dinnerEnabled) {
        messTimings['dinner'] = {
          'start': _dinnerStartController.text,
          'end': _dinnerEndController.text
        };
      }
      final activeMealTypes = <String>[];
      if (_breakfastEnabled) activeMealTypes.add('breakfast');
      if (_lunchEnabled) activeMealTypes.add('lunch');
      if (_dinnerEnabled) activeMealTypes.add('dinner');
      
      final settings = {
        'hostelName': _hostelNameController.text,
        'hostelCode': _hostelCodeController.text,
        'address': _addressController.text,
        'contactNumber': _contactController.text,
        'email': _emailController.text,
        'wardenName': _wardenNameController.text,
        'wardenContact': _wardenContactController.text,
        'totalBlocks': int.tryParse(_totalBlocksController.text) ?? 0,
        'totalFloors': int.tryParse(_totalFloorsController.text) ?? 0,
        'totalRooms': int.tryParse(_totalRoomsController.text) ?? 0,
        'attendanceRadius': double.tryParse(_attendanceRadiusController.text) ?? 500,
        'qrCodeValidDuration': int.tryParse(_qrValidDurationController.text) ?? 30,
        'finePerHourLate': double.tryParse(_lateEntryFineController.text) ?? 50,
        'cautionDeposit': double.tryParse(_cautionDepositController.text) ?? 5000,
        'lateEntryTime': _lateEntryTimeController.text,
        'hostelLocationAddress': _locationAddress,
        'messTimings': messTimings,
        'messActiveMealTypes': activeMealTypes,
        'location': GeoPoint(_hostelLocation!.latitude, _hostelLocation!.longitude),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': Provider.of<AuthProvider>(context, listen: false).user?.uid,
        'attendanceType': 'single_checkin',
      };

      await FirebaseFirestore.instance
          .collection('hostelSettings')
          .doc('settings')
          .set(settings, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Hostel Settings'),
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
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    _buildSection('Basic Information', [
                      _buildTextField(_hostelNameController, 'Hostel Name', Icons.apartment),
                      _buildTextField(_hostelCodeController, 'Hostel Code', Icons.code),
                      _buildTextField(_addressController, 'Address', Icons.location_on, maxLines: 2),
                      _buildTextField(_contactController, 'Contact Number', Icons.phone),
                      _buildTextField(_emailController, 'Email', Icons.email),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Warden Information', [
                      _buildTextField(_wardenNameController, 'Warden Name', Icons.person),
                      _buildTextField(_wardenContactController, 'Warden Contact', Icons.phone),
                    ]),
                   
                    const SizedBox(height: 16),
                    _buildLocationAndAttendanceSection(),
                    const SizedBox(height: 16),
                    _buildMealTimingsSection(),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Save Settings',
                      onPressed: _saveSettings,
                      isLoading: _isSaving,
                      icon: Icons.save,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
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
              child: Icon(Icons.apartment, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hostel Configuration', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Single check-in per day for residents', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationAndAttendanceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('Location & Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoNote('Single Check-In Per Day', 'Students will be marked present ONCE when they enter the hostel boundary.', Icons.info_outline),
          const SizedBox(height: 12),
          _buildNumberField(_attendanceRadiusController, 'Geo-fence Radius (meters)', Icons.gps_fixed),
          const SizedBox(height: 16),
          _buildLocationPicker(),
        ],
      ),
    );
  }

  Widget _buildLocationPicker() {
    final effectiveLocation = _hostelLocation ?? _currentLocation;
    final effectiveAddress = _hostelLocation != null
        ? _locationAddress
        : (_currentLocationAddress.isNotEmpty ? _currentLocationAddress : 'Current location');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (effectiveLocation != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.location_on, color: AppColors.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_hostelLocation != null ? 'Hostel Location' : 'Current Location', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(effectiveAddress.isNotEmpty ? effectiveAddress : 'Loading...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.grey800), maxLines: 2),
                ])),
                IconButton(icon: Icon(Icons.edit_location, color: AppColors.primary, size: 20), onPressed: _showLocationPickerDialog),
              ],
            ),
          ),
        if (effectiveLocation != null)
          Container(
            height: 250,
            decoration: BoxDecoration(border: Border.all(color: AppColors.grey200), borderRadius: BorderRadius.circular(12)),
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: effectiveLocation, zoom: 16),
                  onMapCreated: (controller) => _mapController = controller,
                  onTap: _updateLocation,
                  markers: {
                    Marker(
                      markerId: const MarkerId('hostel'),
                      position: effectiveLocation,
                      draggable: true,
                      onDragEnd: _updateLocation,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('geofence'),
                      center: effectiveLocation,
                      radius: double.tryParse(_attendanceRadiusController.text) ?? 500,
                      fillColor: AppColors.primary.withOpacity(0.1),
                      strokeColor: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  },
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    onPressed: _goToCurrentLocation,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(Icons.touch_app, size: 14, color: AppColors.grey600),
              const SizedBox(width: 6),
              Expanded(child: Text('🔍 Search location | 🖐️ Drag pin | 👆 Tap on map', style: TextStyle(fontSize: 11, color: AppColors.grey600))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote(String title, String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.info.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(icon, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(message, style: TextStyle(color: AppColors.grey700, fontSize: 11)),
          ])),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true, fillColor: AppColors.grey100,
        ),
        maxLines: maxLines,
        validator: (value) => (value == null || value.isEmpty) ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true, fillColor: AppColors.grey100,
        ),
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Please enter $label';
          if (double.tryParse(value) == null) return 'Please enter a valid number';
          return null;
        },
      ),
    );
  }

  Widget _buildTimeRow(String label, TextEditingController startController, TextEditingController endController, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(children: [Icon(icon, color: AppColors.primary, size: 20), const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w600))]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildSmallTimeField(startController, 'Start')),
            const SizedBox(width: 8), const Text('to'), const SizedBox(width: 8),
            Expanded(child: _buildSmallTimeField(endController, 'End')),
          ]),
        ],
      ),
    );
  }

  Widget _buildSmallTimeField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true, fillColor: Colors.white,
      ),
      readOnly: true,
      onTap: () => _selectTime(controller),
      validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
    );
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && mounted) {
      controller.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMealTimingsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 20, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('Flexible Meal Timings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Select which meals are available:', style: TextStyle(color: AppColors.grey700, fontSize: 13)),
          const SizedBox(height: 12),
          
          _buildMealTypeToggle('🥞 Breakfast', _breakfastEnabled, (value) => setState(() => _breakfastEnabled = value)),
          _buildMealTypeToggle('🍽️ Lunch', _lunchEnabled, (value) => setState(() => _lunchEnabled = value)),
          _buildMealTypeToggle('🍴 Dinner', _dinnerEnabled, (value) => setState(() => _dinnerEnabled = value)),
          
          const SizedBox(height: 16),
          
          if (_breakfastEnabled) ...[
            _buildTimeRow('Breakfast', _breakfastStartController, _breakfastEndController, Icons.free_breakfast),
            const SizedBox(height: 8),
          ],
          if (_lunchEnabled) ...[
            _buildTimeRow('Lunch', _lunchStartController, _lunchEndController, Icons.lunch_dining),
            const SizedBox(height: 8),
          ],
          if (_dinnerEnabled) ...[
            _buildTimeRow('Dinner', _dinnerStartController, _dinnerEndController, Icons.dinner_dining),
          ],
        ],
      ),
    );
  }

  Widget _buildMealTypeToggle(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value ? AppColors.primary.withOpacity(0.1) : AppColors.grey100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? AppColors.primary : AppColors.grey300,
            width: value ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: value ? AppColors.primary : AppColors.grey800)),
          ],
        ),
      ),
    );
  }
}

class _LocationSelection {
  final LatLng location;
  final String address;
  
  _LocationSelection({required this.location, required this.address});
}

class _LocationPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;
  final String initialAddress;
  final Future<List<Map<String, dynamic>>> Function(String) searchLocation;
  final Future<String> Function(double, double) getAddressFromCoordinates;

  const _LocationPickerDialog({
    Key? key,
    required this.initialLocation,
    required this.initialAddress,
    required this.searchLocation,
    required this.getAddressFromCoordinates,
  }) : super(key: key);

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  late LatLng _selectedLocation;
  late String _selectedAddress;
  late final TextEditingController _searchController;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? const LatLng(31.5204, 74.3587);
    _selectedAddress = widget.initialAddress;
    _searchController = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    final results = await widget.searchLocation(query);

    if (!mounted) return;

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _selectResult(Map<String, dynamic> result) async {
    final double lat = result['lat'];
    final double lon = result['lon'];
    final location = LatLng(lat, lon);

    if (!mounted) return;

    setState(() {
      _selectedLocation = location;
      _selectedAddress = result['display_name'];
      _searchResults = [];
      _isSearching = false;
      _searchController.text = result['display_name'];
    });

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 16),
      ),
    );
  }

  Future<void> _updateSelectedLocation(LatLng position) async {
    final address = await widget.getAddressFromCoordinates(position.latitude, position.longitude);

    if (!mounted) return;

    await _mapController?.animateCamera(CameraUpdate.newLatLng(position));

    setState(() {
      _selectedLocation = position;
      _selectedAddress = address;
      _searchResults = [];
    });
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);
      final address = await widget.getAddressFromCoordinates(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _selectedLocation = location;
        _selectedAddress = address;
        _searchController.text = address;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting current location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(8),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Set Hostel Location',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search city, area, landmark...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.grey100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _search,
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.grey600),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                        });
                      },
                    ),
                ],
              ),
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (_searchResults.isNotEmpty)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.grey200),
                  ),
                ),
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.location_on, color: AppColors.primary, size: 18),
                      title: Text(
                        result['display_name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () => _selectResult(result),
                    );
                  },
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: true,
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation,
                      zoom: 15,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _updateSelectedLocation,
                    markers: {
                      Marker(
                        markerId: const MarkerId('hostel'),
                        position: _selectedLocation,
                        draggable: true,
                        onDragEnd: _updateSelectedLocation,
                        infoWindow: const InfoWindow(
                          title: 'Hostel Location',
                          snippet: 'Drag or tap to adjust',
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                      ),
                    },
                    circles: {
                      Circle(
                        circleId: const CircleId('radius'),
                        center: _selectedLocation,
                        radius: 100,
                        fillColor: AppColors.primary.withOpacity(0.15),
                        strokeColor: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    },
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'currentLocation',
                          backgroundColor: Colors.white,
                          onPressed: _goToCurrentLocation,
                          child: const Icon(Icons.my_location, color: AppColors.primary),
                        ),
                        const SizedBox(height: 10),
                        FloatingActionButton.small(
                          heroTag: 'centerMap',
                          backgroundColor: AppColors.primary,
                          onPressed: () {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(_selectedLocation, 16),
                            );
                          },
                          child: const Icon(Icons.center_focus_strong, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: AppColors.grey100,
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _selectedAddress.isNotEmpty ? _selectedAddress : 'Loading...',
                      style: TextStyle(fontSize: 11, color: AppColors.grey700),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.grey200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          _LocationSelection(
                            location: _selectedLocation,
                            address: _selectedAddress,
                          ),
                        );
                      },
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}