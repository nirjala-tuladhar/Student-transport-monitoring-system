import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateStudentScreen extends StatefulWidget {
  const CreateStudentScreen({super.key});

  @override
  State<CreateStudentScreen> createState() => _CreateStudentScreenState();
}

class _CreateStudentScreenState extends State<CreateStudentScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createStudentAndParents() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;

    try {
      final studentId = 'LA${DateTime.now().millisecondsSinceEpoch}student';
      final parent1Id = studentId.replaceFirst('student', 'parent1');
      final parent2Id = studentId.replaceFirst('student', 'parent2');
      final password = 'password123';

      await supabase.from('students').insert({
        'id': studentId,
        'name': name,
        'password': password,
      });

      await supabase.from('parents').insert([
        {'id': parent1Id, 'student_id': studentId, 'password': password},
        {'id': parent2Id, 'student_id': studentId, 'password': password},
      ]);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Student and parents created successfully')),
        );
        _nameController.clear();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Student', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Student Name'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _createStudentAndParents,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Create'),
          ),
        ],
      ),
    );
  }
}
