import 'package:flutter/material.dart';
import '../../../models/bus.dart';
import '../../../models/driver.dart';
import '../../../models/student.dart';
import '../../../services/school_service.dart';

class BusListScreen extends StatefulWidget {
  const BusListScreen({super.key});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  final SchoolService _schoolService = SchoolService();
  late Future<List<Map<String, dynamic>>> _busesFuture;

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  void _loadBuses() {
    setState(() {
      _busesFuture = _schoolService.getBusesWithDetails();
    });
  }

  Future<void> _removeStudent(String studentId) async {
    final confirm = await _showConfirmationDialog(
        'Remove Student?', 'Are you sure you want to remove this student from the bus?');
    if (confirm) {
      await _schoolService.unassignStudent(studentId);
      _loadBuses(); // Refresh the list
    }
  }

  Future<void> _removeDriver(String busId) async {
    final confirm = await _showConfirmationDialog(
        'Remove Driver?', 'Are you sure you want to remove this driver from the bus?');
    if (confirm) {
      await _schoolService.unassignDriver(busId);
      _loadBuses(); // Refresh the list
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _busesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No buses found.'));
        }

        final busesData = snapshot.data!;
        return ListView.builder(
          itemCount: busesData.length,
          itemBuilder: (context, index) {
            final busData = busesData[index];
            final bus = Bus.fromMap(busData);
            final driverData = busData['driver'];
            final driver = driverData != null ? Driver.fromMap(driverData) : null;
            final studentsData = busData['students'] as List<dynamic>? ?? [];
            final students = studentsData.map((s) => Student.fromMap(s)).toList();

            return Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🚌 Plate No: ${bus.plateNumber}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (driver != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('👨‍✈️ Driver: ${driver.name}'),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeDriver(bus.id),
                          ),
                        ],
                      )
                    else
                      const Text('👨‍✈️ Driver: Not Assigned'),
                    const Divider(),
                    const Text('🧒 Students:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    if (students.isNotEmpty)
                      ...students.map((student) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(student.name),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _removeStudent(student.id),
                              ),
                            ],
                          ))
                    else
                      const Text('No students assigned.')
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
