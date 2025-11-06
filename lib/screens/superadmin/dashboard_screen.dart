import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../supabase_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_widgets.dart';

class SuperadminDashboardScreen extends StatefulWidget {
  const SuperadminDashboardScreen({super.key});

  @override
  State<SuperadminDashboardScreen> createState() =>
      _SuperadminDashboardScreenState();
}

class _SuperadminDashboardScreenState extends State<SuperadminDashboardScreen> {
  List<Map<String, dynamic>> schoolAdmins = []; // fetched school_admin table
  List<Map<String, dynamic>> schools = []; // fetched schools table
  bool loadingAdmins = true;
  bool loadingSchools = true;
  
  // Admin client for privileged operations
  final SupabaseClient _adminSupabase = SupabaseClient(
    'https://nnjjefycskerdjqmatkf.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5uamplZnljc2tlcmRqcW1hdGtmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MjYyNTQ3NiwiZXhwIjoyMDY4MjAxNDc2fQ.nGXxDihQI6LDVWi8M8rnYAcmHXaIZF2DvSfSITGMBmw',
  );

  @override
  void initState() {
    super.initState();
    fetchSchoolAdmins();
    fetchSchools();
  }

  Future<void> fetchSchoolAdmins() async {
    setState(() => loadingAdmins = true);
    try {
      // Join school_admins with schools to get school name using admin client
      final response = await _adminSupabase
          .from('school_admins')
          .select('id, user_id, school_id, schools(name)');
      
      schoolAdmins = List<Map<String, dynamic>>.from(response);
      
      // Fetch user emails from auth.users for each admin
      for (var admin in schoolAdmins) {
        final userId = admin['user_id'];
        try {
          // Use admin client to get user email
          final userResponse = await _adminSupabase.auth.admin.getUserById(userId);
          admin['email'] = userResponse.user?.email ?? 'No email';
          
          // Extract school name from nested object
          if (admin['schools'] != null) {
            admin['school_name'] = admin['schools']['name'];
          } else {
            admin['school_name'] = 'Unknown School';
          }
        } catch (e) {
          admin['email'] = 'No email';
          admin['school_name'] = 'Unknown School';
        }
      }
      
      // Fetch student and parent counts for each school admin
      for (var admin in schoolAdmins) {
        final schoolId = admin['school_id'];
        if (schoolId != null) {
          try {
            // Count students using admin client
            final students = await _adminSupabase
                .from('students')
                .select()
                .eq('school_id', schoolId);
            admin['student_count'] = (students as List).length;
            
            // Count parents - get all students for this school, then count unique parents
            if ((students as List).isNotEmpty) {
              final studentIds = students.map((s) => s['id']).toList();
              final parents = await _adminSupabase
                  .from('parents')
                  .select('user_id, student_id')
                  .inFilter('student_id', studentIds);
              admin['parent_count'] = (parents as List).length;
            } else {
              admin['parent_count'] = 0;
            }
            
            // Count buses
            final buses = await _adminSupabase
                .from('buses')
                .select()
                .eq('school_id', schoolId);
            admin['bus_count'] = (buses as List).length;
            
            // Count drivers
            final drivers = await _adminSupabase
                .from('drivers')
                .select()
                .eq('school_id', schoolId);
            admin['driver_count'] = (drivers as List).length;
          } catch (e) {
            admin['student_count'] = 0;
            admin['parent_count'] = 0;
            admin['bus_count'] = 0;
            admin['driver_count'] = 0;
          }
        } else {
          admin['student_count'] = 0;
          admin['parent_count'] = 0;
          admin['bus_count'] = 0;
          admin['driver_count'] = 0;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load school admins. Please try again.'), backgroundColor: Colors.red),
        );
      }
      schoolAdmins = [];
    }
    setState(() => loadingAdmins = false);
  }

  Future<void> fetchSchools() async {
    setState(() => loadingSchools = true);
    try {
      final response = await supabase.from('schools').select();
      schools = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load schools. Please try again.'), backgroundColor: Colors.red),
        );
      }
      schools = [];
    }
    setState(() => loadingSchools = false);
  }

  void logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  void resetPassword() async {
    final userEmail = supabase.auth.currentUser?.email;
    if (userEmail != null) {
      await supabase.auth.resetPasswordForEmail(userEmail);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset link sent to your email")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
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
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Super Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                Text('System Dashboard', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
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
                child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              ),
              onPressed: logout,
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGradient),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCard(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.success, AppTheme.success.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 28),
                    ),
                    title: const Text('Create School Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('Generate credentials and assign to school', style: TextStyle(fontSize: 13)),
                    trailing: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(context, '/create_school_admin');
                        if (result == true) {
                          await fetchSchoolAdmins();
                          await fetchSchools();
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                AnimatedCard(
                  padding: const EdgeInsets.all(16),
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
                            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text('School Admins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Total: ${schoolAdmins.length}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      loadingAdmins
                          ? const Center(child: CircularProgressIndicator())
                          : schoolAdmins.isEmpty
                              ? const Text('No school admins found.')
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: schoolAdmins.length,
                                  itemBuilder: (context, index) {
                                    final admin = schoolAdmins[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      elevation: 1,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    admin['email'] ?? 'No email',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    admin['school_name'] ?? 'Unnamed School',
                                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  Text(
                                                    '${admin['student_count'] ?? 0}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                  ),
                                                  const Text('Students', style: TextStyle(fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  Text(
                                                    '${admin['parent_count'] ?? 0}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                  ),
                                                  const Text('Parents', style: TextStyle(fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  Text(
                                                    '${admin['bus_count'] ?? 0}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                  ),
                                                  const Text('Buses', style: TextStyle(fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                children: [
                                                  Text(
                                                    '${admin['driver_count'] ?? 0}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                                  ),
                                                  const Text('Drivers', style: TextStyle(fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                  onPressed: () async {
                                                    // Delete school admin from table
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: const Text('Confirm Delete'),
                                                        content: const Text('Are you sure you want to delete this school admin?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context, false),
                                                            child: const Text('Cancel'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context, true),
                                                            child: const Text('Delete'),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                    if (confirm == true) {
                                                      try {
                                                        await _adminSupabase.from('school_admins').delete().eq('id', admin['id']);
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(content: Text('School admin deleted successfully'), backgroundColor: Colors.green)
                                                          );
                                                        }
                                                        await fetchSchoolAdmins();
                                                      } catch (e) {
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(content: Text('Failed to delete school admin: $e'), backgroundColor: Colors.red)
                                                          );
                                                        }
                                                      }
                                                    }
                                                  },
                                                ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      // Totals Row
                      if (schoolAdmins.isNotEmpty) ...[
                        const Divider(thickness: 2, height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'TOTALS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '${schoolAdmins.fold<int>(0, (sum, admin) => sum + (admin['student_count'] as int? ?? 0))}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const Text('Total', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '${schoolAdmins.fold<int>(0, (sum, admin) => sum + (admin['parent_count'] as int? ?? 0))}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const Text('Total', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '${schoolAdmins.fold<int>(0, (sum, admin) => sum + (admin['bus_count'] as int? ?? 0))}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const Text('Total', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '${schoolAdmins.fold<int>(0, (sum, admin) => sum + (admin['driver_count'] as int? ?? 0))}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const Text('Drivers', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 40), // Space for delete button column
                            ],
                          ),
                        ),
                      ],
                    ],
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
