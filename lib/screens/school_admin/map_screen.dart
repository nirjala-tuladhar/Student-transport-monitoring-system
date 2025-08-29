import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/school_service.dart';
import '../../services/geocoding_service.dart';

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
      setState(() {
        _locations = data;
        _loading = false;
      });

      // Determine center/marker for school
      if (school?.latitude != null && school?.longitude != null) {
        setState(() {
          _school = LatLng(school!.latitude!, school.longitude!);
          _center = _school!;
        });
      } else if (school != null && school.name.isNotEmpty) {
        // Fallback: best-effort geocode by school name
        try {
          final query = [school.name, school.address ?? '']
              .where((e) => e.trim().isNotEmpty)
              .join(', ');
          final geo = await GeocodingService().geocodeAddress(query);
          if (!mounted) return;
          if (geo != null) {
            setState(() {
              _school = LatLng(geo.lat, geo.lon);
              _center = _school!;
            });
          }
        } catch (_) {}
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
      markers.add(
        Marker(
          point: _school!,
          alignment: Alignment.bottomCenter,
          width: 36,
          height: 36,
          child: const Icon(Icons.school, color: Colors.blue, size: 32),
        ),
      );
    }

    markers.addAll(_locations.map<Marker>((row) {
      final lat = (row['latitude'] as num).toDouble();
      final lon = (row['longitude'] as num).toDouble();
      final plate = (row['plate_number'] as String?) ?? 'Bus';
      return Marker(
        point: LatLng(lat, lon),
        alignment: Alignment.bottomCenter,
        width: 160,
        height: 64,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(plate, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const Icon(Icons.directions_bus, color: Colors.red, size: 26),
          ],
        ),
      );
    }).toList());
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Failed to load bus locations:\n$_error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
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
              if (_school != null && _locations.isNotEmpty)
                PolylineLayer(
                  polylines: _locations.map((row) {
                    final lat = (row['latitude'] as num).toDouble();
                    final lon = (row['longitude'] as num).toDouble();
                    return Polyline(
                      points: [_school!, LatLng(lat, lon)],
                      strokeWidth: 3,
                      color: Colors.orange,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Buses: ${_locations.length}'),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _loadLocations,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
