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
  final double? initialHomeLat;
  final double? initialHomeLng;
  const MapTab({
    super.key,
    required this.busId,
    required this.busPlate,
    this.initialHomeLat,
    this.initialHomeLng,
  });

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
  DateTime? _lastEtaNotify;
  bool _dropNotified = false;
  DateTime? _lastBoardingNotify;
  String? _lastBoardingStatus; // Track last boarding status to prevent duplicates
  final _mapController = MapController();
  final _log = NotificationLogService();
  final _remoteNotif = ParentNotificationService();

  @override
  void initState() {
    super.initState();
    // If initial home coordinates are provided, set them immediately
    if (widget.initialHomeLat != null && widget.initialHomeLng != null) {
      _home = LatLng(widget.initialHomeLat!, widget.initialHomeLng!);
      debugPrint('[Parent Map] ✅ Home set from initial props in initState: ${widget.initialHomeLat}, ${widget.initialHomeLng}');
      // Center map on home location after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _home != null) {
          try {
            _mapController.move(_home!, 15);
            debugPrint('[Parent Map] 📍 Map centered on home location');
          } catch (e) {
            debugPrint('[Parent Map] ⚠️ Could not center map: $e');
          }
        }
      });
    }
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
        // Move map to bus location
        try {
          _mapController.move(pos, 15);
        } catch (_) {
          // MapController might not be ready yet, that's ok
        }
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
      
      // Build address from structured fields (preferred) or fallback to legacy field
      final area = row['bus_stop_area'] as String?;
      final city = row['bus_stop_city'] as String?;
      final country = row['bus_stop_country'] as String?;
      String? stopText;
      if (area != null || city != null || country != null) {
        stopText = [area, city, country]
            .where((e) => e != null && e.trim().isNotEmpty)
            .join(', ');
      } else {
        stopText = row['bus_stop'] as String?;
      }
      
      debugPrint('[Parent Map] ===== INITIALIZATION =====');
      debugPrint('[Parent Map] School lat/lng: $slat, $slon');
      debugPrint('[Parent Map] Home lat/lng: $hlat, $hlon');
      debugPrint('[Parent Map] Bus stop address: $stopText');
      debugPrint('[Parent Map] Student ID: ${row['id']}');
      debugPrint('[Parent Map] Bus ID: ${row['bus_id']}');
      
      setState(() {
        if (slat != null && slon != null) {
          _school = LatLng(slat, slon);
          debugPrint('[Parent Map] ✅ School marker set');
        } else {
          debugPrint('[Parent Map] ⚠️ No school coordinates');
        }
        
        // Prioritize passed-in coordinates (from edit screen) over fetched ones
        if (widget.initialHomeLat != null && widget.initialHomeLng != null) {
          _home = LatLng(widget.initialHomeLat!, widget.initialHomeLng!);
          debugPrint('[Parent Map] ✅ Home marker set from props: ${widget.initialHomeLat}, ${widget.initialHomeLng}');
        } else if (hlat != null && hlon != null) {
          _home = LatLng(hlat, hlon);
          debugPrint('[Parent Map] ✅ Home marker set from DB: $hlat, $hlon');
        } else {
          debugPrint('[Parent Map] ⚠️ No home coordinates - will try geocoding');
        }
        
        _studentId = row['id'] as String?;
      });

      // Fallback: if no home coords but we have a bus_stop address, try geocoding it once
      if (mounted && _home == null && (stopText != null && stopText.trim().isNotEmpty)) {
        debugPrint('[Parent Map] Attempting to geocode bus stop: "$stopText"');
        try {
          final geo = await GeocodingService().geocodeAddress(stopText);
          if (geo != null && mounted) {
            setState(() => _home = LatLng(geo.lat, geo.lon));
            debugPrint('[Parent Map] ✅ Home geocoded successfully: ${geo.lat}, ${geo.lon}');
            // Persist back to DB so it doesn't disappear on next load
            final sid = _studentId;
            if (sid != null) {
              debugPrint('[Parent Map] Persisting coordinates to database...');
              unawaited(_service.persistHomeCoords(studentId: sid, lat: geo.lat, lng: geo.lon));
            }
          } else {
            debugPrint('[Parent Map] ❌ Geocoding returned null for "$stopText"');
          }
        } catch (e) {
          debugPrint('[Parent Map] ❌ Geocoding failed: $e');
        }
      } else if (_home == null) {
        debugPrint('[Parent Map] ⚠️ No bus stop address available for geocoding');
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
                message = 'Your child has unboarded the bus';
              } else {
                message = 'Your child has boarded the bus';
              }
            } else if (r.containsKey('boarded') || r.containsKey('is_boarded')) {
              final b = (r['boarded'] ?? r['is_boarded']) as bool?;
              if (b != null) {
                message = b ? 'Your child has boarded the bus' : 'Your child has unboarded the bus';
              }
            }
            if (message != null && mounted) {
              // Check if this is the same status as last time (prevent duplicates)
              if (_lastBoardingStatus == message) {
                debugPrint('[Parent Map] Boarding notification skipped (same status: $message)');
                return;
              }
              
              // Throttle boarding notifications to prevent duplicates (60 seconds)
              final now = DateTime.now();
              if (_lastBoardingNotify != null && now.difference(_lastBoardingNotify!).inSeconds < 60) {
                final secondsSince = now.difference(_lastBoardingNotify!).inSeconds;
                debugPrint('[Parent Map] Boarding notification throttled (${secondsSince}s since last, need 60s)');
                return;
              }
              _lastBoardingNotify = now;
              _lastBoardingStatus = message;
              
              await _log.addLog(NotificationLogItem(
                message: message,
                type: 'boarding',
                timestamp: DateTime.now(),
              ));
              // Persist to backend so it's visible later
              unawaited(_remoteNotif.createMyNotification(type: 'boarding', message: message));
              
              debugPrint('[Parent Map] 🔔 BOARDING NOTIFICATION: $message');
            }
          },
        );
      }
    } catch (e) {
      debugPrint('[Parent Map] _loadContext error: $e');
    }
  }

  void _subscribe(String busId) {
    debugPrint('[Parent Map] 🔔 Subscribing to bus location updates for busId: $busId');
    _locChannel = _service.subscribeBusLocation(
      busId: busId,
      onInsert: (row) {
        final lat = (row['latitude'] as num).toDouble();
        final lng = (row['longitude'] as num).toDouble();
        final pos = LatLng(lat, lng);
        if (!mounted) return;
        
        debugPrint('[Parent Map] 📍 Bus location update: $lat, $lng');
        
        // Always update current position for map display
        setState(() => _current = pos);
        
        // Smooth move to latest position (guarded)
        try {
          _mapController.move(pos, _mapController.camera.zoom);
        } catch (_) {}

        // Check proximity notifications on EVERY update (don't throttle notifications)
        debugPrint('[Parent Map] Checking proximity notifications...');
        _maybeNotifyArrival(pos);
        _maybeNotifyDropAtSchool(pos);
        _maybeNotifyHomeReached(pos);
      },
    );
  }

  void _maybeNotifyArrival(LatLng pos) async {
    if (_home == null) {
      debugPrint('[Parent Map] _maybeNotifyArrival: No home coordinates set');
      return;
    }
    // Proximity alert: within 200 meters of the bus stop
    final dist = const Distance().as(LengthUnit.Meter, pos, _home!);
    debugPrint('[Parent Map] Distance to home: ${dist.toStringAsFixed(1)}m (threshold: 200m)');
    
    final within = dist <= 200;
    final now = DateTime.now();
    if (within) {
      final secondsSinceLastNotify = _lastEtaNotify != null ? now.difference(_lastEtaNotify!).inSeconds : 999;
      final tooSoon = _lastEtaNotify != null && secondsSinceLastNotify < 60;
      debugPrint('[Parent Map] Within 200m! secondsSinceLastNotify=$secondsSinceLastNotify, tooSoon=$tooSoon (need 60s), lastNotify=$_lastEtaNotify');
      if (!tooSoon) {
        _lastEtaNotify = now;
        final message = 'Bus is near your stop (within ${dist.toStringAsFixed(0)} m).';
        debugPrint('[Parent Map] 🔔 SENDING ARRIVAL NOTIFICATION: $message');
        
        // Show visual feedback
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔔 $message'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        
        // Silent log only
        await _log.addLog(NotificationLogItem(
          message: message,
          type: 'arrival',
          timestamp: DateTime.now(),
        ));
        unawaited(_remoteNotif.createMyNotification(type: 'arrival', message: message));
      }
    }
  }

  void _maybeNotifyDropAtSchool(LatLng pos) async {
    if (_school == null) return;
    // Near school within 50m
    final dist = const Distance().as(LengthUnit.Meter, pos, _school!);
    debugPrint('[Parent Map] Distance to school: ${dist.toStringAsFixed(1)}m (threshold: 50m), dropNotified=$_dropNotified');
    
    if (dist <= 50 && !_dropNotified) {
      _dropNotified = true;
      final message = 'Bus is at school (within ${dist.toStringAsFixed(0)} m).';
      debugPrint('[Parent Map] 🔔 SENDING SCHOOL REACHED NOTIFICATION: $message');
      
      // Show visual feedback
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔔 $message'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      // Save to local log
      await _log.addLog(NotificationLogItem(
        message: message,
        type: 'drop',
        timestamp: DateTime.now(),
      ));
      
      // Save to database
      unawaited(_remoteNotif.createMyNotification(type: 'drop', message: message));
    }
    // Reset drop notification when bus moves away (100m)
    if (dist > 100) {
      _dropNotified = false;
    }
  }

  bool _homeReachedNotified = false;
  void _maybeNotifyHomeReached(LatLng pos) async {
    if (_home == null) return;
    final dist = const Distance().as(LengthUnit.Meter, pos, _home!);
    debugPrint('[Parent Map] Distance to home (reached check): ${dist.toStringAsFixed(1)}m (threshold: 50m)');
    if (dist <= 50 && !_homeReachedNotified) {
      _homeReachedNotified = true;
      final message = 'Bus has reached your stop.';
      debugPrint('[Parent Map] 🔔 SENDING HOME REACHED NOTIFICATION: $message');
      
      // Show visual feedback
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔔 $message'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      
      await _log.addLog(NotificationLogItem(
        message: message,
        type: 'home_reached',
        timestamp: DateTime.now(),
      ));
      unawaited(_remoteNotif.createMyNotification(type: 'home_reached', message: message));
    }
    // Reset when bus moves away (100m)
    if (dist > 100) {
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
    final center = _current ?? _home ?? _school ?? const LatLng(27.7172, 85.3240); // Prefer bus location
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FlutterMap(
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
            if (_home != null)
              Marker(
                point: _home!,
                alignment: Alignment.bottomCenter,
                width: 100,
                height: 70,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
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
                        'Home',
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
                        Icons.home_rounded,
                        color: Color(0xFF4CAF50),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            if (_current != null)
              Marker(
                point: _current!,
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
                        widget.busPlate,
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
              ),
          ]),
          // Debug UI and warning messages removed for cleaner map view
        ],
      ),
    );
  }
}
