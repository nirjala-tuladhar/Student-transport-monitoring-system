import 'package:flutter/material.dart';
import '../../../services/school_service.dart';

class CreateStudentScreen extends StatefulWidget {
  const CreateStudentScreen({super.key});

  @override
  State<CreateStudentScreen> createState() => _CreateStudentScreenState();
}

class _CreateStudentScreenState extends State<CreateStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _busStopController = TextEditingController();
  final _parent1EmailController = TextEditingController();
  final _parent2EmailController = TextEditingController();
  final _schoolService = SchoolService();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _schoolService.createStudent(
        name: _nameController.text.trim(),
        busStop: _busStopController.text.trim(),
        parent1Email: _parent1EmailController.text.trim(),
        parent2Email: _parent2EmailController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student created and parent invites sent!')),
      );
      _formKey.currentState!.reset();
      _nameController.clear();
      _busStopController.clear();
      _parent1EmailController.clear();
      _parent2EmailController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create student: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _busStopController.dispose();
    _parent1EmailController.dispose();
    _parent2EmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add a New Student', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Student\'s Full Name'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _busStopController,
                decoration: const InputDecoration(labelText: 'Bus Stop Location'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _parent1EmailController,
                decoration: const InputDecoration(labelText: 'Parent 1 Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty || !v.contains('@') ? 'Valid email required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _parent2EmailController,
                decoration: const InputDecoration(labelText: 'Parent 2 Email (Optional)'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Create Student & Invite Parents'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
