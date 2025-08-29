import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/school_service.dart';

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
  final _schoolService = SchoolService();
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
      appBar: AppBar(title: const Text('Set Your Password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Change Your Password', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_success)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12.0),
                    child: Text('Password updated successfully. You may close this tab.', style: TextStyle(color: Colors.green)),
                  ),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: 'Confirm New Password'),
                  obscureText: true,
                  validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Save Password'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
