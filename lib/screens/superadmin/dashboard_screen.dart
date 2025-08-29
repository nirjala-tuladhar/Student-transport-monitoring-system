import 'package:flutter/material.dart';
import '../../supabase_client.dart';

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

  @override
  void initState() {
    super.initState();
    fetchSchoolAdmins();
    fetchSchools();
  }

  Future<void> fetchSchoolAdmins() async {
    setState(() => loadingAdmins = true);
    try {
      final response = await supabase.from('school_admins').select();
      schoolAdmins = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching school admins: $e');
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
      print('Error fetching schools: $e');
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
        title: const Text('Superadmin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Removed Password Reset section as requested

              // School Admin List with Edit/Delete
              Card(
                elevation: 6,
                color: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('School Admins',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
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
                                    return ListTile(
                                      title: Text(
                                          admin['school_name'] ?? 'Unnamed'),
                                      subtitle: Text(admin['email'] ?? ''),
                                      trailing: Wrap(
                                        spacing: 10,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () {
                                              // TODO: implement edit school admin
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () async {
                                              // Delete school admin from table
                                              final confirm =
                                                  await showDialog<bool>(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: const Text(
                                                      'Confirm Delete'),
                                                  content: const Text(
                                                      'Are you sure you want to delete this school admin?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, false),
                                                      child:
                                                          const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context, true),
                                                      child:
                                                          const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirm == true) {
                                                try {
                                                  await supabase
                                                      .from('school_admins')
                                                      .delete()
                                                      .eq('id', admin['id']);
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(const SnackBar(
                                                          content: Text(
                                                              'School admin deleted')));
                                                  await fetchSchoolAdmins(); // refresh list
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(
                                                              'Delete failed: $e')));
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Create School Admin
              Card(
                elevation: 6,
                color: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: const Text('Create School Admin'),
                  subtitle:
                      const Text('Generate temp login and assign to school'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      // Navigate and wait for result, refresh list after return
                      final result = await Navigator.pushNamed(
                          context, '/create_school_admin');
                      if (result == true) {
                        await fetchSchoolAdmins();
                        await fetchSchools();
                      }
                    },
                    child: const Text('Create'),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Simple Schools list
              Card(
                elevation: 6,
                color: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Schools',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(),
                      if (loadingSchools)
                        const Center(child: CircularProgressIndicator())
                      else if (schools.isEmpty)
                        const Text('No schools found.')
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: schools.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final school = schools[index];
                            return ListTile(
                              title: Text(school['name'] ?? 'Unnamed'),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
