import 'dart:math';
import 'package:flutter/material.dart';
import 'package:student_transport_monitoring_system/services/auth_service.dart';
import 'package:student_transport_monitoring_system/services/school_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/common_widgets.dart';

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
      String errorMsg = 'Failed to create school admin. Please try again.';
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('already exists') || errorStr.contains('duplicate')) {
        errorMsg = 'This email is already registered. Please use a different email.';
      } else if (errorStr.contains('invalid email')) {
        errorMsg = 'Invalid email format. Please check and try again.';
      } else if (errorStr.contains('network')) {
        errorMsg = 'Network error. Please check your connection and try again.';
      } else if (errorStr.contains('permission') || errorStr.contains('unauthorized')) {
        errorMsg = 'You do not have permission to perform this action.';
      }
      
      setState(() => _errorMessage = errorMsg);
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 26, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'New School Setup',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.white),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: FadeInAnimation(
                child: AnimatedCard(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Create Admin Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                    SizedBox(height: 4),
                                    Text('Setup new school and admin profile', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        ModernTextField(
                          controller: _schoolNameController,
                          label: 'School Name',
                          hint: 'e.g., Springfield High School',
                          prefixIcon: Icons.school_rounded,
                          validator: (val) => val == null || val.isEmpty ? 'Enter school name' : null,
                        ),
                        const SizedBox(height: 20),
                        ModernTextField(
                          controller: _emailController,
                          label: 'School Admin Email',
                          hint: 'admin@school.com',
                          prefixIcon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Enter email';
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
                            if (!emailRegex.hasMatch(val)) return 'Enter valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        AnimatedButton(
                          text: 'Send Invitation',
                          icon: Icons.send_rounded,
                          onPressed: _loading ? null : _createSchoolAdmin,
                          isLoading: _loading,
                          backgroundColor: AppTheme.success,
                          width: double.infinity,
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(_errorMessage!, style: TextStyle(color: AppTheme.error, fontSize: 14, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                        if (_successMessage != null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(_successMessage!, style: TextStyle(color: AppTheme.success, fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
