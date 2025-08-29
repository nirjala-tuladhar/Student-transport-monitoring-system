import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/parent_service.dart';
import '../../services/parent_notification_service.dart';
import '../../services/notification_log_service.dart';
import '../../services/geocoding_service.dart';

class MapTab extends StatefulWidget {
  final String? busId;
  final String busPlate;
  const MapTab({super.key, required this.busId, required this.busPlate});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final _service = ParentService();
  RealtimeChannel? _locChannel;
  RealtimeChannel? _boardingChannel;
  LatLng? _current;
  LatLng? _school;
  LatLng? _home;
  String? _studentId;
  bool? _boarded; // unknown initially
  DateTime? _lastEtaNotify;
  bool _dropNotified = false;
  final _mapController = MapController();
  final _log = NotificationLogService();
  final _remoteNotif = ParentNotificationService();
  DateTime? _lastProcessAt;
  LatLng? _lastProcessedPos;

  @override
  void initState() {
    super.initState();
    _loadContext();
    _initBus();
  }

  Future<void> _initBus() async {
    final busId = widget.busId;
    debugPrint('[Parent Map] busId: ${busId ?? 'null'}');
    if (busId == null) return;
    try {
      // Fetch latest location first, so the marker appears even before realtime
      final latest = await _service.getLatestBusLocation(busId);
      if (latest != null && mounted) {
        final lat = (latest['latitude'] as num).toDouble();
        final lng = (latest['longitude'] as num).toDouble();
        final pos = LatLng(lat, lng);
        setState(() => _current = pos);
        debugPrint('[Parent Map] initial bus pos: $lat, $lng');
      } else {
        debugPrint('[Parent Map] no previous bus location found');
      }
    } catch (e) {
      debugPrint('[Parent Map] getLatestBusLocation error: $e');
    }
    // Subscribe for realtime updates
    _subscribe(busId);
    debugPrint('[Parent Map] subscribed to bus location');
  }

  Future<void> _loadContext() async {
    try {
      final row = await _service.getMyChildWithBus();
      if (!mounted || row == null) return;
      // school coords
      final school = row['school'] as Map<String, dynamic>?;
      final slat = (school?['latitude'] as num?)?.toDouble();
      final slon = (school?['longitude'] as num?)?.toDouble();
      // home coords
      final hlat = (row['bus_stop_lat'] as num?)?.toDouble();
      final hlon = (row['bus_stop_lng'] as num?)?.toDouble();
      String? stopText = row['bus_stop'] as String?;
      // Debug: print fetched coordinates
      // These prints help verify if RLS/columns are providing data
      // They will appear in the terminal/Run console
      // Remove once verified
      // ignore: avoid_print
      debugPrint('[Parent Map] school lat/lng: $slat, $slon');
      debugPrint('[Parent Map] home   lat/lng: $hlat, $hlon');
      setState(() {
        if (slat != null && slon != null) _school = LatLng(slat, slon);
        if (hlat != null && hlon != null) _home = LatLng(hlat, hlon);
        _studentId = row['id'] as String?;
      });

      // Fallback: if no home coords but we have a bus_stop text, try geocoding it once
      if (mounted && _home == null && (stopText != null && stopText.trim().isNotEmpty)) {
        try {
          final geo = await GeocodingService().geocodeAddress(stopText);
          if (geo != null && mounted) {
            setState(() => _home = LatLng(geo.lat, geo.lon));
            debugPrint('[Parent Map] home geocoded from bus_stop text: ${geo.lat}, ${geo.lon}');
            // Persist back to DB so it doesn't disappear on next load
            final sid = _studentId;
            if (sid != null) {
              unawaited(_service.persistHomeCoords(studentId: sid, lat: geo.lat, lng: geo.lon));
            }
          }
        } catch (e) {
          debugPrint('[Parent Map] geocode bus_stop failed: $e');
        }
      }

      // Subscribe to boarding status changes
      if (_studentId != null) {
        _boardingChannel = _service.subscribeBoarding(
          studentId: _studentId!,
          onInsert: (r) async {
            // Try to deduce status
            final status = (r['status'] ?? r['event'] ?? r['state'] ?? '').toString().toLowerCase();
            String? message;
            if (status.contains('board')) {
              if (status.contains('un')) {
                _boarded = false; message = 'Your child has unboarded the bus';
              } else {
                _boarded = true; message = 'Your child has boarded the bus';
              }
            } else if (r.containsKey('boarded') || r.containsKey('is_boarded')) {
              final b = (r['boarded'] ?? r['is_boarded']) as bool?;
              if (b != null) {
                _boarded = b;
                message = b ? 'Your child has boarded the bus' : 'Your child has unboarded the bus';
              }
            }
            if (message != null) {
              // Silent log only; no in-map SnackBar
              await _log.addLog(NotificationLogItem(
                message: message,
                type: 'boarding',
                timestamp: DateTime.now(),
              ));
              // Persist to backend so it's visible later
              unawaited(_remoteNotif.createMyNotification(type: 'boarding', message: message));
            }
          },
        );
      }
    } catch (e) {
      debugPrint('[Parent Map] _loadContext error: $e');
    }
  }

  void _subscribe(String busId) {
    _locChannel = _service.subscribeBusLocation(
      busId: busId,
      onInsert: (row) {
        final lat = (row['latitude'] as num).toDouble();
        final lng = (row['longitude'] as num).toDouble();
        final pos = LatLng(lat, lng);
        if (!mounted) return;
        // Throttle updates: process if >=10s since last or moved >30m
        final now = DateTime.now();
        final timeOk = _lastProcessAt == null || now.difference(_lastProcessAt!).inSeconds >= 10;
        final distOk = _lastProcessedPos == null ||
            const Distance().as(LengthUnit.Meter, pos, _lastProcessedPos!) > 30.0;
        if (!(timeOk || distOk)) return;
        _lastProcessAt = now;
        _lastProcessedPos = pos;

        setState(() => _current = pos);
        // Smooth move to latest position (guarded)
        try {
          _mapController.move(pos, _mapController.camera.zoom);
        } catch (_) {}

        // Notifications based on proximity
        _maybeNotifyArrival(pos);
        _maybeNotifyDropAtSchool(pos);
        _maybeNotifyHomeReached(pos);
      },
    );
  }

  void _maybeNotifyArrival(LatLng pos) async {
    if (_home == null) return;
    // Rough ETA: 5 minutes ≈ 1.5 km (assuming urban speed ~18 km/h)
    final dist = const Distance().as(LengthUnit.Meter, pos, _home!);
    final within = dist <= 1500;
    final now = DateTime.now();
    if (within) {
      final tooSoon = _lastEtaNotify != null && now.difference(_lastEtaNotify!).inMinutes < 20;
      if (!tooSoon) {
        _lastEtaNotify = now;
        // Silent log only
        await _log.addLog(NotificationLogItem(
          message: 'Bus arriving soon: about 5 minutes from your stop.',
          type: 'arrival',
          timestamp: DateTime.now(),
        ));
        unawaited(_remoteNotif.createMyNotification(type: 'arrival', message: 'Bus arriving soon: about 5 minutes from your stop.'));
      }
    }
  }

  void _maybeNotifyDropAtSchool(LatLng pos) async {
    if (_school == null) return;
    // Near school within 200m and we previously saw boarded true
    final dist = const Distance().as(LengthUnit.Meter, pos, _school!);
    if (dist <= 200 && _boarded == true && !_dropNotified) {
      _dropNotified = true;
      // Silent log only
      await _log.addLog(NotificationLogItem(
        message: 'Dropped at school: bus has arrived.',
        type: 'drop',
        timestamp: DateTime.now(),
      ));
      unawaited(_remoteNotif.createMyNotification(type: 'drop', message: 'Dropped at school: bus has arrived.'));
    }
    // Reset drop notification when bus moves away
    if (dist > 400) {
      _dropNotified = false;
    }
  }

  bool _homeReachedNotified = false;
  void _maybeNotifyHomeReached(LatLng pos) async {
    if (_home == null) return;
    final dist = const Distance().as(LengthUnit.Meter, pos, _home!);
    if (dist <= 100 && !_homeReachedNotified) {
      _homeReachedNotified = true;
      await _log.addLog(NotificationLogItem(
        message: 'Bus has reached your stop.',
        type: 'home_reached',
        timestamp: DateTime.now(),
      ));
      unawaited(_remoteNotif.createMyNotification(type: 'home_reached', message: 'Bus has reached your stop.'));
    }
    if (dist > 200) {
      _homeReachedNotified = false;
    }
  }

  @override
  void dispose() {
    _locChannel?.unsubscribe();
    _boardingChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.busId == null) {
      return const Center(child: Text('No bus assigned yet'));
    }
    final center = _current ?? _home ?? _school ?? const LatLng(27.7172, 85.3240); // Prefer home when available
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        minZoom: 11,
        maxZoom: 19,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(27.55, 85.15), // SW corner of Kathmandu Valley approx
            const LatLng(27.85, 85.55), // NE corner of Kathmandu Valley approx
          ),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.parent',
        ),
        MarkerLayer(markers: [
          if (_school != null)
            Marker(
              point: _school!,
              alignment: Alignment.bottomCenter,
              width: 36,
              height: 36,
              child: const Icon(Icons.school, size: 32, color: Colors.blue),
            ),
          if (_home != null)
            Marker(
              point: _home!,
              alignment: Alignment.bottomCenter,
              width: 36,
              height: 36,
              child: const Icon(Icons.home, size: 32, color: Colors.green),
            ),
          if (_current != null)
            Marker(
              point: _current!,
              alignment: Alignment.bottomCenter,
              width: 40,
              height: 40,
              child: const Icon(Icons.directions_bus, size: 36, color: Colors.red),
            ),
        ]),
        if (_school == null && _home == null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              child: Card(
                color: Colors.black.withOpacity(0.7),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'No school/home markers yet. Check that school coords and student\'s bus stop lat/lng are set and visible by parent (RLS).',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        if (_school != null && _current != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [_school!, _current!],
                strokeWidth: 4,
                color: Colors.orange,
              )
            ],
          ),
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, right: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Bus: ${widget.busPlate}'),
              ),
            ),
          ),
        ),
        // History button removed as per request
      ],
    );
  }
}
