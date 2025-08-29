import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/parent_service.dart';
import 'notifications_tab.dart';
import 'map_tab.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with SingleTickerProviderStateMixin {
  final _service = ParentService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _student; // id, name, bus_id, bus
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _service.getMyChildWithBus();
      if (!mounted) return;
      if (s == null) {
        setState(() {
          _error = 'No student linked to this parent account';
          _loading = false;
        });
        return;
      }
      setState(() {
        _student = s;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/parent/password-login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Panel'),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notifications', icon: Icon(Icons.notifications)),
            Tab(text: 'Map', icon: Icon(Icons.map)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    NotificationsTab(
                      studentId: _student!['id'] as String,
                      studentName: _student!['name'] as String? ?? 'Student',
                    ),
                    MapTab(
                      busId: _student!['bus_id'] as String?,
                      busPlate: _student!['bus']?['plate_number'] as String? ?? 'Bus',
                    ),
                  ],
                ),
    );
  }
}
