import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_client.dart';
import '../../services/bus_service.dart';

class BusHomeScreen extends StatefulWidget {
  const BusHomeScreen({super.key});

  @override
  State<BusHomeScreen> createState() => _BusHomeScreenState();
}

class _BusHomeScreenState extends State<BusHomeScreen> {
  final _busService = BusService();
  String? _busId;
  String? _tripId;
  Map<String, dynamic>? _busInfo; // contains plate_number, driver
  List<Map<String, dynamic>> _students = [];
  List<String> _boardedIds = [];
  String? _status;
  Timer? _locTimer;
  bool _simStarted = false;

  @override
  void initState() {
    super.initState();
    // Defer reading ModalRoute args until first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      final arg = ModalRoute.of(context)?.settings.arguments;
      final id = (arg is String && arg.isNotEmpty) ? arg : await _busService.getMyBusId();
      setState(() => _busId = id);
      await _loadBusInfo();
      await _loadStudentsAndBoarded();
      // Use simulator for testing to avoid heavy sensors and frequent DB writes
      if (!_simStarted) {
        _busService.startSimulatingLocation(
          busId: id,
          stepPerTick: 0.00002, // ~2.2 m/tick
          interval: const Duration(seconds: 10), // 1 tick / 10s
          debugPrints: false,
        );
        _simStarted = true;
        setState(() => _status = 'Simulator started');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Init error: $e');
    }
  }

  // Location permission and raw device timer removed while using simulator

  Future<void> _loadBusInfo() async {
    final id = _busId!;
    final info = await _busService.getBusWithDriver(id);
    setState(() => _busInfo = info);
  }

  Future<void> _loadStudentsAndBoarded() async {
    final id = _busId!;
    final studs = await _busService.listStudentsForBus(id);
    String? trip = _tripId ?? await _busService.getActiveTripId(id);
    List<Map<String, dynamic>> boarded = [];
    if (trip != null) {
      boarded = await _busService.listBoarded(trip);
    }
    setState(() {
      _students = studs;
      _tripId = trip;
      _boardedIds = boarded.map((e) => e['student_id'] as String).toList();
    });
  }

  Future<void> _startTrip() async {
    final id = _busId!;
    final trip = await _busService.startTrip(id);
    setState(() => _tripId = trip);
    await _loadStudentsAndBoarded();
  }

  Future<void> _endTrip() async {
    final trip = _tripId;
    if (trip == null) return;
    await _busService.endTrip(trip);
    setState(() => _tripId = null);
    await _loadStudentsAndBoarded();
  }

  // Fingerprint features removed per requirement

  Future<void> _boardStudent(String studentId, String name) async {
    if (_tripId == null) {
      await _startTrip();
    }
    final trip = _tripId!;
    await _busService.markBoarded(tripId: trip, studentId: studentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Good morning, $name'), duration: const Duration(seconds: 3)),
    );
    await _loadStudentsAndBoarded();
  }

  // Scan fingerprint logic removed

  Future<void> _unboardStudent(String studentId) async {
    final trip = _tripId;
    if (trip == null) return;
    await _busService.markUnboarded(tripId: trip, studentId: studentId);
    await _loadStudentsAndBoarded();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    _locTimer?.cancel();
    final id = _busId;
    if (id != null && _simStarted) {
      _busService.stopSimulatingLocation(id);
      _simStarted = false;
    }
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    final id = _busId;
    if (id != null && _simStarted) {
      _busService.stopSimulatingLocation(id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busName = _busInfo == null ? '-' : (_busInfo!['plate_number'] as String? ?? '-');
    final driverName = _busInfo?['driver']?['name'] as String?;
    final unboarded = _students.where((s) => !_boardedIds.contains(s['id'] as String)).toList();
    final boarded = _students.where((s) => _boardedIds.contains(s['id'] as String)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Panel'),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
      ),
      // Removed fingerprint FAB
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bus: $busName'),
            Text('Driver: ${driverName ?? '-'}'),
            const SizedBox(height: 8),
            Text('Status: ${_status ?? 'Ready'}'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _tripId == null ? _startTrip : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Trip'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _tripId != null ? _endTrip : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.stop),
                  label: const Text('End Trip'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Unboarded', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.builder(
                            itemCount: unboarded.length,
                            itemBuilder: (context, i) {
                              final s = unboarded[i];
                              final fullName = (s['name'] as String?)?.trim();
                              final firstName = (s['first_name'] as String?)?.trim();
                              final lastName = (s['last_name'] as String?)?.trim();
                              String displayFirst = firstName ?? (fullName != null ? fullName.split(' ').first : 'Student');
                              String? displayLast;
                              if (lastName != null && lastName.isNotEmpty) {
                                displayLast = lastName;
                              } else if (fullName != null) {
                                final parts = fullName.split(' ');
                                if (parts.length > 1) displayLast = parts.sublist(1).join(' ');
                              }
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(displayFirst, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      if (displayLast != null && displayLast.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2.0),
                                          child: Text(displayLast, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                        ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _boardStudent(s['id'] as String, displayFirst),
                                          icon: const Icon(Icons.login),
                                          label: const Text('Board'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Boarded', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.builder(
                            itemCount: boarded.length,
                            itemBuilder: (context, i) {
                              final s = boarded[i];
                              final fullName = (s['name'] as String?)?.trim();
                              final firstName = (s['first_name'] as String?)?.trim();
                              final lastName = (s['last_name'] as String?)?.trim();
                              String displayFirst = firstName ?? (fullName != null ? fullName.split(' ').first : 'Student');
                              String? displayLast;
                              if (lastName != null && lastName.isNotEmpty) {
                                displayLast = lastName;
                              } else if (fullName != null) {
                                final parts = fullName.split(' ');
                                if (parts.length > 1) displayLast = parts.sublist(1).join(' ');
                              }
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(displayFirst, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      if (displayLast != null && displayLast.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2.0),
                                          child: Text(displayLast, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                        ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _unboardStudent(s['id'] as String),
                                          icon: const Icon(Icons.logout),
                                          label: const Text('Unboard'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
