import 'dart:math';
import 'package:flutter/material.dart';
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

  bool _loading = false;
  String? _errorMessage;
  String? _tempPassword;
  String? _successMessage;

  String generateTempPassword({int length = 8}) {
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
      _tempPassword = generateTempPassword();
    });

    final schoolName = _schoolNameController.text.trim();
    final email = _emailController.text.trim();

    try {
      // Step 1: Sign up the school admin user
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: _tempPassword!,
      );

      if (authResponse.user == null) {
        setState(() => _errorMessage = 'Failed to create user.');
        return;
      }

      // Step 2: Insert into 'school_admin' table
      await supabase.from('school_admin').insert({
        'school_name': schoolName,
        'email': email,
        'user_id': authResponse.user!.id,
      });

      setState(() {
        _successMessage =
            'Created successfully!\nTemp Password: $_tempPassword';
        _schoolNameController.clear();
        _emailController.clear();
      });

      Future.delayed(const Duration(seconds: 10), () {
        Navigator.pop(context);
      });
    } catch (e, stacktrace) {
      print('❌ Unexpected error: $e');
      print('🧱 Stacktrace: $stacktrace');
      setState(() => _errorMessage = 'Unexpected error. Check console.');
    } finally {
      setState(() => _loading = false);
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
                              'Create School Admin',
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
