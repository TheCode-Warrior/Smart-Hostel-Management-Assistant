import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/room_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_textfield.dart';
import '../../core/models/room_model.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({Key? key}) : super(key: key);

  @override
  _AddRoomScreenState createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
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
  final List<String> _selectedAmenities = [];
  final List<String> _availableAmenities = [
    'Study Table', 'Chair', 'Wardrobe', 'Bookshelf', 
    'Water Purifier', 'Refrigerator', 'TV', 'Attached Balcony'
  ];
  
  bool _isLoading = false;
  int _currentStep = 0;

  final List<String> _blocks = ['A', 'B', 'C', 'D'];
  final List<String> _roomTypes = ['single', 'double', 'triple', 'dormitory'];
  final List<String> _statuses = ['available', 'occupied', 'maintenance', 'cleaning'];
  final List<String> _furnishingOptions = ['none', 'basic', 'semi-furnished', 'fully-furnished'];

  @override
  void dispose() {
    _roomNumberController.dispose();
    _monthlyRentController.dispose();
    _capacityController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    final room = RoomModel(
      roomNumber: _roomNumberController.text.trim(),
      hostelBlock: _selectedBlock,
      floor: int.tryParse(_floorController.text) ?? 1,
      roomType: _selectedRoomType,
      capacity: int.tryParse(_capacityController.text) ?? 2,
      currentOccupancy: 0,
      isAvailable: _selectedStatus == 'available',
      monthlyRent: double.tryParse(_monthlyRentController.text) ?? 0,
      amenities: _selectedAmenities,
      status: _stringToStatus(_selectedStatus),
      features: {
        'attachedWashroom': _attachedWashroom,
        'balcony': _balcony,
        'furnishing': _furnishing,
        'acAvailable': _acAvailable,
        'fanAvailable': _fanAvailable,
        'geyserAvailable': _geyserAvailable,
        'wifiAvailable': _wifiAvailable,
      },
      occupants: [],
    );

    final success = await roomProvider.addRoom(room);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(roomProvider.errorMessage ?? 'Failed to add room'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  RoomStatus _stringToStatus(String status) {
    switch (status) {
      case 'available': return RoomStatus.available;
      case 'occupied': return RoomStatus.occupied;
      case 'maintenance': return RoomStatus.maintenance;
      case 'cleaning': return RoomStatus.cleaning;
      default: return RoomStatus.available;
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Room'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Basic Info'),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.5), thickness: 2)),
                _buildStepIndicator(1, 'Features'),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.5), thickness: 2)),
                _buildStepIndicator(2, 'Amenities'),
              ],
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_currentStep == 0) _buildBasicInfoStep(),
                    if (_currentStep == 1) _buildFeaturesStep(),
                    if (_currentStep == 2) _buildAmenitiesStep(),
                  ],
                ),
              ),
            ),
            
            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: _currentStep == 2 ? 'Add Room' : 'Next',
                      onPressed: _currentStep == 2 ? _saveRoom : _nextStep,
                      isLoading: _isLoading,
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

  Widget _buildStepIndicator(int step, String label) {
    final isCompleted = step < _currentStep;
    final isCurrent = step == _currentStep;
    
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? Colors.green
                : (isCurrent ? Colors.white : Colors.white.withOpacity(0.5)),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isCurrent ? AppColors.primary : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isCurrent ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoStep() {
    return Column(
      children: [
        // Room Number
        CustomTextField(
          controller: _roomNumberController,
          label: 'Room Number',
          prefixIcon: Icons.meeting_room,
          keyboardType: TextInputType.text,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter room number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Block Selection
        DropdownButtonFormField<String>(
          value: _selectedBlock,
          decoration: InputDecoration(
            labelText: 'Block',
            prefixIcon: Icon(Icons.apartment, color: AppColors.grey600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColors.grey100,
          ),
          items: _blocks.map((block) {
            return DropdownMenuItem(
              value: block,
              child: Text('Block $block'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBlock = value!;
            });
          },
        ),
        const SizedBox(height: 16),

        // Floor Number
        CustomTextField(
          controller: _floorController,
          label: 'Floor Number',
          prefixIcon: Icons.format_list_numbered,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter floor number';
            }
            if (int.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Room Type
        DropdownButtonFormField<String>(
          value: _selectedRoomType,
          decoration: InputDecoration(
            labelText: 'Room Type',
            prefixIcon: Icon(Icons.bed, color: AppColors.grey600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColors.grey100,
          ),
          items: _roomTypes.map((type) {
            String displayName;
            switch (type) {
              case 'single': displayName = 'Single Occupancy'; break;
              case 'double': displayName = 'Double Occupancy'; break;
              case 'triple': displayName = 'Triple Occupancy'; break;
              case 'dormitory': displayName = 'Dormitory'; break;
              default: displayName = type;
            }
            return DropdownMenuItem(
              value: type,
              child: Text(displayName),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedRoomType = value!;
              // Update capacity based on room type
              switch (value) {
                case 'single':
                  _capacityController.text = '1';
                  break;
                case 'double':
                  _capacityController.text = '2';
                  break;
                case 'triple':
                  _capacityController.text = '3';
                  break;
                case 'dormitory':
                  _capacityController.text = '6';
                  break;
              }
            });
          },
        ),
        const SizedBox(height: 16),

        // Capacity
        CustomTextField(
          controller: _capacityController,
          label: 'Capacity (Number of beds)',
          prefixIcon: Icons.people,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter capacity';
            }
            if (int.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Monthly Rent
        CustomTextField(
          controller: _monthlyRentController,
          label: 'Monthly Rent (₹)',
          prefixIcon: Icons.currency_rupee,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter monthly rent';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Initial Status
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          decoration: InputDecoration(
            labelText: 'Initial Status',
            prefixIcon: Icon(Icons.info_outline, color: AppColors.grey600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColors.grey100,
          ),
          items: _statuses.map((status) {
            String displayName = status[0].toUpperCase() + status.substring(1);
            return DropdownMenuItem(
              value: status,
              child: Text(displayName),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedStatus = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFeaturesStep() {
    return Column(
      children: [
        // Room Features Section
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
              const Text(
                'Room Features',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Attached Washroom
              SwitchListTile(
                title: const Text('Attached Washroom'),
                subtitle: const Text('Private washroom attached to room'),
                value: _attachedWashroom,
                onChanged: (value) {
                  setState(() {
                    _attachedWashroom = value;
                  });
                },
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Balcony
              SwitchListTile(
                title: const Text('Balcony'),
                subtitle: const Text('Attached balcony'),
                value: _balcony,
                onChanged: (value) {
                  setState(() {
                    _balcony = value;
                  });
                },
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Furnishing
              const SizedBox(height: 8),
              const Text(
                'Furnishing Level',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
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
                    onSelected: (selected) {
                      setState(() {
                        _furnishing = selected ? option : 'none';
                      });
                    },
                    backgroundColor: AppColors.grey100,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Appliances Section
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
              const Text(
                'Appliances',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // AC
              SwitchListTile(
                title: const Text('Air Conditioner (AC)'),
                value: _acAvailable,
                onChanged: (value) {
                  setState(() {
                    _acAvailable = value;
                  });
                },
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Fan
              SwitchListTile(
                title: const Text('Ceiling Fan'),
                value: _fanAvailable,
                onChanged: (value) {
                  setState(() {
                    _fanAvailable = value;
                  });
                },
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Geyser
              SwitchListTile(
                title: const Text('Water Geyser'),
                value: _geyserAvailable,
                onChanged: (value) {
                  setState(() {
                    _geyserAvailable = value;
                  });
                },
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              
              // WiFi
              SwitchListTile(
                title: const Text('WiFi Connectivity'),
                value: _wifiAvailable,
                onChanged: (value) {
                  setState(() {
                    _wifiAvailable = value;
                  });
                },
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesStep() {
    return Column(
      children: [
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
              const Text(
                'Additional Amenities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select amenities available in this room',
                style: TextStyle(color: AppColors.grey600, fontSize: 12),
              ),
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
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Info Card
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You can add more amenities later by editing the room.',
                  style: TextStyle(color: AppColors.grey700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}