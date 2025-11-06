import 'package:flutter/material.dart';
import '../../../models/bus.dart';
import '../../../models/driver.dart';
import '../../../models/student.dart';
import '../../../services/school_service.dart';

class EditBusListScreen extends StatefulWidget {
  const EditBusListScreen({super.key});

  @override
  State<EditBusListScreen> createState() => _EditBusListScreenState();
}

class _EditBusListScreenState extends State<EditBusListScreen> {
  final SchoolService _schoolService = SchoolService();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _busesData = [];
  List<Student> _unassignedStudents = [];
  List<Driver> _unassignedDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadScreenData();
  }

  Future<void> _loadScreenData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final busesFuture = _schoolService.getBusesWithDetails();
      final studentsFuture = _schoolService.getUnassignedStudents();
      final driversFuture = _schoolService.getUnassignedDrivers();

      final results = await Future.wait([busesFuture, studentsFuture, driversFuture]);

      setState(() {
        _busesData = results[0] as List<Map<String, dynamic>>;
        _unassignedStudents = results[1] as List<Student>;
        _unassignedDrivers = results[2] as List<Driver>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  void _showCreateBusDialog() {
    final plateNumberController = TextEditingController();
    final capacityController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    String? submitError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
        title: const Text('Create New Bus'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: plateNumberController,
                decoration: const InputDecoration(labelText: 'Plate Number'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: capacityController,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Required';
                  final n = int.tryParse(value);
                  if (n == null) return 'Invalid number';
                  if (n <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Bus Login Username'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Username is required';
                  if (v.length < 3) return 'At least 3 characters';
                  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v)) return 'Use lowercase letters, numbers, _ only';
                  return null;
                },
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Bus Login Password'),
                obscureText: true,
                validator: (value) {
                  final v = value ?? '';
                  if (v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              if (submitError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(submitError!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: submitting
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    setStateDialog(() {
                      submitting = true;
                      submitError = null;
                    });
                    try {
                      await _schoolService.createBus(
                        plateNumberController.text.trim(),
                        int.parse(capacityController.text.trim()),
                        username: usernameController.text.trim(),
                        password: passwordController.text,
                      );
                      if (mounted) Navigator.pop(context);
                      _loadScreenData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bus created')),
                        );
                      }
                    } catch (e) {
                      setStateDialog(() {
                        final msg = e.toString();
                        if (msg.toLowerCase().contains('already') || msg.toLowerCase().contains('duplicate') || msg.toLowerCase().contains('registered')) {
                          submitError = 'Username already taken';
                        } else {
                          submitError = msg;
                        }
                        submitting = false;
                      });
                    }
                  },
            child: submitting
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create'),
          ),
        ],
      ),
      ),
    );
  }

  void _showAssignStudentDialog(Bus bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Student to ${bus.plateNumber}'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: _unassignedStudents.isEmpty
              ? const Text('No unassigned students available.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _unassignedStudents.length,
                  itemBuilder: (context, index) {
                    final student = _unassignedStudents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.person, size: 20),
                        title: Text(
                          student.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          try {
                            await _schoolService.assignStudentToBus(student.id, bus.id);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Assigned ${student.name} to ${bus.plateNumber}')),
                              );
                            }
                            await _loadScreenData();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to assign: $e')),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showAssignDriverDialog(Bus bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Driver'),
        content: SizedBox(
          width: double.maxFinite,
          child: _unassignedDrivers.isEmpty
              ? const Text('No unassigned drivers available.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _unassignedDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = _unassignedDrivers[index];
                    return ListTile(
                      title: Text(driver.name),
                      onTap: () async {
                        try {
                          await _schoolService.assignDriverToBus(driver.id, bus.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Assigned driver ${driver.name}')),
                            );
                          }
                          await _loadScreenData();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to assign driver: $e')),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : RefreshIndicator(
                  onRefresh: _loadScreenData,
                  child: _busesData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_bus, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              const Text(
                                'No buses found.',
                                style: TextStyle(fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Use "Create Bus" from the menu to add one.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _busesData.length,
                          itemBuilder: (context, index) {
                            final busData = _busesData[index];
                            final bus = Bus.fromMap(busData);
                            final capacity = busData['capacity'];
                            final driverData = busData['driver'];
                            final driver = driverData != null ? Driver.fromMap(driverData) : null;
                            final studentsData = busData['students'] as List<dynamic>? ?? [];
                            final students = studentsData.map((s) => Student.fromMap(s)).toList();
                            return Card(
                              margin: const EdgeInsets.all(10),
                              elevation: 4,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Plate No: ${bus.plateNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('Capacity: ${capacity ?? 'N/A'}'),
                                    const Divider(),
                                    ListTile(
                                      leading: const Icon(Icons.person),
                                      title: Text(driver?.name ?? 'No driver assigned'),
                                      trailing: IconButton(
                                        icon: Icon(driver != null ? Icons.edit : Icons.add),
                                        onPressed: () => _showAssignDriverDialog(bus),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Students:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add'),
                                          onPressed: () => _showAssignStudentDialog(bus),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    if (students.isNotEmpty)
                                      ...students.map((student) => ListTile(
                                        leading: const Icon(Icons.child_care, size: 20),
                                        title: Text(student.name),
                                        dense: true,
                                      ))
                                    else
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text('No students assigned.'),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
