import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bus Panel Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Username required';
                  if (value.length < 3) return 'At least 3 characters';
                  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) return 'Use lowercase letters, numbers, _ only';
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Password required' : null,
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
            ],
          ),
        ),
      ),
    );
  }
}
