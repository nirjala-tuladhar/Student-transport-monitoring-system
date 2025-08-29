import 'dart:math';
import 'package:flutter/material.dart';
import 'package:student_transport_monitoring_system/services/auth_service.dart';
import 'package:student_transport_monitoring_system/services/school_service.dart';
import '../../supabase_client.dart';

class CreateSchoolAdminScreen extends StatefulWidget {
  const CreateSchoolAdminScreen({super.key});

  @override
  State<CreateSchoolAdminScreen> createState() =>
      _CreateSchoolAdminScreenState();
}

class _CreateSchoolAdminScreenState extends State<CreateSchoolAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _authService = AuthService();
  final _schoolService = SchoolService();

  bool _loading = false;
  String? _errorMessage;
  String? _successMessage;

  // Generates a random, secure password for one-time use during invitation.
  String generateSecurePassword({int length = 12}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#\$%&*!';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)])
        .join();
  }

  Future<void> _createSchoolAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final schoolName = _schoolNameController.text.trim();
    final email = _emailController.text.trim();

    try {
      // 1) Create the school first (admin client bypasses RLS)
      final schoolResponse = await _schoolService.createSchool(schoolName);
      final String schoolId = schoolResponse['id'] as String;

      // 2) Invite the user and attach school metadata so it shows in Authentication -> Users
      final newUser = await _authService.inviteUserByEmail(
        email,
        'school_admin',
        schoolName: schoolName,
        schoolId: schoolId,
      );

      // 3) Create the school_admin link row
      await _authService.createSchoolAdmin(newUser.id, schoolId);

      setState(() {
        _successMessage = 'Invitation sent to $email for $schoolName';
        _schoolNameController.clear();
        _emailController.clear();
      });

      // Optionally, navigate back after a delay.
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) Navigator.pop(context);
      });

    } catch (e) {
      setState(() => _errorMessage = 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create School Admin')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _schoolNameController,
                    decoration: const InputDecoration(
                      labelText: 'School Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Enter school name' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'School Admin Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter email';
                      final emailRegex =
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
                      if (!emailRegex.hasMatch(val)) return 'Enter valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _createSchoolAdmin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Send Invitation',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null)
                    SelectableText(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (_successMessage != null)
                    SelectableText(
                      _successMessage!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
