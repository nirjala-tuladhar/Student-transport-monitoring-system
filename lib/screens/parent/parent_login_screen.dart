import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/common_widgets.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  bool _useOtp = true; // toggle between OTP and Password login
  bool _obscurePassword = true;
  final _auth = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
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
      final email = _emailController.text.trim();
      final secret = _passwordController.text;

      if (_useOtp) {
        // First, verify OTP exists and is not used
        final otpValid = await _auth.verifyOtpNotUsed(email, secret);
        if (!otpValid) {
          setState(() {
            _error = 'Invalid or already used OTP. Please use your password to login.';
            _loading = false;
          });
          return;
        }

        // Attempt sign-in using OTP as temporary password
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: secret,
        );

        if (!mounted) return;
        // Proceed to set permanent password
        Navigator.of(context).pushReplacementNamed('/parent/set-password');
      } else {
        // Normal password login
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: secret,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Login failed. Please try again.';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('invalid login credentials') || errorStr.contains('invalid')) {
          errorMsg = 'Incorrect email or password. Please try again.';
        } else if (errorStr.contains('email not confirmed')) {
          errorMsg = 'Please verify your email before logging in.';
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

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^.+@.+\..+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email above, then tap Forgot password');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final redirectTo = kIsWeb
          ? Uri.base.origin // return to the same running parent app origin
          : 'io.supabase.flutter://reset-callback';
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password reset email sent. Please check your inbox.'),
      ));
    } catch (e) {
      setState(() => _error = 'Failed to send reset email: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                        // Header
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppTheme.elevatedShadow,
                            ),
                            child: const Icon(
                              Icons.family_restroom_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Parent Portal',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Monitor your child\'s journey',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        // Toggle OTP / Password
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('OTP'),
                              icon: Icon(Icons.pin_rounded, size: 18),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('Password'),
                              icon: Icon(Icons.lock_rounded, size: 18),
                            ),
                          ],
                          selected: {_useOtp},
                          onSelectionChanged: (s) => setState(() => _useOtp = s.first),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return AppTheme.primaryBlue;
                              }
                              return Colors.white;
                            }),
                            foregroundColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.white;
                              }
                              return AppTheme.primaryBlue;
                            }),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ModernTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'Enter your email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Email required';
                            if (!RegExp(r'^.+@.+\..+$').hasMatch(value)) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ModernTextField(
                          controller: _passwordController,
                          label: _useOtp ? 'One-Time Password (OTP)' : 'Password',
                          hint: _useOtp ? 'Enter your OTP' : 'Enter your password',
                          prefixIcon: _useOtp ? Icons.pin_rounded : Icons.lock_outline,
                          obscureText: !_useOtp && _obscurePassword,
                          keyboardType: _useOtp ? TextInputType.number : TextInputType.visiblePassword,
                          suffixIcon: !_useOtp ? IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ) : null,
                          validator: (v) {
                            if (v == null || v.isEmpty) return _useOtp ? 'OTP required' : 'Password required';
                            return null;
                          },
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
                        if (!_useOtp) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _loading ? null : _forgotPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ],
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
