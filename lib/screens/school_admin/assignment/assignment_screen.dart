import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import 'bus_list_screen.dart';
import 'edit_bus_list_screen.dart';
import 'create_student_screen.dart';
import 'create_driver_screen.dart';
import '../../school_admin/change_password_screen.dart';
import 'edit_profile_screen.dart';

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key});

  @override
  State<AssignmentScreen> createState() => _AssignmentDashboardState();
}

class _AssignmentDashboardState extends State<AssignmentScreen> {
  final SchoolService _schoolService = SchoolService();
  final AuthService _authService = AuthService();
  int _selectedDrawerIndex = 0;
  String _schoolName = 'Loading...';
  String? _schoolAddress;

  @override
  void initState() {
    super.initState();
    _fetchSchoolName();
  }

  Future<void> _fetchSchoolName() async {
    try {
      final school = await _schoolService.getSchool();
      if (school != null) {
        setState(() {
          _schoolName = school.name;
          _schoolAddress = school.address;
        });
      } else {
        setState(() {
          _schoolName = 'School Admin Dashboard';
          _schoolAddress = null;
        });
      }
    } catch (e) {
      setState(() {
        _schoolName = 'School Admin Dashboard';
        _schoolAddress = null;
      });
      // Optionally log or show error
      print('Error fetching school name: $e');
    }
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const BusListScreen();
      case 1:
        return const EditBusListScreen();
      case 2:
        return const CreateStudentScreen();
      case 3:
        return const CreateDriverScreen();
      case 4:
        return const EditProfileScreen();
      case 5:
        return ChangePasswordScreen(
          onPasswordChanged: () {
            // Go back to bus list or dashboard after password change
            setState(() {
              _selectedDrawerIndex = 0;
            });
          },
        );
      default:
        return const BusListScreen();
    }
  }

  void _onSelectItem(int index) {
    setState(() => _selectedDrawerIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_schoolName Dashboard'),
            if (_schoolAddress != null && _schoolAddress!.isNotEmpty)
              Text(
                _schoolAddress!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.directions_bus),
              title: const Text('Bus List'),
              selected: _selectedDrawerIndex == 0,
              onTap: () => _onSelectItem(0),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Bus List'),
              selected: _selectedDrawerIndex == 1,
              onTap: () => _onSelectItem(1),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Create Student'),
              selected: _selectedDrawerIndex == 2,
              onTap: () => _onSelectItem(2),
            ),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Create Driver'),
              selected: _selectedDrawerIndex == 3,
              onTap: () => _onSelectItem(3),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Edit Profile'),
              selected: _selectedDrawerIndex == 4,
              onTap: () => _onSelectItem(4),
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change Password'),
              selected: _selectedDrawerIndex == 5,
              onTap: () => _onSelectItem(5),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await _authService.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ],
        ),
      ),
      body: _getScreen(_selectedDrawerIndex),
    );
  }
}
