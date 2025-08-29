import 'package:flutter/material.dart';
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
  final _schoolService = SchoolService();
  final _authService = AuthService();
  bool _isLoading = false;
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
          // Best-effort parse existing address into Area, City, Country
          final addr = (school.address ?? '').trim();
          if (addr.isNotEmpty) {
            final parts = addr.split(',').map((e) => e.trim()).toList();
            if (parts.length >= 3) {
              // Expecting: Area, City, Country
              _areaController.text = parts[0];
              _cityController.text = parts[1];
              _countryController.text = parts.sublist(2).join(', ');
            } else if (parts.length == 2) {
              // Fallback: City, Country (legacy)
              _cityController.text = parts[0];
              _countryController.text = parts[1];
            } else if (parts.length == 1) {
              // Unknown format: put into city for compatibility
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
      // New format: Area, City, Country (omit empty parts)
      final combinedAddress = [area, city, country].where((e) => e.isNotEmpty).join(', ');
      await _schoolService.updateSchoolProfile(
        id: _school!.id,
        name: _nameController.text.trim(),
        // Store City, Country for clarity and improved geocoding
        address: combinedAddress,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _school == null
              ? const Center(child: Text('Profile not found.'))
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Edit School Profile', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'School Name'),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _areaController,
                        decoration: const InputDecoration(labelText: 'Area / Locality (e.g., Gems, Dhapakhel)'),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _countryController,
                        decoration: const InputDecoration(labelText: 'Country'),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _updateProfile,
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
