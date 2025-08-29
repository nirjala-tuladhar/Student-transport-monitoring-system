import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

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
  final _auth = AuthService();

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
        // Attempt sign-in using OTP as temporary password
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: secret,
        );

        // Enforce single-use: check if this is a first OTP login
        final isFirst = await _auth.isFirstOtpLogin();
        if (!isFirst) {
          // OTP has already been used. Prevent reuse.
          await Supabase.instance.client.auth.signOut();
          setState(() {
            _error = 'OTP already used. Please login with your password or request a new OTP.';
            _loading = false;
          });
          return;
        }

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
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Parent Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toggle OTP / Password
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Login with OTP')),
                  ButtonSegment(value: false, label: Text('Login with Password')),
                ],
                selected: {_useOtp},
                onSelectionChanged: (s) => setState(() => _useOtp = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Email required';
                  if (!RegExp(r'^.+@.+\..+$').hasMatch(value)) return 'Invalid email';
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: _useOtp ? 'One-Time Password (OTP)' : 'Password'),
                obscureText: !_useOtp,
                keyboardType: _useOtp ? TextInputType.number : TextInputType.visiblePassword,
                validator: (v) {
                  if (v == null || v.isEmpty) return _useOtp ? 'OTP required' : 'Password required';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Login'),
              )
              ,
              if (!_useOtp)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
