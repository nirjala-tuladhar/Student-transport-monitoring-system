import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/common_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  final VoidCallback? onPasswordChanged;
  final String redirectRoute; // where to go after success
  const ChangePasswordScreen({this.onPasswordChanged, this.redirectRoute = '/login', super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  // final _schoolService = SchoolService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _success = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.changePassword(_passwordController.text);
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully. You can now close this tab.')),
      );
      // Notify parent if provided
      widget.onPasswordChanged?.call();
      // Do not navigate; finish here per requirements.
      setState(() {
        _success = true;
      });

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: FadeInAnimation(
                child: AnimatedCard(
                  padding: const EdgeInsets.all(28),
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
                                child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              const Text('Change Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
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
                                Expanded(child: Text(_errorMessage!, style: TextStyle(color: AppTheme.error, fontSize: 14, fontWeight: FontWeight.w500))),
                              ],
                            ),
                          ),
                        if (_success)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
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
                                const Expanded(child: Text('Password updated successfully. You may close this tab.', style: TextStyle(color: AppTheme.success, fontSize: 14, fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ),
                        ModernTextField(
                          controller: _passwordController,
                          label: 'New Password',
                          hint: 'Enter new password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: true,
                          validator: (v) => v!.length < 6 ? 'Password must be at least 6 characters' : null,
                        ),
                        const SizedBox(height: 20),
                        ModernTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm New Password',
                          hint: 'Re-enter password',
                          prefixIcon: Icons.lock_reset_rounded,
                          obscureText: true,
                          validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                        ),
                        const SizedBox(height: 32),
                        AnimatedButton(
                          text: 'Save Password',
                          icon: Icons.check_rounded,
                          onPressed: _isLoading ? null : _submit,
                          isLoading: _isLoading,
                          width: double.infinity,
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
