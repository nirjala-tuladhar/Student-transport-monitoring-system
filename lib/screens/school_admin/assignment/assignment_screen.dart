import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../../../theme/app_theme.dart';
import 'bus_list_screen.dart';
import 'edit_bus_list_screen.dart';
import 'create_student_screen.dart';
import 'create_driver_screen.dart';
import 'create_bus_screen.dart';
import '../../school_admin/change_password_screen.dart';
import 'edit_profile_screen.dart';

/// Redesigned School Admin Dashboard with modern UI
class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key});

  @override
  State<AssignmentScreen> createState() => _AssignmentDashboardState();
}

class _AssignmentDashboardState extends State<AssignmentScreen> with SingleTickerProviderStateMixin {
  final SchoolService _schoolService = SchoolService();
  final AuthService _authService = AuthService();
  int _selectedDrawerIndex = 0;
  String _schoolName = 'Loading...';
  String? _schoolAddress;
  String? _schoolLogoUrl;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppTheme.normalAnimation,
    );
    _fetchSchoolName();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchoolName() async {
    try {
      final school = await _schoolService.getSchool();
      if (school != null) {
        setState(() {
          _schoolName = school.name;
          _schoolAddress = school.address;
          _schoolLogoUrl = school.logoUrl;
        });
      } else {
        setState(() {
          _schoolName = 'School Admin Dashboard';
          _schoolAddress = null;
          _schoolLogoUrl = null;
        });
      }
    } catch (e) {
      setState(() {
        _schoolName = 'School Admin Dashboard';
        _schoolAddress = null;
      });
      debugPrint('Error fetching school name: $e');
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
        return const CreateBusScreen();
      case 5:
        return const EditProfileScreen();
      case 6:
        return ChangePasswordScreen(
          onPasswordChanged: () {
            setState(() => _selectedDrawerIndex = 0);
          },
        );
      default:
        return const BusListScreen();
    }
  }

  void _onSelectItem(int index) {
    setState(() => _selectedDrawerIndex = index);
    Navigator.pop(context);
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildModernAppBar(),
      drawer: _buildModernDrawer(),
      body: FadeTransition(
        opacity: _animationController,
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.subtleGradient,
          ),
          child: _getScreen(_selectedDrawerIndex),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
      ),
      title: Row(
        children: [
          Hero(
            tag: 'school_logo',
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                image: _schoolLogoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_schoolLogoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _schoolLogoUrl == null
                  ? Icon(
                      Icons.school_rounded,
                      color: AppTheme.primaryBlue,
                      size: 24,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _schoolName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_schoolAddress != null && _schoolAddress!.isNotEmpty)
                  Text(
                    _schoolAddress!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildModernDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildDrawerHeader(),
            _buildDrawerSection(
              title: 'Management',
              items: [
                _DrawerItem(icon: Icons.directions_bus_rounded, title: 'Bus List', index: 0),
                _DrawerItem(icon: Icons.edit_road_rounded, title: 'Edit Bus List', index: 1),
                _DrawerItem(icon: Icons.person_add_rounded, title: 'Create Student', index: 2),
                _DrawerItem(icon: Icons.badge_rounded, title: 'Create Driver', index: 3),
                _DrawerItem(icon: Icons.add_business_rounded, title: 'Create Bus', index: 4),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
            _buildDrawerSection(
              title: 'Settings',
              items: [
                _DrawerItem(icon: Icons.settings_rounded, title: 'Edit Profile', index: 5),
                _DrawerItem(icon: Icons.lock_rounded, title: 'Change Password', index: 6),
              ],
            ),
            const SizedBox(height: 16),
            _buildLogoutButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Admin Panel',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your school',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSection({
    required String title,
    required List<_DrawerItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ...items.map((item) => _buildDrawerTile(
              icon: item.icon,
              title: item.title,
              index: item.index,
            )),
      ],
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedDrawerIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onSelectItem(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: AppTheme.fastAnimation,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryBlue.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryBlue.withOpacity(0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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

            if (confirm == true) {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.error.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: AppTheme.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerItem {
  final IconData icon;
  final String title;
  final int index;

  _DrawerItem({
    required this.icon,
    required this.title,
    required this.index,
  });
}
