import 'package:flutter/material.dart';
import '../../services/bus_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';

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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
        ),
        title: const Text('Select Bus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGradient),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.error.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(_error!, style: TextStyle(fontSize: 16, color: AppTheme.error), textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : FadeInAnimation(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _buses.length,
                      itemBuilder: (context, i) {
                        final b = _buses[i];
                        final plate = b['plate_number'] as String? ?? 'Bus';
                        final driver = b['driver']?['name'] as String?;
                        return FadeInAnimation(
                          delay: Duration(milliseconds: i * 100),
                          child: AnimatedCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            onTap: () => Navigator.of(context).pushReplacementNamed('/home', arguments: b['id'] as String),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plate,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        driver == null ? 'No driver assigned' : 'Driver: $driver',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
