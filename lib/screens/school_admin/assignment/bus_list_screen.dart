import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusListScreen extends StatefulWidget {
  const BusListScreen({super.key});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _buses;

  Future<List<Map<String, dynamic>>> _fetchBusList() async {
    final buses = await supabase
        .from('buses')
        .select('*, driver:drivers(*), students:students(*)');
    return List<Map<String, dynamic>>.from(buses);
  }

  Future<void> _removeStudent(String studentId, String busId) async {
    final confirm = await _showConfirmationDialog(
        'Remove Student?', 'Are you sure you want to remove this student?');
    if (confirm) {
      await supabase
          .from('students')
          .update({'bus_id': null}).eq('id', studentId);
      setState(() => _buses = _fetchBusList());
    }
  }

  Future<void> _removeDriver(String driverId, String busId) async {
    final confirm = await _showConfirmationDialog(
        'Remove Driver?', 'Are you sure you want to remove this driver?');
    if (confirm) {
      await supabase.from('buses').update({'driver_id': null}).eq('id', busId);
      setState(() => _buses = _fetchBusList());
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
  void initState() {
    super.initState();
    _buses = _fetchBusList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _buses,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final buses = snapshot.data!;
        return ListView.builder(
          itemCount: buses.length,
          itemBuilder: (context, index) {
            final bus = buses[index];
            final driver = bus['driver'];
            final students = bus['students'] ?? [];
            return Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🚌 Bus No: ${bus['bus_number']}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (driver != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '👨‍✈️ Driver: ${driver['id']} - ${driver['name']}'),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _removeDriver(driver['id'], bus['id']),
                          ),
                        ],
                      )
                    else
                      const Text('👨‍✈️ Driver: Not Assigned'),
                    const Divider(),
                    const Text('🧒 Students:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    for (var student in students)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${student['id']} - ${student['name']}'),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () =>
                                _removeStudent(student['id'], bus['id']),
                          ),
                        ],
                      ),
                    if (students.isEmpty) const Text('No students assigned.')
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
