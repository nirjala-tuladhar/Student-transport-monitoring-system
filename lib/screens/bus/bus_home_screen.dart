import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/bus_service.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';

class BusHomeScreen extends StatefulWidget {
  const BusHomeScreen({super.key});

  @override
  State<BusHomeScreen> createState() => _BusHomeScreenState();
}

class _BusHomeScreenState extends State<BusHomeScreen> {
  final _busService = BusService();
  final _geocodingService = GeocodingService();
  String? _busId;
  String? _tripId;
  Map<String, dynamic>? _busInfo; // contains plate_number, driver
  List<Map<String, dynamic>> _students = [];
  List<String> _boardedIds = [];
  String? _status;
  Timer? _locTimer;
  bool _simStarted = false;
  bool _useDeviceGps = true; // Use phone GPS so Lockito can simulate
  StreamSubscription<Position>? _gpsSub;
  String _selectedTab = 'Unboarded'; // 'Unboarded' or 'Boarded'
  double? _currentLat;
  double? _currentLng;
  String _locationName = 'Getting location...';

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
      // Default: use device GPS so Lockito can drive the location
      await _ensurePermissions();
      await _startGpsTracking();
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
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_bus, color: Colors.blue[700], size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Safe trip, $name! 🚌',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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
    await _stopGpsTracking();
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
    _gpsSub?.cancel();
    final id = _busId;
    if (id != null && _simStarted) {
      _busService.stopSimulatingLocation(id);
    }
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _status = 'Enable Location Services');
      // We don't open settings automatically; Lockito/mock requires developer action
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _status = 'Location permission permanently denied');
    }
  }

  Future<void> _startGpsTracking() async {
    if (!_useDeviceGps) return;
    await _stopGpsTracking();
    final busId = _busId;
    if (busId == null) return;
    
    // Get initial position immediately
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final lat = pos.latitude;
      final lng = pos.longitude;
      await _busService.sendLocation(busId: busId, latitude: lat, longitude: lng);
      if (mounted) {
        setState(() {
          _status = 'Tracking';
          _currentLat = lat;
          _currentLng = lng;
        });
        // Get location name
        _updateLocationName(lat, lng);
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Getting location...');
    }
    
    // Then start continuous tracking
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters
    );
    _gpsSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) async {
      final lat = pos.latitude;
      final lng = pos.longitude;
      try {
        await _busService.sendLocation(busId: busId, latitude: lat, longitude: lng);
        if (mounted) {
          setState(() {
            _status = 'Tracking';
            _currentLat = lat;
            _currentLng = lng;
          });
          // Update location name periodically
          _updateLocationName(lat, lng);
        }
      } catch (e) {
        if (mounted) setState(() => _status = 'Error: $e');
      }
    });
  }

  Future<void> _stopGpsTracking() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
  }

  Future<void> _updateLocationName(double lat, double lng) async {
    try {
      final name = await _geocodingService.reverseGeocode(lat: lat, lon: lng);
      if (name != null && mounted) {
        setState(() => _locationName = name);
      } else if (mounted) {
        setState(() => _locationName = 'Location unavailable');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationName = 'Error getting location');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busName = _busInfo == null ? '-' : (_busInfo!['plate_number'] as String? ?? '-');
    final driverName = _busInfo?['driver']?['name'] as String?;
    final unboarded = _students.where((s) => !_boardedIds.contains(s['id'] as String)).toList();
    final boarded = _students.where((s) => _boardedIds.contains(s['id'] as String)).toList();

    return Scaffold(
      appBar: _buildModernAppBar(busName, driverName),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.subtleGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                                  busName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Driver: ${driverName ?? '-'}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.gps_fixed_rounded, 
                        _currentLat != null && _currentLng != null
                            ? '${_currentLat!.toStringAsFixed(6)}, ${_currentLng!.toStringAsFixed(6)}'
                            : (_status ?? 'Ready')),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.location_on_rounded, _locationName),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: _useDeviceGps,
                            activeColor: AppTheme.success,
                          onChanged: (v) async {
                            setState(() => _useDeviceGps = v);
                            if (v) {
                              await _ensurePermissions();
                              await _startGpsTracking();
                              // stop simulator if running
                              final id = _busId;
                              if (id != null && _simStarted) {
                                _busService.stopSimulatingLocation(id);
                                _simStarted = false;
                              }
                            } else {
                              await _stopGpsTracking();
                              // start simulator
                              final id = _busId;
                              if (id != null && !_simStarted) {
                                _busService.startSimulatingLocation(
                                  busId: id,
                                  stepPerTick: 0.00002,
                                  interval: const Duration(seconds: 10),
                                  debugPrints: false,
                                );
                                _simStarted = true;
                                setState(() => _status = 'Simulator started');
                              }
                            }
                          },
                        ),
                            const SizedBox(width: 12),
                            const Text('Use device GPS (Lockito)', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _tripId == null ? _startTrip : null,
                                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                label: const Text('Start Trip'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _tripId != null ? _endTrip : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _tripId != null ? AppTheme.error : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.stop_rounded, size: 20),
                                label: const Text('End Trip'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: AnimatedContainer(
                                  duration: AppTheme.fastAnimation,
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _selectedTab = 'Unboarded'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedTab == 'Unboarded' ? AppTheme.primaryBlue : Colors.white,
                                      foregroundColor: _selectedTab == 'Unboarded' ? Colors.white : AppTheme.primaryBlue,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: _selectedTab == 'Unboarded' ? 2 : 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                                      ),
                                    ),
                                    child: const Text('Unboarded', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: AppTheme.fastAnimation,
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _selectedTab = 'Boarded'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedTab == 'Boarded' ? AppTheme.success : Colors.white,
                                      foregroundColor: _selectedTab == 'Boarded' ? Colors.white : AppTheme.success,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: _selectedTab == 'Boarded' ? 2 : 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: AppTheme.success, width: 1.5),
                                      ),
                                    ),
                                    child: const Text('Boarded', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    const Divider(height: 1),
                    // Student list
                    Expanded(
                    child: _selectedTab == 'Unboarded'
                        ? ListView.separated(
                            padding: const EdgeInsets.all(8),
                            separatorBuilder: (context, index) => const Divider(),
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
                              final displayName = displayLast != null && displayLast.isNotEmpty
                                  ? '$displayFirst $displayLast'
                                  : displayFirst;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _boardStudent(s['id'] as String, displayFirst),
                                      icon: const Icon(Icons.login, size: 18),
                                      label: const Text('Board'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            separatorBuilder: (context, index) => const Divider(),
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
                              final displayName = displayLast != null && displayLast.isNotEmpty
                                  ? '$displayFirst $displayLast'
                                  : displayFirst;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _unboardStudent(s['id'] as String),
                                      icon: const Icon(Icons.logout, size: 18),
                                      label: const Text('Unboard'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red[700],
                                        side: BorderSide(color: Colors.red[700]!),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ), // closes Padding
      ), // closes Container
    ), // closes SafeArea
    );
  }

  PreferredSizeWidget _buildModernAppBar(String busName, String? driverName) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bus Driver Panel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Manage Your Route',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) _logout();
            },
            tooltip: 'Logout',
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textPrimary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
