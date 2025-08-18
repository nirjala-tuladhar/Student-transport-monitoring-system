import 'package:flutter/material.dart';
import 'bus_list_screen.dart';
import 'edit_bus_list_screen.dart';
import 'create_student_screen.dart';
import 'create_driver_screen.dart';
import '../../school_admin/change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key});

  @override
  State<AssignmentScreen> createState() => _AssignmentDashboardState();
}

class _AssignmentDashboardState extends State<AssignmentScreen> {
  int _selectedDrawerIndex = 0;
  String _schoolName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchSchoolName();
  }

  Future<void> _fetchSchoolName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('school_admin')
          .select('school_name')
          .eq('user_id', user.id)
          .single();

      if (response != null && response['school_name'] != null) {
        setState(() {
          _schoolName = response['school_name'] as String;
        });
      } else {
        setState(() {
          _schoolName = 'School Admin Dashboard';
        });
      }
    } catch (e) {
      setState(() {
        _schoolName = 'School Admin Dashboard';
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
      appBar: AppBar(title: Text('$_schoolName Dashboard')),
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
              onTap: () => _onSelectItem(0),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Bus List'),
              onTap: () => _onSelectItem(1),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Create Student'),
              onTap: () => _onSelectItem(2),
            ),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Create Driver'),
              onTap: () => _onSelectItem(3),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Edit Profile'),
              onTap: () => _onSelectItem(4),
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change Password'),
              onTap: () => _onSelectItem(5),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
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
