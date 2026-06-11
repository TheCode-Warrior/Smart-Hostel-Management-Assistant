import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fyp_2026/core/models/student_model.dart';
import 'package:fyp_2026/core/providers/student_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/custom_button.dart';
import '../../routes/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _profileImage;
  bool _isPickingImage = false;
  bool _isUploading = false;
  String? _profileImageBase64;
  bool _imageLoadError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final user = authProvider.user;
    if (user != null) {
      _nameController.text = user.fullName ?? '';
      _phoneController.text = user.phoneNumber ?? '';
      _profileImageBase64 = user.profileImage;
      setState(() {});
    }
  }

  Future<String?> _convertImageToBase64(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);
      return base64String;
    } catch (e) {
      debugPrint('Error converting image to base64: $e');
      return null;
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300, // Reduced size for better performance
        maxHeight: 300,
        imageQuality: 60, // Lower quality to reduce size
      );

      if (image != null && mounted) {
        setState(() {
          _profileImage = File(image.path);
          _isUploading = true;
        });
        
        // Convert to base64
        final base64String = await _convertImageToBase64(File(image.path));
        
        if (base64String != null && mounted) {
          await _saveProfileImageBase64(base64String);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    } finally {
      _isPickingImage = false;
      setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfileImageBase64(String base64String) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      // Save base64 string to Firestore
      final success = await authProvider.updateProfile({
        'profileImage': base64String,
      });
      
      if (success && mounted) {
        setState(() {
          _profileImageBase64 = base64String;
          _profileImage = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to save profile image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isUploading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final updates = <String, dynamic>{
      'fullName': _nameController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
    };

    final success = await authProvider.updateProfile(updates);
    
    setState(() => _isUploading = false);
    
    if (!mounted) return;

    if (success) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Failed to update profile'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  // Custom widget for profile image from Base64
  Widget _buildProfileImage() {
    // If uploading, show loading indicator
    if (_isUploading) {
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    
    // If user picked a new image (not yet uploaded)
    if (_profileImage != null) {
      return ClipOval(
        child: Image.file(
          _profileImage!,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 42, color: Colors.white),
            );
          },
        ),
      );
    }
    
    // If there's a saved base64 image
    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty && !_imageLoadError) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(_profileImageBase64!),
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              setState(() => _imageLoadError = true);
              return Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: 42, color: Colors.white),
              );
            },
          ),
        );
      } catch (e) {
        return Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, size: 42, color: Colors.white),
        );
      }
    }
    
    // Default avatar
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, size: 42, color: Colors.white),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, {Color? accent}) {
    final color = accent ?? AppColors.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: AppColors.grey200.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: AppColors.grey600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: AppColors.grey600),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.grey100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.grey200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.grey200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    final createdAtText = user?.createdAt != null
        ? '${user!.createdAt!.toDate().day}/${user.createdAt!.toDate().month}/${user.createdAt!.toDate().year}'
        : 'N/A';
    final lastLoginText = user?.lastLogin != null
        ? '${user!.lastLogin!.toDate().day}/${user.lastLogin!.toDate().month}/${user.lastLogin!.toDate().year}'
        : 'N/A';

    return Scaffold(
      backgroundColor: AppColors.grey100,
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primary,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit, color: Colors.white, size: 22),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  _isEditing = false;
                  _loadData();
                } else {
                  _isEditing = true;
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.05),
                AppColors.grey100,
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryDark,
                        AppColors.primary,
                        AppColors.primaryLight,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Image with upload button
                      Stack(
                        children: [
                          _buildProfileImage(),
                          if (_isEditing && !_isUploading)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAndUploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'User',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                user?.roleString ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Personal Information Card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: AppColors.grey200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.grey900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Edit your name and phone number',
                          style: TextStyle(
                            color: AppColors.grey600,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildInfoRow(context, 'Email', user?.email ?? '', Icons.email_outlined),
                              const Divider(height: 20),
                              
                              if (_isEditing)
                                TextFormField(
                                  controller: _nameController,
                                  decoration: _inputDecoration('Full Name', Icons.person_outline),
                                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name' : null,
                                )
                              else
                                _buildInfoRow(context, 'Full Name', user?.fullName ?? '', Icons.person_outline),
                              const SizedBox(height: 10),
                              
                              if (_isEditing)
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
                                  keyboardType: TextInputType.phone,
                                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter phone number' : null,
                                )
                              else
                                _buildInfoRow(context, 'Phone', user?.phoneNumber ?? '', Icons.phone_outlined),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Metrics Row
                Row(
                  children: [
                    _buildMetricCard('Member since', createdAtText, Icons.calendar_month),
                    const SizedBox(width: 10),
                    _buildMetricCard('Last login', lastLoginText, Icons.schedule),
                  ],
                ),
                const SizedBox(height: 14),

                // Actions Section
                Text(
                  'Actions',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.grey900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                
                if (_isEditing)
                  CustomButton(
                    text: _isUploading ? 'Saving...' : 'Save Changes',
                    onPressed: _isUploading ? null : _saveProfile,
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Settings'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.25)),
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                    label: const Text('Logout', style: TextStyle(color: Colors.red)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}