import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../../../models/school.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  bool _useManualCoords = false;
  final _schoolService = SchoolService();
  final _authService = AuthService();
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _uploadingLogo = false;
  School? _school;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final school = await _schoolService.getSchool();
      if (school != null) {
        setState(() {
          _school = school;
          _nameController.text = school.name;
          // Load coordinates if available
          if (school.latitude != null) {
            _latController.text = school.latitude.toString();
          }
          if (school.longitude != null) {
            _lngController.text = school.longitude.toString();
          }
          // Parse existing address into Area, City, Country
          final addr = (school.address ?? '').trim();
          if (addr.isNotEmpty) {
            final parts = addr.split(',').map((e) => e.trim()).toList();
            if (parts.length >= 3) {
              _areaController.text = parts[0];
              _cityController.text = parts[1];
              _countryController.text = parts.sublist(2).join(', ');
            } else if (parts.length == 2) {
              _cityController.text = parts[0];
              _countryController.text = parts[1];
            } else if (parts.length == 1) {
              _cityController.text = parts[0];
            }
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate() || _school == null) return;

    setState(() => _isLoading = true);

    try {
      final area = _areaController.text.trim();
      final city = _cityController.text.trim();
      final country = _countryController.text.trim();
      // Format: Area, City, Country (Area is optional)
      final combinedAddress = [area, city, country].where((e) => e.isNotEmpty).join(', ');
      
      // Check if using manual coordinates
      double? manualLat;
      double? manualLng;
      if (_useManualCoords) {
        manualLat = double.tryParse(_latController.text.trim());
        manualLng = double.tryParse(_lngController.text.trim());
        if (manualLat == null || manualLng == null) {
          throw Exception('Invalid coordinates. Please enter valid numbers.');
        }
      }
      
      await _schoolService.updateSchoolProfile(
        id: _school!.id,
        name: _nameController.text.trim(),
        address: combinedAddress,
        manualLat: manualLat,
        manualLng: manualLng,
      );
      
      // Reload profile to get updated coordinates
      await _loadProfile();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully! School location has been geocoded.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadLogo() async {
    if (_school == null) return;

    try {
      // Pick image from gallery
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _uploadingLogo = true);

      // Get image bytes (works on both web and mobile)
      final bytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name;

      // Upload to Supabase
      await _schoolService.uploadSchoolLogoBytes(
        schoolId: _school!.id,
        imageBytes: bytes,
        fileName: fileName,
      );

      // Reload profile to get updated logo
      await _loadProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingLogo = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading
            ? const CircularProgressIndicator()
            : _school == null
                ? const Text('Profile not found.')
                : Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.school, color: Colors.blue[700], size: 32),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Edit School Profile',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Logo Upload Section
                          Column(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.blue[300]!, width: 2),
                                  image: _school?.logoUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(_school!.logoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _school?.logoUrl == null
                                    ? Center(
                                        child: Text(
                                          'LOGO',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _uploadingLogo ? null : _pickAndUploadLogo,
                                icon: _uploadingLogo
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.upload),
                                label: Text(_uploadingLogo ? 'Uploading...' : 'Upload Logo'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'School Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _areaController,
                        decoration: const InputDecoration(
                          labelText: 'Area / Street (Optional)',
                          hintText: 'e.g., Sungabha Marg, Dhapakhel',
                          border: OutlineInputBorder(),
                          helperText: 'Specific area or street name',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      // Manual Coordinates Section - Always visible
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'School Location Coordinates',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Get exact coordinates from Google Maps by right-clicking on your school location',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 16),
                            CheckboxListTile(
                              title: const Text('Use manual coordinates'),
                              subtitle: const Text('Recommended for accurate location'),
                              value: _useManualCoords,
                              onChanged: (val) {
                                setState(() => _useManualCoords = val ?? false);
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _latController,
                              decoration: InputDecoration(
                                labelText: 'Latitude',
                                hintText: 'e.g., 27.6915',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: _useManualCoords ? Colors.white : Colors.grey[100],
                                prefixIcon: const Icon(Icons.north),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              enabled: _useManualCoords,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _lngController,
                              decoration: InputDecoration(
                                labelText: 'Longitude',
                                hintText: 'e.g., 85.3206',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: _useManualCoords ? Colors.white : Colors.grey[100],
                                prefixIcon: const Icon(Icons.east),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              enabled: _useManualCoords,
                            ),
                          ],
                        ),
                      ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _updateProfile,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
