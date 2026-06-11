import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/student_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_textfield.dart';
import '../../core/models/student_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({Key? key}) : super(key: key);

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  // Personal Info Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _enrollmentController = TextEditingController();
  
  // Parent Info Controllers
  final _parentNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _parentEmailController = TextEditingController();
  
  // Address Controllers
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  // Academic Controllers
  final _courseController = TextEditingController();
  final _batchController = TextEditingController();
  
  // Emergency Controllers
  final _emergencyContactController = TextEditingController();
  final _medicalConditionsController = TextEditingController();
  
  // Dropdown Values
  String? _selectedSemester;
  String? _selectedBloodGroup;
  
  // File Picker
  File? _profileImage;
  List<File> _documents = [];
  
  bool _isLoading = false;
  int _currentStep = 0;

  final List<String> _semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _enrollmentController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _courseController.dispose();
    _batchController.dispose();
    _emergencyContactController.dispose();
    _medicalConditionsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _pickDocument() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        _documents.add(File(image.path));
      });
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  Future<void> _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final studentProvider = Provider.of<StudentProvider>(context, listen: false);

      // Create student model - ✅ Set isVerified to true for auto-verification
      StudentModel student = StudentModel(
        userId: '',
        enrollmentNo: _enrollmentController.text,
        fullName: _nameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        course: _courseController.text,
        semester: int.tryParse(_selectedSemester ?? '1'),
        batch: _batchController.text,
        parentName: _parentNameController.text,
        parentPhone: _parentPhoneController.text,
        parentEmail: _parentEmailController.text,
        address: _addressController.text,
        city: _cityController.text,
        state: _stateController.text,
        pincode: _pincodeController.text,
        bloodGroup: _selectedBloodGroup,
        emergencyContact: _emergencyContactController.text,
        medicalConditions: _medicalConditionsController.text,
        isVerified: true, // ✅ Auto-verify for room allocation
      );

      bool success = await studentProvider.addStudent(student);

      setState(() => _isLoading = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${studentProvider.errorMessage ?? 'Failed to add student'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 4) {
      _scrollToTop();
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _scrollToTop();
      setState(() {
        _currentStep--;
      });
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Student'),
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
                _buildStepIndicator(0, 'Personal'),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.5), thickness: 2)),
                _buildStepIndicator(1, 'Parent'),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.5), thickness: 2)),
                _buildStepIndicator(2, 'Address'),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.5), thickness: 2)),
                _buildStepIndicator(3, 'Academic'),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.5), thickness: 2)),
                _buildStepIndicator(4, 'Documents'),
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
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_currentStep == 0) _buildPersonalInfoStep(),
                    if (_currentStep == 1) _buildParentInfoStep(),
                    if (_currentStep == 2) _buildAddressStep(),
                    if (_currentStep == 3) _buildAcademicStep(),
                    if (_currentStep == 4) _buildDocumentsStep(),
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
                      text: _currentStep == 4 ? 'Save Student' : 'Next',
                      onPressed: _currentStep == 4 ? _saveStudent : _nextStep,
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
    bool isCompleted = step < _currentStep;
    bool isCurrent = step == _currentStep;
    
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
                ? const Icon(Icons.check, color: Colors.white, size: 16)
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
            fontSize: 10,
            color: isCurrent ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoStep() {
    return Column(
      children: [
        // Profile Image
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.grey200,
                  border: Border.all(color: AppColors.primary, width: 2),
                  image: _profileImage != null
                      ? DecorationImage(
                          image: FileImage(_profileImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _profileImage == null
                    ? Icon(
                        Icons.person_add,
                        size: 40,
                        color: AppColors.grey600,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        CustomTextField(
          controller: _nameController,
          label: 'Full Name',
          prefixIcon: Icons.person,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter full name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _enrollmentController,
          label: 'Enrollment Number',
          prefixIcon: Icons.badge,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter enrollment number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _emailController,
          label: 'Email',
          prefixIcon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter email';
            }
            if (!value.contains('@') || !value.contains('.')) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _phoneController,
          label: 'Phone Number',
          prefixIcon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter phone number';
            }
            if (value.length < 10) {
              return 'Enter a valid 10-digit number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildParentInfoStep() {
    return Column(
      children: [
        CustomTextField(
          controller: _parentNameController,
          label: "Parent's Name",
          prefixIcon: Icons.people,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter parent's name";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _parentPhoneController,
          label: "Parent's Phone",
          prefixIcon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter parent's phone";
            }
            if (value.length < 10) {
              return 'Enter a valid 10-digit number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _parentEmailController,
          label: "Parent's Email",
          prefixIcon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter parent's email";
            }
            if (!value.contains('@') || !value.contains('.')) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAddressStep() {
    return Column(
      children: [
        CustomTextField(
          controller: _addressController,
          label: 'Address',
          prefixIcon: Icons.location_on,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _cityController,
          label: 'City',
          prefixIcon: Icons.location_city,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter city';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _stateController,
          label: 'State',
          prefixIcon: Icons.map,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter state';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _pincodeController,
          label: 'Pincode',
          prefixIcon: Icons.markunread_mailbox,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter pincode';
            }
            if (value.length != 6) {
              return 'Enter a valid 6-digit pincode';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAcademicStep() {
    return Column(
      children: [
        CustomTextField(
          controller: _courseController,
          label: 'Course',
          prefixIcon: Icons.school,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter course';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<String>(
          value: _selectedSemester,
          decoration: InputDecoration(
            labelText: 'Semester',
            prefixIcon: Icon(Icons.format_list_numbered, color: AppColors.grey600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColors.grey100,
          ),
          items: _semesters.map((sem) {
            return DropdownMenuItem(
              value: sem,
              child: Text('Semester $sem'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSemester = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Please select semester';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _batchController,
          label: 'Batch (e.g., 2024-2028)',
          prefixIcon: Icons.group,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter batch';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<String>(
          value: _selectedBloodGroup,
          decoration: InputDecoration(
            labelText: 'Blood Group',
            prefixIcon: Icon(Icons.bloodtype, color: AppColors.grey600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: AppColors.grey100,
          ),
          items: _bloodGroups.map((bg) {
            return DropdownMenuItem(
              value: bg,
              child: Text(bg),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedBloodGroup = value;
            });
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _emergencyContactController,
          label: 'Emergency Contact Number',
          prefixIcon: Icons.emergency,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter emergency contact';
            }
            if (value.length < 10) {
              return 'Enter a valid 10-digit number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _medicalConditionsController,
          label: 'Medical Conditions (if any)',
          prefixIcon: Icons.medical_services,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildDocumentsStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey300),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.upload_file, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Upload Documents',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: _pickDocument,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add Document'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              if (_documents.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ..._documents.asMap().entries.map((entry) {
                  int index = entry.key;
                  File file = entry.value;
                  return ListTile(
                    leading: const Icon(Icons.description, color: AppColors.primary),
                    title: Text(file.path.split('/').last),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _removeDocument(index),
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can upload student photos, ID proof, and other documents. '
                  'Maximum file size: 5MB per file.',
                  style: TextStyle(
                    color: AppColors.grey700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}