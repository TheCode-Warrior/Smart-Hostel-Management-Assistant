import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/room_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/models/room_model.dart';

class EditRoomScreen extends StatefulWidget {
  final String roomId;

  const EditRoomScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  _EditRoomScreenState createState() => _EditRoomScreenState();
}

class _EditRoomScreenState extends State<EditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _roomNumberController = TextEditingController();
  final _monthlyRentController = TextEditingController();
  final _capacityController = TextEditingController();
  final _floorController = TextEditingController();
  
  // Dropdown values
  String _selectedBlock = 'A';
  String _selectedRoomType = 'double';
  String _selectedStatus = 'available';
  
  // Features
  bool _attachedWashroom = false;
  bool _balcony = false;
  String _furnishing = 'none';
  bool _acAvailable = false;
  bool _fanAvailable = true;
  bool _geyserAvailable = false;
  bool _wifiAvailable = false;
  
  // Additional amenities
  List<String> _selectedAmenities = [];
  
  bool _isLoading = false;
  bool _isSaving = false;

  final List<String> _blocks = ['A', 'B', 'C', 'D'];
  final List<String> _roomTypes = ['single', 'double', 'triple', 'dormitory'];
  final List<String> _statuses = ['available', 'occupied', 'maintenance', 'cleaning'];
  final List<String> _furnishingOptions = ['none', 'basic', 'semi-furnished', 'fully-furnished'];
  final List<String> _availableAmenities = [
    'Study Table', 'Chair', 'Wardrobe', 'Bookshelf', 
    'Water Purifier', 'Refrigerator', 'TV', 'Attached Balcony'
  ];

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  Future<void> _loadRoomData() async {
    setState(() => _isLoading = true);
    
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    await roomProvider.loadRoomById(widget.roomId);
    
    final room = roomProvider.currentRoom;
    if (room != null) {
      _roomNumberController.text = room.roomNumber ?? '';
      _selectedBlock = room.hostelBlock ?? 'A';
      _floorController.text = (room.floor ?? 1).toString();
      _selectedRoomType = room.roomType ?? 'double';
      _capacityController.text = (room.capacity ?? 2).toString();
      _monthlyRentController.text = (room.monthlyRent ?? 0).toString();
      _selectedStatus = room.status?.toString().split('.').last ?? 'available';
      _selectedAmenities = List.from(room.amenities ?? []);
      
      final features = room.features ?? {};
      _attachedWashroom = features['attachedWashroom'] ?? false;
      _balcony = features['balcony'] ?? false;
      _furnishing = features['furnishing'] ?? 'none';
      _acAvailable = features['acAvailable'] ?? false;
      _fanAvailable = features['fanAvailable'] ?? true;
      _geyserAvailable = features['geyserAvailable'] ?? false;
      _wifiAvailable = features['wifiAvailable'] ?? false;
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _updateRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    final updates = {
      'roomNumber': _roomNumberController.text.trim(),
      'hostelBlock': _selectedBlock,
      'floor': int.tryParse(_floorController.text) ?? 1,
      'roomType': _selectedRoomType,
      'capacity': int.tryParse(_capacityController.text) ?? 2,
      'monthlyRent': double.tryParse(_monthlyRentController.text) ?? 0,
      'status': _selectedStatus,
      'isAvailable': _selectedStatus == 'available',
      'amenities': _selectedAmenities,
      'features': {
        'attachedWashroom': _attachedWashroom,
        'balcony': _balcony,
        'furnishing': _furnishing,
        'acAvailable': _acAvailable,
        'fanAvailable': _fanAvailable,
        'geyserAvailable': _geyserAvailable,
        'wifiAvailable': _wifiAvailable,
      },
    };

    final success = await roomProvider.updateRoom(widget.roomId, updates);

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(roomProvider.errorMessage ?? 'Failed to update room'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Room'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Room Number
              _buildTextField(
                controller: _roomNumberController,
                label: 'Room Number',
                icon: Icons.meeting_room,
              ),
              const SizedBox(height: 16),

              // Block Selection
              _buildDropdown(
                label: 'Block',
                value: _selectedBlock,
                items: _blocks,
                onChanged: (value) => setState(() => _selectedBlock = value!),
                displayBuilder: (value) => 'Block $value',
              ),
              const SizedBox(height: 16),

              // Floor Number
             // Floor Number
_buildTextField(
  controller: _floorController,
  label: 'Floor Number',
  icon: Icons.format_list_numbered,  // ✅ Fixed
  keyboardType: TextInputType.number,
),
              const SizedBox(height: 16),

              // Room Type
              _buildDropdown(
                label: 'Room Type',
                value: _selectedRoomType,
                items: _roomTypes,
                onChanged: (value) => setState(() => _selectedRoomType = value!),
                displayBuilder: (value) {
                  switch (value) {
                    case 'single': return 'Single Occupancy';
                    case 'double': return 'Double Occupancy';
                    case 'triple': return 'Triple Occupancy';
                    case 'dormitory': return 'Dormitory';
                    default: return value;
                  }
                },
              ),
              const SizedBox(height: 16),

              // Capacity
              _buildTextField(
                controller: _capacityController,
                label: 'Capacity',
                icon: Icons.people,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Monthly Rent
              _buildTextField(
                controller: _monthlyRentController,
                label: 'Monthly Rent (₹)',
                icon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Status
              _buildDropdown(
                label: 'Status',
                value: _selectedStatus,
                items: _statuses,
                onChanged: (value) => setState(() => _selectedStatus = value!),
                displayBuilder: (value) => value[0].toUpperCase() + value.substring(1),
              ),
              const SizedBox(height: 16),

              // Features Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Room Features', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: const Text('Attached Washroom'),
                      value: _attachedWashroom,
                      onChanged: (value) => setState(() => _attachedWashroom = value),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    SwitchListTile(
                      title: const Text('Balcony'),
                      value: _balcony,
                      onChanged: (value) => setState(() => _balcony = value),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    const SizedBox(height: 8),
                    const Text('Furnishing Level', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _furnishingOptions.map((option) {
                        final isSelected = _furnishing == option;
                        String displayName = option[0].toUpperCase() + option.substring(1);
                        if (option == 'none') displayName = 'No Furnishing';
                        if (option == 'basic') displayName = 'Basic';
                        if (option == 'semi-furnished') displayName = 'Semi-Furnished';
                        if (option == 'fully-furnished') displayName = 'Fully Furnished';
                        
                        return FilterChip(
                          label: Text(displayName),
                          selected: isSelected,
                          onSelected: (selected) => setState(() => _furnishing = selected ? option : 'none'),
                          backgroundColor: AppColors.grey100,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Air Conditioner (AC)'),
                      value: _acAvailable,
                      onChanged: (value) => setState(() => _acAvailable = value),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    SwitchListTile(
                      title: const Text('Ceiling Fan'),
                      value: _fanAvailable,
                      onChanged: (value) => setState(() => _fanAvailable = value),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    SwitchListTile(
                      title: const Text('Water Geyser'),
                      value: _geyserAvailable,
                      onChanged: (value) => setState(() => _geyserAvailable = value),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    SwitchListTile(
                      title: const Text('WiFi Connectivity'),
                      value: _wifiAvailable,
                      onChanged: (value) => setState(() => _wifiAvailable = value),
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amenities Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Additional Amenities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableAmenities.map((amenity) {
                        final isSelected = _selectedAmenities.contains(amenity);
                        return FilterChip(
                          label: Text(amenity),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAmenities.add(amenity);
                              } else {
                                _selectedAmenities.remove(amenity);
                              }
                            });
                          },
                          backgroundColor: AppColors.grey100,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Update Room',
                onPressed: _updateRoom,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AppColors.grey100,
      ),
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required String Function(String) displayBuilder,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.arrow_drop_down_circle, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AppColors.grey100,
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(displayBuilder(item)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}