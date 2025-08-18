import 'package:flutter/material.dart';
import 'assignment/assignment_screen.dart';
import 'summary_screen.dart';
import 'map_screen.dart';

class SchoolAdminApp extends StatefulWidget {
  final VoidCallback? onLogout;

  const SchoolAdminApp({super.key, this.onLogout});

  @override
  State<SchoolAdminApp> createState() => _SchoolAdminAppState();
}

class _SchoolAdminAppState extends State<SchoolAdminApp> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = [
    const MapScreen(),
    const AssignmentScreen(),
    const SummaryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              if (widget.onLogout != null) {
                widget.onLogout!();
              }
            },
          )
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Assignment'),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics), label: 'Summary'),
        ],
      ),
    );
  }
}
