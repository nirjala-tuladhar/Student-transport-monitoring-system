import 'package:flutter/material.dart';
import '../../services/bus_service.dart';

class SelectBusScreen extends StatefulWidget {
  const SelectBusScreen({super.key});

  @override
  State<SelectBusScreen> createState() => _SelectBusScreenState();
}

class _SelectBusScreenState extends State<SelectBusScreen> {
  final _service = BusService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _buses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.listMyBuses();
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(() {
          _error = 'No buses linked to this account';
          _loading = false;
        });
        return;
      }
      if (rows.length == 1) {
        Navigator.of(context).pushReplacementNamed('/home', arguments: rows.first['id'] as String);
        return;
      }
      setState(() {
        _buses = rows;
        _loading = false;
      });
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
      appBar: AppBar(title: const Text('Select Bus')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: _buses.length,
                  itemBuilder: (context, i) {
                    final b = _buses[i];
                    final plate = b['plate_number'] as String? ?? 'Bus';
                    final driver = b['driver']?['name'] as String?;
                    return ListTile(
                      title: Text(plate),
                      subtitle: Text(driver == null ? 'No driver' : 'Driver: $driver'),
                      onTap: () => Navigator.of(context).pushReplacementNamed('/home', arguments: b['id'] as String),
                    );
                  },
                ),
    );
  }
}
