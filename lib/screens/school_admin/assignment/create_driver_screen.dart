import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateDriverScreen extends StatefulWidget {
  const CreateDriverScreen({super.key});

  @override
  State<CreateDriverScreen> createState() => _CreateDriverScreenState();
}

class _CreateDriverScreenState extends State<CreateDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _driverNameController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _createDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('driver')
          .select('driver_id')
          .order('driver_id', ascending: false)
          .limit(1)
          .execute();

      String newDriverId = 'DR0001'; // default if no driver exists
      if (response.data != null && (response.data as List).isNotEmpty) {
        final lastId = response.data[0]['driver_id'] as String;
        final numberPart =
            int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final nextNumber = numberPart + 1;
        newDriverId = 'DR${nextNumber.toString().padLeft(4, '0')}';
      }

      final response1 = await Supabase.instance.client.from('driver').insert({
        'driver_id': newDriverId,
        'driver_name': _driverNameController.text.trim(),
      });

      if (response == null || response is List && response1.isEmpty) {
        setState(() {
          _errorMessage = 'Failed to create driver.';
        });
      } else {
        setState(() {
          _successMessage = 'Driver created with ID $newDriverId';
          _driverNameController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 350,
        child: Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Create Driver',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _driverNameController,
                    decoration: const InputDecoration(
                      labelText: 'Driver Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter driver name'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _createDriver,
                            child: const Text('Create Driver'),
                          ),
                        ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
