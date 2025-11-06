import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/common_widgets.dart';

/// Redesigned School Admin Login Screen with modern UI/UX
/// 
/// Key Features:
/// - Material 3 design with gradient background
/// - Smooth fade-in animations
/// - Animated button with loading state
/// - Password visibility toggle
/// - Responsive layout
/// - Accessibility improvements
class SchoolAdminLoginScreen extends StatefulWidget {
  const SchoolAdminLoginScreen({super.key});

  @override
  State<SchoolAdminLoginScreen> createState() => _SchoolAdminLoginScreenState();
}

class _SchoolAdminLoginScreenState extends State<SchoolAdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      // Navigate to dashboard after successful login
      if (mounted) {
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo and Header Section
                      _buildHeader(),
                      
                      const SizedBox(height: 40),
                      
                      // Login Form Card
                      _buildLoginCard(isSmallScreen),
                      
                      const SizedBox(height: 24),
                      
                      // Footer
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInAnimation(
      delay: const Duration(milliseconds: 100),
      child: Column(
        children: [
          // App Icon/Logo
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Title
          Text(
            'School Admin Portal',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Sign in to manage your school',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(bool isSmallScreen) {
    return FadeInAnimation(
      delay: const Duration(milliseconds: 200),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 24.0 : 32.0),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
          border: Border.all(
            color: AppTheme.borderColor,
            width: 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Text
              Text(
                'Welcome Back!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Enter your credentials to continue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Email Field
              ModernTextField(
                controller: _emailController,
                label: 'Email Address',
                hint: 'Enter your email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!v.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Password Field
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
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Login Button
              AnimatedButton(
                text: 'Sign In',
                onPressed: _login,
                isLoading: _isLoading,
                icon: Icons.arrow_forward_rounded,
                width: double.infinity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return FadeInAnimation(
      delay: const Duration(milliseconds: 300),
      child: Column(
        children: [
          // Security Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.success.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Secure Login',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Help Text
          Text(
            'Need help? Contact your administrator',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
