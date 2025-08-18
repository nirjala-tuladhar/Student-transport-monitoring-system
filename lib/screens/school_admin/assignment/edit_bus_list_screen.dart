import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditBusListScreen extends StatefulWidget {
  const EditBusListScreen({super.key});

  @override
  State<EditBusListScreen> createState() => _EditBusListScreenState();
}

class _EditBusListScreenState extends State<EditBusListScreen> {
  List<Map<String, dynamic>> buses = [];
  List<Map<String, dynamic>> unassignedStudents = [];
  List<Map<String, dynamic>> unassignedDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final client = Supabase.instance.client;

    final busRes = await client
        .from('buses')
        .select('*, driver:drivers(*), students:students(*)');
    final studentsRes =
        await client.from('students').select('*').is_('bus_id', null);
    final driversRes =
        await client.from('drivers').select('*').is_('bus_id', null);

    setState(() {
      buses = List<Map<String, dynamic>>.from(busRes);
      unassignedStudents = List<Map<String, dynamic>>.from(studentsRes);
      unassignedDrivers = List<Map<String, dynamic>>.from(driversRes);
    });
  }

  Future<void> _assignStudentToBus(String studentId, String busId) async {
    await Supabase.instance.client
        .from('students')
        .update({'bus_id': busId}).eq('id', studentId);
    _loadData();
  }

  Future<void> _assignDriverToBus(String driverId, String busId) async {
    await Supabase.instance.client
        .from('drivers')
        .update({'bus_id': busId}).eq('id', driverId);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: buses.length,
        itemBuilder: (context, index) {
          final bus = buses[index];
          final busId = bus['id'].toString();
          return Card(
            margin: const EdgeInsets.all(10),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bus ${bus['bus_number']}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Text("Driver: "),
                      Text(bus['driver'] != null
                          ? '${bus['driver']['id']} - ${bus['driver']['name']}'
                          : 'None'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showDriverAssignDialog(busId),
                      )
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text("Students:"),
                  ...List<Widget>.from(
                      (bus['students'] ?? []).map<Widget>((student) => ListTile(
                            title: Text(student['name']),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () =>
                                  _removeStudentFromBus(student['id']),
                            ),
                          ))),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Student'),
                      onPressed: () => _showStudentAssignDialog(busId),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStudentAssignDialog(String busId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Assign Student"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unassignedStudents.length,
            itemBuilder: (context, index) {
              final student = unassignedStudents[index];
              return ListTile(
                title: Text(student['name']),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _assignStudentToBus(student['id'], busId);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDriverAssignDialog(String busId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Assign Driver"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unassignedDrivers.length,
            itemBuilder: (context, index) {
              final driver = unassignedDrivers[index];
              return ListTile(
                title: Text('${driver['id']} - ${driver['name']}'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _assignDriverToBus(driver['id'], busId);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _removeStudentFromBus(String studentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Student"),
        content: const Text(
            "Are you sure you want to remove this student from the bus?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Confirm")),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client
          .from('students')
          .update({'bus_id': null}).eq('id', studentId);
      _loadData();
    }
  }
}
