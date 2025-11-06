import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/school_service.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _schoolService = SchoolService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _locations = [];
  LatLng _center = const LatLng(27.7172, 85.3240); // Default: Kathmandu
  LatLng? _school;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _schoolService.getLatestBusLocations();
      final school = await _schoolService.getSchool();
      
      print('[SchoolAdminMap] ===== LOADING MAP DATA =====');
      print('[SchoolAdminMap] School: ${school?.name}');
      print('[SchoolAdminMap] School lat/lon: ${school?.latitude}, ${school?.longitude}');
      print('[SchoolAdminMap] School address: ${school?.address}');
      print('[SchoolAdminMap] Buses found: ${data.length}');
      
      setState(() {
        _locations = data;
        _loading = false;
      });

      // Determine center/marker for school
      if (school?.latitude != null && school?.longitude != null) {
        print('[SchoolAdminMap] ✅ Using stored school coordinates');
        setState(() {
          _school = LatLng(school!.latitude!, school.longitude!);
          _center = _school!;
        });
      } else if (school != null && school.name.isNotEmpty) {
        // Fallback: best-effort geocode by school name
        print('[SchoolAdminMap] ⚠️ No coordinates, attempting geocoding...');
        try {
          final query = [school.name, school.address ?? '']
              .where((e) => e.trim().isNotEmpty)
              .join(', ');
          print('[SchoolAdminMap] Geocoding query: "$query"');
          final geo = await GeocodingService().geocodeAddress(query);
          if (!mounted) return;
          if (geo != null) {
            print('[SchoolAdminMap] ✅ Geocoded successfully: ${geo.lat}, ${geo.lon}');
            setState(() {
              _school = LatLng(geo.lat, geo.lon);
              _center = _school!;
            });
          } else {
            print('[SchoolAdminMap] ❌ Geocoding returned null');
          }
        } catch (e) {
          print('[SchoolAdminMap] ❌ Geocoding error: $e');
        }
      } else {
        print('[SchoolAdminMap] ⚠️ No school data available');
      }

      if (_school == null && data.isNotEmpty) {
        // Center to first bus
        setState(() {
          _center = LatLng(
            (data.first['latitude'] as num).toDouble(),
            (data.first['longitude'] as num).toDouble(),
          );
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_school != null) {
      print('[SchoolAdminMap] Adding school marker at: ${_school!.latitude}, ${_school!.longitude}');
      markers.add(
        Marker(
          point: _school!,
          alignment: Alignment.bottomCenter,
          width: 100,
          height: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'School',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Color(0xFF2196F3),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      print('[SchoolAdminMap] ⚠️ No school marker - _school is null');
    }

    markers.addAll(_locations.map<Marker>((row) {
      final lat = (row['latitude'] as num).toDouble();
      final lon = (row['longitude'] as num).toDouble();
      final plate = (row['plate_number'] as String?) ?? 'Bus';
      return Marker(
        point: LatLng(lat, lon),
        alignment: Alignment.bottomCenter,
        width: 160,
        height: 75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xFFFF7043)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                plate,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: Color(0xFFFF5722),
                size: 24,
              ),
            ),
          ],
        ),
      );
    }).toList());
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGradient),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading map...', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.error.withOpacity(0.7)),
                const SizedBox(height: 16),
                Text('Failed to load bus locations', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.error, fontSize: 14)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadLocations,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'student_transport_monitoring_system',
            ),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Active Buses', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('${_locations.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: AppTheme.primaryBlue, size: 20),
                  ),
                  onPressed: _loadLocations,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
