import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/common_widgets.dart';

class BusLoginScreen extends StatefulWidget {
  const BusLoginScreen({super.key});

  @override
  State<BusLoginScreen> createState() => _BusLoginScreenState();
}

class _BusLoginScreenState extends State<BusLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uname = _usernameController.text.trim().toLowerCase();
      final syntheticEmail = '$uname@bus.local';
      await Supabase.instance.client.auth.signInWithPassword(
        email: syntheticEmail,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/select-bus');
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Login failed. Please try again.';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('invalid login credentials') || errorStr.contains('invalid')) {
          errorMsg = 'Incorrect username or password. Please try again.';
        } else if (errorStr.contains('network')) {
          errorMsg = 'Network error. Please check your connection.';
        }
        
        setState(() {
          _error = errorMsg;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.subtleGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
              child: FadeInAnimation(
                duration: AppTheme.slowAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: EdgeInsets.all(isSmallScreen ? 24.0 : 32.0),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                    border: Border.all(color: AppTheme.borderColor, width: 1),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.elevatedShadow,
                            ),
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Bus Driver Portal',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Track and manage your route',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ModernTextField(
                          controller: _usernameController,
                          label: 'Username',
                          hint: 'Enter your username',
                          prefixIcon: Icons.person_outline,
                          keyboardType: TextInputType.text,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Username required';
                            if (value.length < 3) return 'At least 3 characters';
                            if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) return 'Use lowercase letters, numbers, _ only';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ModernTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Enter your password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Password required' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: AppTheme.error),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: AppTheme.error, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        AnimatedButton(
                          text: 'Sign In',
                          onPressed: _login,
                          isLoading: _loading,
                          icon: Icons.arrow_forward_rounded,
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
